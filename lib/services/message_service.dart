// lib/services/message_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Conversation ID ────────────────────────────────────────────────────────
  // Deterministic: always sorted so both users share the same document.
  String conversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  DocumentReference _convoRef(String uid1, String uid2) => _db
      .collection('conversations')
      .doc(conversationId(uid1, uid2));

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final convoRef = _convoRef(senderId, receiverId);
    final msgRef   = convoRef.collection('messages').doc();

    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId':   senderId,
      'receiverId': receiverId,
      'text':       text,
      'createdAt':  FieldValue.serverTimestamp(),
      'read':       false,
    });

    // Update / create the conversation summary so listing conversations is fast.
    batch.set(
      convoRef,
      {
        'participants':            [senderId, receiverId],
        'lastMessage':             text,
        'lastSenderId':            senderId,
        'updatedAt':               FieldValue.serverTimestamp(),
        'unread_$receiverId':      FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Mark read ──────────────────────────────────────────────────────────────

  Future<void> markRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final convoRef = _convoRef(currentUserId, otherUserId);

    // Use set+merge so this is a no-op if the conversation doc doesn't exist yet.
    await convoRef.set(
      {'unread_$currentUserId': 0},
      SetOptions(merge: true),
    );

    final snap = await convoRef
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .limit(500)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Live list of conversation summaries for [userId], newest first.
  Stream<QuerySnapshot> conversationsStream(String userId) => _db
      .collection('conversations')
      .where('participants', arrayContains: userId)
      .orderBy('updatedAt', descending: true)
      .snapshots();

  /// Live message thread between two users.
  Stream<QuerySnapshot> messagesStream(String uid1, String uid2) =>
      _convoRef(uid1, uid2)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots();

  /// Unread count for [currentUserId] extracted from a conversation doc.
  int unreadCount(Map<String, dynamic> data, String currentUserId) =>
      (data['unread_$currentUserId'] as num?)?.toInt() ?? 0;
}
