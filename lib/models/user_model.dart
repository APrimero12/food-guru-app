// lib/models/user_model.dart (or wherever you keep your models)
import 'package:firebase_auth/firebase_auth.dart'; // Add this line
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp and DocumentSnapshot

class UserModel {
  final String uid; // Use Firebase Authentication's unique User ID (String)
  final String? name; // Can come from Firebase User.displayName
  final String? username; // Custom field, might be set later
  final String? email; // Can come from Firebase User.email
  final String? avatar; // Can come from Firebase User.photoURL
  final String? bio; // Custom field, might be set later
  final Timestamp? createdAt; // When the user record was first created in Firestore
  final Timestamp? lastActive; // Optional: To track last activity

  // Constructor
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
}
