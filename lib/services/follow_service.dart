// lib/services/follow_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appdevproject/models/user_model.dart';

class FollowService {
  final CollectionReference _followsCollection =
  FirebaseFirestore.instance.collection('follows');
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  // Document ID is deterministic so we can get/delete without querying.
  String _docId(String followerId, String followingId) =>
      '${followerId}_$followingId';

  // ── write ──────────────────────────────────────────────────────────────────

  Future<void> followUser(String followerId, String followingId) async {
    await _followsCollection.doc(_docId(followerId, followingId)).set({
      'followerId':  followerId,
      'followingId': followingId,
      'createdAt':   FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    await _followsCollection
        .doc(_docId(followerId, followingId))
        .delete();
  }

  // ── read ───────────────────────────────────────────────────────────────────

  Future<bool> isFollowing(String followerId, String followingId) async {
    final doc = await _followsCollection
        .doc(_docId(followerId, followingId))
        .get();
    return doc.exists;
  }

  /// Returns a set of user IDs the current user is following.
  /// Used to cheaply check follow state without fetching full user objects.
  Future<Set<String>> getFollowingIds(String userId) async {
    final snapshot = await _followsCollection
        .where('followerId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((d) => d['followingId'] as String)
        .toSet();
  }

  Future<int> getFollowingCount(String userId) async {
    final snapshot = await _followsCollection
        .where('followerId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getFollowersCount(String userId) async {
    final snapshot = await _followsCollection
        .where('followingId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Returns full UserModel objects for everyone [userId] is following.
  Future<List<UserModel>> getFollowing(String userId) async {
    final snapshot = await _followsCollection
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final ids = snapshot.docs
        .map((d) => d['followingId'] as String)
        .toList();

    return _fetchUsers(ids);
  }

  /// Returns full UserModel objects for everyone following [userId].
  Future<List<UserModel>> getFollowers(String userId) async {
    final snapshot = await _followsCollection
        .where('followingId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final ids = snapshot.docs
        .map((d) => d['followerId'] as String)
        .toList();

    return _fetchUsers(ids);
  }

  /// Returns users the current user has NOT yet followed, for the Discover tab.
  Future<List<UserModel>> getDiscoverUsers(String currentUserId,
      {int limit = 20}) async {
    // Get who the user already follows (+ themselves).
    final alreadyFollowing = await getFollowingIds(currentUserId);
    alreadyFollowing.add(currentUserId);

    // Fetch a batch of users and filter client-side.
    final snapshot = await _usersCollection
        .limit(limit + alreadyFollowing.length)
        .get();

    return snapshot.docs
        .where((d) => !alreadyFollowing.contains(d.id))
        .take(limit)
        .map((d) {
      try {
        return UserModel.fromFirestore(d);
      } catch (_) {
        return null;
      }
    })
        .whereType<UserModel>()
        .toList();
  }

  // ── private ────────────────────────────────────────────────────────────────

  Future<List<UserModel>> _fetchUsers(List<String> ids) async {
    if (ids.isEmpty) return [];

    final docs = await Future.wait(
      ids.map((id) => _usersCollection.doc(id).get()),
    );

    return docs
        .where((d) => d.exists)
        .map((d) {
      try {
        return UserModel.fromFirestore(d);
      } catch (_) {
        return null;
      }
    })
        .whereType<UserModel>()
        .toList();
  }
}