import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid; // Use Firebase Authentication's unique User ID (String)
  final String? name; // Can come from Firebase User.displayName
  final String? username; // Custom field, might be set later
  final String? email; // Can come from Firebase User.email
  final String? avatar; // Can come from Firebase User.photoURL
  final String? bio; // Custom field, might be set later
  final Timestamp? createdAt; // When the user record was first created in Firestore
  final Timestamp? lastActive; // Optional: To track last activity

  // connection to the user collection in Firestore server
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  UserModel({
    required this.uid,
    this.name,
    this.username,
    this.email,
    this.avatar,
    this.bio,
    this.createdAt,
    this.lastActive,
  });

  // Factory method to create a UserModel from a Firebase Auth User object
  // This is useful right after authentication to populate initial data.
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      name: user.displayName, // Firebase User's display name
      avatar: user.photoURL, // Firebase User's photo URL
      createdAt: Timestamp.now(), // Set creation time when model is first created
      lastActive: Timestamp.now(), // Set initial last active time
    );
  }

  // Factory method to create a UserModel from a Firestore DocumentSnapshot
  // This is used when retrieving user data from Firestore.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    // Ensure data exists and is a Map
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      // Handle the case where the document data is null,
      // which means the document might not exist or be empty.
      // You might want to throw an error or return a default/empty UserModel.
      throw StateError('User document data is null for uid: ${doc.id}');
    }

    return UserModel(
      uid: doc.id, // The document ID is the user's UID
      email: data['email'] as String?,
      name: data['name'] as String?,
      username: data['username'] as String?,
      avatar: data['avatar'] as String?,
      bio: data['bio'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      lastActive: data['lastActive'] as Timestamp?,
    );
  }

  // Method to convert UserModel to a Map<String, dynamic> for Firestore
  // This is used when saving or updating user data in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'username': username,
      'avatar': avatar,
      'bio': bio,
      // Use FieldValue.serverTimestamp() for creating or updating timestamps
      // This ensures the timestamp is set by the Firestore server, preventing client-side clock skew
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastActive': lastActive ?? FieldValue.serverTimestamp(),
    };
  }

  @override
  String toString() {
    return 'UserModel{uid: $uid, name: $name, username: $username, email: $email, avatar: $avatar, bio: $bio, createdAt: $createdAt, lastActive: $lastActive}';
  }

  // CRUD OPERATIONS FOR USER

  DocumentReference _userDocRef(String uid) {
    return _usersCollection.doc(uid);
  }

  /// method checks if username already exists and that there are not duplicate
  /// usernames in the database
  Future<bool> isUsernameTaken(String username) async {
    final docSnapshot = await _usersCollection.doc(username.toLowerCase()).get();
    return docSnapshot.exists;
  }

  // --- CREATE USER WITH UNIQUE USERNAME CHECK ---
  Future<void> createUserWithUniqueUsername(UserModel user) async {
    // 1. Validate that the username is present and valid in the UserModel
    if (user.username == null || user.username!.trim().isEmpty) {
      throw ArgumentError('Username cannot be null or empty.');
    }
    final String lowerCaseUsername = user.username!.toLowerCase();

    // We are gonna use a transaction to make sure that all operations works
    // if one fails no changes will be done to the database
    return FirebaseFirestore.instance.runTransaction((transaction) async {

      //Checks if the username is available
      final usernameDocRef = _usersCollection.doc(lowerCaseUsername);
      final usernameDoc = await transaction.get(usernameDocRef);

      if (usernameDoc.exists) {
        throw Exception('Username "$lowerCaseUsername" is already taken.');
      }

      // if the username is available it will create a document
      final userDocRef = _userDocRef(user.uid);
      transaction.set(
        userDocRef,
        // Ensure that createdAt and lastActive use serverTimestamp for initial creation
        user.toMap().map((key, value) {
          if (key == 'createdAt' || key == 'lastActive') {
            return MapEntry(key, FieldValue.serverTimestamp());
          }
          return MapEntry(key, value);
        }),
        SetOptions(merge: true), // Use merge: true to avoid overwriting if partial data exists
      );

      //Reserve the username by creating a document in the 'usernames' collection
      transaction.set(usernameDocRef, {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    }).catchError((error) {
      // Handle errors from the transaction
      print("Failed to create user and reserve username: $error");
      throw Exception('An unexpected error occurred during user creation.');
    });
  }

  /**
   * This updates the username.
   */
  Future<void> updateUsername(String uid, String oldUsername, String newUsername) async {
    final String lowerCaseOldUsername = oldUsername.toLowerCase();
    final String lowerCaseNewUsername = newUsername.toLowerCase();

    // this makes sure that the old username and new one isnt the same.
    if (lowerCaseOldUsername == lowerCaseNewUsername) {
      return;
    }

    // Use a transaction for the update/delete of username record
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      //Check if the new username is taken
      final newUsernameDocRef = _usersCollection.doc(lowerCaseNewUsername);
      final newUsernameDoc = await transaction.get(newUsernameDocRef);

      if (newUsernameDoc.exists) {
        throw Exception('New username "$lowerCaseNewUsername" is already taken.');
      }

      //Delete the old username record
      final oldUsernameDocRef = _usersCollection.doc(lowerCaseOldUsername);
      transaction.delete(oldUsernameDocRef);

      //Create the new username record
      transaction.set(newUsernameDocRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});

      //Update the username in the user's main profile
      final userDocRef = _userDocRef(uid);
      transaction.update(userDocRef, {'username': newUsername});
    }).catchError((error) {
      print("Failed to update username: $error");
      throw Exception('An unexpected error occurred during username update.');
    });
  }

  // DELETE
  /**
   * makes sure that the user is deleted from the collection and removes their
   * username so it can be used when creating a new user later 
   */
  Future<void> deleteUserAndUsername(String uid, String username) async {
    final String lowerCaseUsername = username.toLowerCase();

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      // Delete the user's profile document
      final userDocRef = _userDocRef(uid);
      transaction.delete(userDocRef);

      // Delete the username record
      final usernameDocRef = _usersCollection.doc(lowerCaseUsername);
      transaction.delete(usernameDocRef);
    }).catchError((error) {
      print("Failed to delete user and username: $error");
      throw Exception('An unexpected error occurred during user and username deletion.');
    });
  }
}
