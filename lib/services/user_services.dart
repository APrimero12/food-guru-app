import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Only if you need FirebaseAuth directly here
import 'package:appdevproject/models/user_model.dart';

class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Helper to get a user's document reference
  DocumentReference _userDocRef(String uid) {
    return _usersCollection.doc(uid);
  }

  /// Fetches a UserModel from Firestore by UID.
  Future<UserModel?> getUser(String uid) async {
    try {
      final docSnapshot = await _userDocRef(uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      }
      return null; // when the user is not found
    } catch (e) {
      print("Error getting user $uid: $e");
      return null;
    }
  }

  /// Creates a new user document in Firestore.
  /// This also handles username reservation.
  Future<void> createUser(UserModel user) async {
    if (user.username == null || user.username!.trim().isEmpty) {
      throw ArgumentError('Username cannot be null or empty.');
    }
    final String lowerCaseUsername = user.username!.toLowerCase();

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final usernameDocRef = _usersCollection.doc(lowerCaseUsername);
      final usernameDoc = await transaction.get(usernameDocRef);

      if (usernameDoc.exists) {
        throw Exception('Username "$lowerCaseUsername" is already taken.');
      }

      final userDocRef = _userDocRef(user.uid);
      transaction.set(
        userDocRef,
        user.toMap().map((key, value) {
          // Set server timestamps for createdAt and lastActive upon creation
          if (key == 'createdAt' || key == 'lastActive' || value == null) {
            return MapEntry(key, FieldValue.serverTimestamp());
          }
          return MapEntry(key, value);
        }),
        SetOptions(merge: true),
      );

      transaction.set(usernameDocRef, {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    }).catchError((error) {
      print("Failed to create user and reserve username: $error");
      throw Exception('An unexpected error occurred during user creation: $error');
    });
  }

  /// Updates an existing user document in Firestore.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _userDocRef(uid).update(data);
    } catch (e) {
      print("Error updating user $uid: $e");
      throw Exception('Failed to update user: $e');
    }
  }

  /// Updates the username for a user, handling the username reservation.
  Future<void> updateUsername(String uid, String oldUsername, String newUsername) async {
    final String lowerCaseOldUsername = oldUsername.toLowerCase();
    final String lowerCaseNewUsername = newUsername.toLowerCase();

    if (lowerCaseOldUsername == lowerCaseNewUsername) {
      return;
    }

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final newUsernameDocRef = _usersCollection.doc(lowerCaseNewUsername);
      final newUsernameDoc = await transaction.get(newUsernameDocRef);

      if (newUsernameDoc.exists) {
        throw Exception('New username "$lowerCaseNewUsername" is already taken.');
      }

      final oldUsernameDocRef = _usersCollection.doc(lowerCaseOldUsername);
      transaction.delete(oldUsernameDocRef);

      transaction.set(newUsernameDocRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});

      final userDocRef = _userDocRef(uid);
      transaction.update(userDocRef, {'username': newUsername, 'lastActive': FieldValue.serverTimestamp()});
    }).catchError((error) {
      print("Failed to update username: $error");
      throw Exception('An unexpected error occurred during username update: $error');
    });
  }

  /// Deletes a user's profile and their username reservation.
  Future<void> deleteUserAndUsername(String uid, String username) async {
    final String lowerCaseUsername = username.toLowerCase();

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final userDocRef = _userDocRef(uid);
      transaction.delete(userDocRef);

      final usernameDocRef = _usersCollection.doc(lowerCaseUsername);
      transaction.delete(usernameDocRef);
    }).catchError((error) {
      print("Failed to delete user and username: $error");
      throw Exception('An unexpected error occurred during user and username deletion: $error');
    });
  }
}
