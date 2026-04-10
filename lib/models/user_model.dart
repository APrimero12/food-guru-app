class UserModel {

  int userId;
  String name;
  String username;
  String email;
  String password;
  String avatar;
  String bio;

  UserModel(this.userId, this.name, this.username, this.email, this.password,
      this.avatar, this.bio);

  @override
  String toString() {
    return 'UserModel{userId: $userId, name: $name, username: $username, email: $email, password: $password, avatar: $avatar, bio: $bio}';
  }
}
