// lib/providers/user_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/services/recipe_services.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  final Set<String> _likedRecipeIds = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _pendingLiked = {};
  final Map<String, bool> _committedLiked = {};

  // ── getters ───────────────────────────────────────────────────────────────

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get likedRecipeIds => Set.unmodifiable(_likedRecipeIds);

  bool isLiked(String recipeId) => _likedRecipeIds.contains(recipeId);

  // ── load user ─────────────────────────────────────────────────────────────
  //
  // On first sign-up the Firestore document may not exist yet when this is
  // called. We retry up to 5 times before giving up so the profile page
  // doesn't infinite-load.

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      UserModel? user;

      // Retry up to 5 times with increasing delay to handle first-signup
      // race condition where auth fires before Firestore write completes
      for (int attempt = 0; attempt < 5; attempt++) {
        user = await _userService.getUser(uid);
        if (user != null) break;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }

      if (user != null) {
        _currentUser = user;

        final liked = await _fetchLikedIds(uid);
        _likedRecipeIds
          ..clear()
          ..addAll(liked);
        for (final id in liked) {
          _committedLiked[id] = true;
        }
      } else {
        // Still null after retries — set a minimal placeholder so the UI
        // doesn't keep spinning. The user can update their profile later.
        _error = 'Could not load profile. Please restart the app.';
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── debounced like toggle ─────────────────────────────────────────────────

  bool toggleLike(String recipeId) {
    final uid = _currentUser?.uid;
    if (uid == null) return isLiked(recipeId);

    final nowLiked = !isLiked(recipeId);
    if (nowLiked) {
      _likedRecipeIds.add(recipeId);
    } else {
      _likedRecipeIds.remove(recipeId);
    }
    _pendingLiked[recipeId] = nowLiked;
    notifyListeners();

    _debounceTimers[recipeId]?.cancel();
    _debounceTimers[recipeId] = Timer(const Duration(seconds: 3), () {
      _flushLike(recipeId, uid);
    });

    return nowLiked;
  }

  Future<void> _flushLike(String recipeId, String uid) async {
    final desired = _pendingLiked[recipeId];
    final previous = _committedLiked[recipeId] ?? false;
    if (desired == null || desired == previous) return;

    try {
      await RecipeService().toggleLike(recipeId, uid);
      _committedLiked[recipeId] = desired;
    } catch (e) {
      debugPrint('toggleLike flush failed for $recipeId: $e');
      if (previous) {
        _likedRecipeIds.add(recipeId);
      } else {
        _likedRecipeIds.remove(recipeId);
      }
      _pendingLiked[recipeId] = previous;
      notifyListeners();
    } finally {
      _debounceTimers.remove(recipeId);
    }
  }

  // ── flush all pending on logout ───────────────────────────────────────────

  Future<void> flushAllPending() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    for (final recipeId in List.of(_debounceTimers.keys)) {
      _debounceTimers[recipeId]?.cancel();
      _debounceTimers.remove(recipeId);
      await _flushLike(recipeId, uid);
    }
  }

  // ── other mutations ───────────────────────────────────────────────────────

  void updateLocalUser(UserModel updated) {
    _currentUser = updated;
    notifyListeners();
  }

  void clearUser() {
    flushAllPending();
    _currentUser = null;
    _likedRecipeIds.clear();
    _pendingLiked.clear();
    _committedLiked.clear();
    _debounceTimers.forEach((_, t) => t.cancel());
    _debounceTimers.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimers.forEach((_, t) => t.cancel());
    super.dispose();
  }

  // ── private ───────────────────────────────────────────────────────────────

  Future<Set<String>> _fetchLikedIds(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('user_likes')
          .where('userId', isEqualTo: uid)
          .get();
      return snap.docs.map((d) => d['recipeId'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}