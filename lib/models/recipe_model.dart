import 'comments_model.dart';
import 'user_model.dart';

class RecipeModel {

  // this is what is related to the recipe post.
  int recipeId;
  UserModel user;
  String image;
  String recipeName;
  String description;
  String createdAt;
  int likes;
  CommentsModel comments;

  // this is what has to do with the recipe
  int prepTime;
  int cookeTime;
  int servings;
  Diffculty diffculty;
  Category category;
  DietaryResrictions dietaryRestrictions;
  Ingredients ingredients;

  RecipeModel(this.recipeId, this.user, this.image, this.recipeName,
      this.description, this.createdAt, this.likes, this.comments,
      this.prepTime, this.cookeTime, this.servings, this.diffculty,
      this.category, this.dietaryRestrictions, this.ingredients);
}

class Ingredients {

  int id;
  String name;
  int amount;
  String unit;

  Ingredients(this.id, this.name, this.amount, this.unit);
}

class Instruction {
  String steps;

  Instruction(this.steps);
}

enum Diffculty {
  Beginner, Easy, Medium, Hard;
}

enum Category {
  Breakfast, Lunch, Dinner, Snacks, Desserts, Appetizers, Salads, Soups;
}

enum DietaryResrictions {
  Dairy, Gluten, Nuts, Vegan, Vegetarian, Fish;
  // TODO: Can add more restrictions if needed
}
