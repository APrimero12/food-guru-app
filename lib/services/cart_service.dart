// lib/services/cart_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CartService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _listsRef(String userId) =>
      _db.collection('carts').doc(userId).collection('lists');

  CollectionReference _itemsRef(String userId, String listId) =>
      _listsRef(userId).doc(listId).collection('items');

  // ── Lists ──────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> listsStream(String userId) => _listsRef(userId)
      .orderBy('createdAt', descending: false)
      .snapshots();

  Future<String> createList(String userId, String name) async {
    final doc = await _listsRef(userId).add({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> renameList(String userId, String listId, String newName) =>
      _listsRef(userId).doc(listId).update({'name': newName.trim()});

  Future<void> deleteList(String userId, String listId) async {
    // Delete all items in the subcollection first.
    const batchSize = 500;
    var snap = await _itemsRef(userId, listId).limit(batchSize).get();
    while (snap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
      snap = await _itemsRef(userId, listId).limit(batchSize).get();
    }
    await _listsRef(userId).doc(listId).delete();
  }

  // ── Items ──────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> itemsStream(String userId, String listId) =>
      _itemsRef(userId, listId)
          .orderBy('addedAt', descending: false)
          .snapshots();

  /// Adds one recipe's ingredient(s) to a list.
  /// [ingredients] is a list of maps with keys: name, amount, unit.
  Future<void> addRecipeToList({
    required String userId,
    required String listId,
    required String recipeId,
    required String recipeName,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    final batch = _db.batch();
    final now = Timestamp.now();
    for (final ing in ingredients) {
      final doc = _itemsRef(userId, listId).doc();
      batch.set(doc, {
        'recipeId':   recipeId,
        'recipeName': recipeName,
        'name':       (ing['name'] ?? '').toString(),
        'amount':     ing['amount'] ?? 0,
        'unit':       (ing['unit'] ?? '').toString(),
        'checked':    false,
        'addedAt':    now,
      });
    }
    await batch.commit();
  }

  Future<void> toggleItem({
    required String userId,
    required String listId,
    required String itemId,
    required bool checked,
  }) =>
      _itemsRef(userId, listId).doc(itemId).update({'checked': checked});

  Future<void> removeItem(String userId, String listId, String itemId) =>
      _itemsRef(userId, listId).doc(itemId).delete();

  Future<void> removeRecipeFromList(
      String userId, String listId, String recipeId) async {
    final snap = await _itemsRef(userId, listId)
        .where('recipeId', isEqualTo: recipeId)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearCheckedItems(String userId, String listId) async {
    final snap = await _itemsRef(userId, listId)
        .where('checked', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Returns list of all list docs (id + data) — used when showing the
  /// "pick a list" sheet from RecipeDetailPage.
  Future<List<Map<String, dynamic>>> getLists(String userId) async {
    final snap = await _listsRef(userId)
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }
}