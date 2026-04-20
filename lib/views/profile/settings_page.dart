import 'package:flutter/material.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/auth.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/views/login/login_screen.dart';

class SettingsPage extends StatefulWidget {
  final UserModel currentUser;
  final AuthService authService;
  final UserService userService;

  const SettingsPage({
    super.key,
    required this.currentUser,
    required this.authService,
    required this.userService,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;

  final TextEditingController _currentPasswordController =
  TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _showPasswordChange = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.currentUser.name ?? '');
    _usernameController =
        TextEditingController(text: widget.currentUser.username ?? '');
    _emailController =
        TextEditingController(text: widget.currentUser.email ?? '');
    _bioController =
        TextEditingController(text: widget.currentUser.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await widget.authService.signOut();
      _showSnackBar('Logged out successfully');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => SignInPage()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to log out: $e', isError: true);
      print('Failed to log out: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordChange() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1)); // TODO: real impl
      _showSnackBar('Password changed successfully');
      setState(() => _showPasswordChange = false);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showSnackBar('Failed to change password: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleProfileUpdate() async {
    final newName = _nameController.text;
    final newUsername = _usernameController.text;
    final newEmail = _emailController.text;
    final newBio = _bioController.text;

    if (newName.isEmpty || newUsername.isEmpty || newEmail.isEmpty) {
      _showSnackBar('Name, username, and email are required', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedData = {
        'name': newName,
        'username': newUsername,
        'email': newEmail,
        'bio': newBio,
      };
      await widget.userService.updateUser(widget.currentUser.uid, updatedData);
      _showSnackBar('Profile updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------ build --

  @override
  Widget build(BuildContext context) {
    // No Scaffold / AppBar here — MyExplorePage owns those.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  children: const [
                    Icon(Icons.settings, size: 32, color: Colors.orange),
                    SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Account Info card
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Account Information'),
                    const SizedBox(height: 16),
                    _buildAccountInfoRow(
                        'Name', widget.currentUser.name ?? 'Not Set'),
                    _buildAccountInfoRow(
                        'Username', widget.currentUser.username ?? 'Not Set'),
                    _buildAccountInfoRow(
                        'Email', widget.currentUser.email ?? 'Not Set'),
                  ],
                ),
              ),

              // Update Profile card
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Update Profile'),
                    const SizedBox(height: 16),
                    _buildInputField('Name', _nameController, 'John Doe',
                        isRequired: true),
                    _buildInputField(
                        'Username', _usernameController, 'johndoe',
                        isRequired: true),
                    _buildInputField(
                        'Email', _emailController, 'user@foodguru.com',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true),
                    _buildTextAreaField(
                        'Bio', _bioController, 'Tell us about yourself...'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleProfileUpdate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? _loadingIndicator()
                          : const Text('Update Profile'),
                    ),
                  ],
                ),
              ),

              // Change Password card
              _card(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                              () => _showPasswordChange = !_showPasswordChange),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock,
                                  size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Change Password',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600)),
                                  Text('Update your password',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),
                          Transform.rotate(
                            angle: _showPasswordChange ? 1.5708 : 0,
                            child: Icon(Icons.chevron_right,
                                size: 20, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    if (_showPasswordChange)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPasswordField(
                                'Current Password', _currentPasswordController),
                            _buildPasswordField(
                                'New Password', _newPasswordController),
                            _buildPasswordField('Confirm New Password',
                                _confirmPasswordController),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handlePasswordChange,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                  child: _isLoading
                                      ? _loadingIndicator()
                                      : const Text('Update Password'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                    setState(() {
                                      _showPasswordChange = false;
                                      _currentPasswordController
                                          .clear();
                                      _newPasswordController.clear();
                                      _confirmPasswordController
                                          .clear();
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: Colors.grey[400]!),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Logout card
              _card(
                child: InkWell(
                  onTap: _isLoading ? null : _handleLogout,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.logout,
                              size: 20, color: Colors.red),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Log Out',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red)),
                              Text('Sign out of your account',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right,
                          size: 20, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- helper widgets --

  Widget _card({required Widget child}) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(padding: const EdgeInsets.all(24.0), child: child),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600));

  Widget _loadingIndicator() => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  Widget _buildAccountInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInputField(
      String label,
      TextEditingController controller,
      String hintText, {
        TextInputType keyboardType = TextInputType.text,
        bool isRequired = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500),
            children: isRequired
                ? const [
              TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red))
            ]
                : null,
          )),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextAreaField(
      String label,
      TextEditingController controller,
      String hintText,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '••••••••',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}