// lib/providers/user_provider.dart
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
      // Fetch user profile and liked IDs in parallel.
      final results = await Future.wait([
        _userService.getUser(uid),
        _fetchLikedIds(uid),
      ]);

      _currentUser    = results[0] as UserModel?;
      final liked     = results[1] as Set<String>;
      _likedRecipeIds
        ..clear()
        ..addAll(liked);
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── optimistic like toggle ────────────────────────────────────────────────

  /// Optimistically updates the local liked set, calls Firestore, and reverts
  /// on failure. All pages that consume [isLiked] / [likedRecipeIds] will
  /// rebuild automatically via [notifyListeners].
  Future<void> toggleLike(String recipeId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final wasLiked = _likedRecipeIds.contains(recipeId);

    // Optimistic update.
    if (wasLiked) {
      _likedRecipeIds.remove(recipeId);
    } else {
      _likedRecipeIds.add(recipeId);
    }
    notifyListeners();

    try {
      await RecipeService().toggleLike(recipeId, uid);
    } catch (e) {
      // Revert on failure.
      if (wasLiked) {
        _likedRecipeIds.add(recipeId);
      } else {
        _likedRecipeIds.remove(recipeId);
      }
      notifyListeners();
      debugPrint('toggleLike failed: $e');
    }
  }

  // ── other mutations ───────────────────────────────────────────────────────

  void updateLocalUser(UserModel updated) {
    _currentUser = updated;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    _likedRecipeIds.clear();
    _error = null;
    notifyListeners();
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