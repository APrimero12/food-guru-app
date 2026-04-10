import 'user_model.dart';

class CommentsModel {

  int commentId;
  UserModel id;
  String message;
  String createdAt;

  CommentsModel(this.commentId, this.id, this.message, this.createdAt);

  @override
  String toString() {
    return 'CommentsModel{commentId: $commentId, id: $id, message: $message, createdAt: $createdAt}';
  }
}
