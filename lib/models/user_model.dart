class UserModel {

  int userId;
  String email;
  String username;
  String password;
  String fName;
  String lName;

  UserModel(this.userId, this.email, this.username, this.password, this.fName,
      this.lName);

  @override
  String toString() {
    return 'UserModel{userId: $userId, email: $email, username: $username, password: $password, fName: $fName, lName: $lName}';
  }

}