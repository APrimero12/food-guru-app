import 'package:appdevproject/models/recipe_model.dart';
import 'package:appdevproject/models/user_model.dart';

class CartModel {

  int id;
  UserModel userCart;
  Ingredients ingredients;

  CartModel(this.id, this.userCart, this.ingredients);

  @override
  String toString() {
    return 'CartModel{id: $id, userCart: $userCart, ingredients: $ingredients}';
  }
}