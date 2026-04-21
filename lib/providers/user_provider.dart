// lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/user_services.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches the user document from Firestore and stores it locally.
  /// Called by AuthWrapper once Firebase confirms a logged-in user.
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _userService.getUser(uid);
      _currentUser = user;
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the local copy after a successful profile save.
  void updateLocalUser(UserModel updated) {
    _currentUser = updated;
    notifyListeners();
  }

  /// Clears user data on sign-out.
  void clearUser() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}