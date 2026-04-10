class MessagesModel {

  int messageId;
  int senderId;
  int receiverId;
  String message;
  String createdAt;
  bool read;

  MessagesModel(this.messageId, this.senderId, this.receiverId, this.message,
      this.createdAt, this.read);

  @override
  String toString() {
    return 'MessagesModel{messageId: $messageId, senderId: $senderId, receiverId: $receiverId, message: $message, createdAt: $createdAt, read: $read}';
  }
}
