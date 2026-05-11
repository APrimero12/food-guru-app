// lib/providers/user_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/services/recipe_services.dart';

class UserProvider extends ChangeNotifier {
  final UserService   _userService   = UserService();

  UserModel?   _currentUser;
  bool         _isLoading = false;
  String?      _error;

  // Single source of truth for which recipes the current user has liked.
  final Set<String> _likedRecipeIds = {};

  // ── debounce: one timer + pending-state map per recipe ───────────────────
  // When the user spam-taps, we update the UI instantly every tap but only
  // fire a Firestore write 3 seconds after the *last* tap on that recipe.
  final Map<String, Timer>  _debounceTimers   = {};
  // Tracks whether the PENDING Firestore write will be a like or unlike.
  final Map<String, bool>   _pendingLiked     = {};
  // The like state that was committed to Firestore last (used for revert).
  final Map<String, bool>   _committedLiked   = {};

  // ── getters ───────────────────────────────────────────────────────────────

  UserModel?       get currentUser    => _currentUser;
  bool             get isLoading      => _isLoading;
  String?          get error          => _error;
  Set<String>      get likedRecipeIds => Set.unmodifiable(_likedRecipeIds);

  bool isLiked(String recipeId) => _likedRecipeIds.contains(recipeId);

  // ── load user + liked IDs together ────────────────────────────────────────

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _userService.getUser(uid),
        _fetchLikedIds(uid),
      ]);

      _currentUser    = results[0] as UserModel?;
      final liked     = results[1] as Set<String>;
      _likedRecipeIds
        ..clear()
        ..addAll(liked);

      // Seed committed state so the debouncer knows the real starting point.
      for (final id in liked) {
        _committedLiked[id] = true;
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
  //
  // UI updates immediately on every call.
  // A Firestore write is scheduled 3 s after the last call for that recipe.
  // If the user taps again before the timer fires, the timer resets.
  //
  // Returns the NEW local liked state so callers can update their own count.

  bool toggleLike(String recipeId) {
    final uid = _currentUser?.uid;
    if (uid == null) return isLiked(recipeId);

    // Flip local state immediately.
    final nowLiked = !isLiked(recipeId);
    if (nowLiked) {
      _likedRecipeIds.add(recipeId);
    } else {
      _likedRecipeIds.remove(recipeId);
    }
    _pendingLiked[recipeId] = nowLiked;
    notifyListeners();

    // Cancel any existing timer for this recipe and start a fresh one.
    _debounceTimers[recipeId]?.cancel();
    _debounceTimers[recipeId] = Timer(const Duration(seconds: 3), () {
      _flushLike(recipeId, uid);
    });

    return nowLiked;
  }

  /// Actually writes to Firestore once the debounce timer fires.
  Future<void> _flushLike(String recipeId, String uid) async {
    final desired  = _pendingLiked[recipeId];
    final previous = _committedLiked[recipeId] ?? false;
    if (desired == null || desired == previous) return; // nothing changed

    try {
      await RecipeService().toggleLike(recipeId, uid);
      _committedLiked[recipeId] = desired;
    } catch (e) {
      debugPrint('toggleLike flush failed for $recipeId: $e');
      // Revert local state to what Firestore has.
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

  // ── flush all pending likes on logout / dispose ───────────────────────────

  Future<void> flushAllPending() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    // Cancel timers and write immediately.
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
    // Flush pending likes before clearing so we don't lose data on sign-out.
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
      return snap.docs
          .map((d) => d['recipeId'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }
}