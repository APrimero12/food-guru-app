// lib/services/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appdevproject/models/recipe_model.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/models/comments_model.dart';

class RecipeService {
  final CollectionReference _recipesCollection =
  FirebaseFirestore.instance.collection('recipes');

  DocumentReference _recipeDocRef(String recipeId) =>
      _recipesCollection.doc(recipeId);

  // ─── CREATE ───────────────────────────────────────────────────────────────

  /// Creates a new recipe document in Firestore.
  /// Returns the newly created document's ID.
  Future<String> createRecipe({
    required UserModel user,
    required String image,
    required String recipeName,
    required String description,
    required int prepTime,
    required int cookTime,
    required int servings,
    required Diffculty difficulty,
    required Category category,
    required DietaryResrictions dietaryRestrictions,
    required Ingredients ingredients,
    List<Instruction>? instructions,
  }) async {
    try {
      final docRef = _recipesCollection.doc(); // auto-generate ID

      final data = {
        'userId': user.uid,
        'userName': user.name,
        'userAvatar': user.avatar,
        'image': image,
        'recipeName': recipeName,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'difficulty': difficulty.name,
        'category': category.name,
        'dietaryRestrictions': dietaryRestrictions.name,
        'ingredients': _ingredientsToMap(ingredients),
        'instructions': instructions?.map((i) => i.steps).toList() ?? [],
      };

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      print('Error creating recipe: $e');
      throw Exception('Failed to create recipe: $e');
    }
  }

  // ─── READ ─────────────────────────────────────────────────────────────────

  /// Fetches a single recipe by its Firestore document ID.
  Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    try {
      final doc = await _recipeDocRef(recipeId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      print('Error fetching recipe $recipeId: $e');
      return null;
    }
  }

  /// Returns a real-time stream of all recipes, newest first.
  Stream<QuerySnapshot> getAllRecipesStream() {
    return _recipesCollection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fetches a paginated list of all recipes (one-time read).
  Future<List<Map<String, dynamic>>> getAllRecipes({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _recipesCollection
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching recipes: $e');
      return [];
    }
  }

  /// Fetches all recipes created by a specific user.
  Future<List<Map<String, dynamic>>> getRecipesByUser(String userId) async {
    try {
      final snapshot = await _recipesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching recipes for user $userId: $e');
      return [];
    }
  }

  /// Returns a real-time stream of recipes by a specific user.
  Stream<QuerySnapshot> getRecipesByUserStream(String userId) {
    return _recipesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fetches recipes filtered by category.
  Future<List<Map<String, dynamic>>> getRecipesByCategory(
      Category category) async {
    try {
      final snapshot = await _recipesCollection
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching recipes by category: $e');
      return [];
    }
  }

  /// Fetches recipes filtered by dietary restriction.
  Future<List<Map<String, dynamic>>> getRecipesByDietaryRestriction(
      DietaryResrictions restriction) async {
    try {
      final snapshot = await _recipesCollection
          .where('dietaryRestrictions', isEqualTo: restriction.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching recipes by restriction: $e');
      return [];
    }
  }

  /// Fetches the recipes a user has liked.
  /// Requires a separate 'likes' subcollection or a 'likedBy' field.
  Future<List<Map<String, dynamic>>> getLikedRecipes(String userId) async {
    try {
      // Queries a top-level 'user_likes' collection where each doc is
      // "{userId}_{recipeId}" — adjust to match your Firestore schema.
      final snapshot = await FirebaseFirestore.instance
          .collection('user_likes')
          .where('userId', isEqualTo: userId)
          .get();

      final recipeIds =
      snapshot.docs.map((d) => d['recipeId'] as String).toList();

      if (recipeIds.isEmpty) return [];

      // Firestore 'whereIn' supports up to 30 values at once.
      final chunks = <List<String>>[];
      for (var i = 0; i < recipeIds.length; i += 30) {
        chunks.add(recipeIds.sublist(
            i, i + 30 > recipeIds.length ? recipeIds.length : i + 30));
      }

      final results = <Map<String, dynamic>>[];
      for (final chunk in chunks) {
        final recipeSnap = await _recipesCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(recipeSnap.docs.map(
                (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}));
      }
      return results;
    } catch (e) {
      print('Error fetching liked recipes for $userId: $e');
      return [];
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────

  /// Updates specific fields on a recipe document.
  Future<void> updateRecipe(
      String recipeId, Map<String, dynamic> updatedFields) async {
    try {
      await _recipeDocRef(recipeId).update({
        ...updatedFields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating recipe $recipeId: $e');
      throw Exception('Failed to update recipe: $e');
    }
  }

  /// Toggles a like on a recipe. Uses a transaction to keep the like count accurate.
  /// Stores likes in a top-level 'user_likes' collection for easy querying.
  Future<void> toggleLike(String recipeId, String userId) async {
    final likeDocRef = FirebaseFirestore.instance
        .collection('user_likes')
        .doc('${userId}_$recipeId');

    final recipeRef = _recipeDocRef(recipeId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final likeSnap = await transaction.get(likeDocRef);
      final recipeSnap = await transaction.get(recipeRef);

      if (!recipeSnap.exists) throw Exception('Recipe not found.');

      if (likeSnap.exists) {
        // Already liked — remove the like
        transaction.delete(likeDocRef);
        transaction.update(recipeRef, {'likes': FieldValue.increment(-1)});
      } else {
        // Not yet liked — add the like
        transaction.set(likeDocRef, {
          'userId': userId,
          'recipeId': recipeId,
          'likedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(recipeRef, {'likes': FieldValue.increment(1)});
      }
    });
  }

  /// Checks whether a given user has liked a recipe.
  Future<bool> isLikedByUser(String recipeId, String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_likes')
        .doc('${userId}_$recipeId')
        .get();
    return doc.exists;
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────

  /// Deletes a recipe document and its associated comments subcollection.
  Future<void> deleteRecipe(String recipeId, String userId) async {
    try {
      final recipeRef = _recipeDocRef(recipeId);
      final recipeSnap = await recipeRef.get();

      if (!recipeSnap.exists) throw Exception('Recipe not found.');

      final data = recipeSnap.data() as Map<String, dynamic>;
      if (data['userId'] != userId) {
        throw Exception('Unauthorized: you can only delete your own recipes.');
      }

      // Delete comments subcollection first (Firestore does not cascade deletes)
      await _deleteSubcollection(recipeRef, 'comments');

      // Delete any likes tied to this recipe
      final likesSnap = await FirebaseFirestore.instance
          .collection('user_likes')
          .where('recipeId', isEqualTo: recipeId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in likesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(recipeRef);
      await batch.commit();
    } catch (e) {
      print('Error deleting recipe $recipeId: $e');
      throw Exception('Failed to delete recipe: $e');
    }
  }

  // ─── COMMENTS ─────────────────────────────────────────────────────────────

  /// Adds a comment to a recipe's 'comments' subcollection.
  Future<void> addComment({
    required String recipeId,
    required String userId,
    required String userName,
    required String message,
  }) async {
    try {
      await _recipeDocRef(recipeId).collection('comments').add({
        'userId': userId,
        'userName': userName,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Returns a real-time stream of comments for a recipe, oldest first.
  Stream<QuerySnapshot> getCommentsStream(String recipeId) {
    return _recipeDocRef(recipeId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Deletes a specific comment from a recipe's subcollection.
  Future<void> deleteComment(String recipeId, String commentId) async {
    try {
      await _recipeDocRef(recipeId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      print('Error deleting comment $commentId: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  // ─── PRIVATE HELPERS ──────────────────────────────────────────────────────

  Map<String, dynamic> _ingredientsToMap(Ingredients ingredients) {
    return {
      'id': ingredients.id,
      'name': ingredients.name,
      'amount': ingredients.amount,
      'unit': ingredients.unit,
    };
  }

  /// Deletes all documents in a subcollection in batches of 500.
  Future<void> _deleteSubcollection(
      DocumentReference parent, String subcollectionName) async {
    const batchSize = 500;
    var snapshot =
    await parent.collection(subcollectionName).limit(batchSize).get();

    while (snapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
      snapshot = await parent
          .collection(subcollectionName)
          .limit(batchSize)
          .get();
    }
  }
}