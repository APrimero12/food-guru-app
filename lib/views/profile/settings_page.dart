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
  // Controllers for the "Update Profile" form
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;

  // Controllers for the "Change Password" form
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showPasswordChange = false;
  bool _isLoading = false; // To disable buttons during API calls

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current user data
    _nameController = TextEditingController(text: widget.currentUser.name ?? '');
    _usernameController = TextEditingController(text: widget.currentUser.username ?? '');
    _emailController = TextEditingController(text: widget.currentUser.email ?? '');
    _bioController = TextEditingController(text: widget.currentUser.bio ?? '');
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Handlers ---

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.authService.signOut();
      _showSnackBar('Logged out successfully');
      // Navigate to login page and remove all previous routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => SignInPage()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to log out: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // TODO: MAKE SURE PASSWORD CHANGE WORKS IN HERE

  Future<void> _handlePasswordChange() async {
    // Placeholder for password change logic
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

    setState(() {
      _isLoading = true;
    });

    try {
      print('Attempting to change password...');
      print('Current Password: $currentPassword');
      print('New Password: $newPassword');
      // In a real app, you would reauthenticate and update password here:
      // await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(EmailAuthProvider.credential(email: currentUser.email!, password: currentPassword));
      // await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      _showSnackBar('Password changed successfully');
      setState(() {
        _showPasswordChange = false;
      });
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showSnackBar('Failed to change password: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleProfileUpdate() async {
    // Placeholder for profile update logic
    final newName = _nameController.text;
    final newUsername = _usernameController.text;
    final newEmail = _emailController.text;
    final newBio = _bioController.text;

    if (newName.isEmpty || newUsername.isEmpty || newEmail.isEmpty) {
      _showSnackBar('Name, username, and email are required', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = {
        'name': newName,
        'username': newUsername,
        'email': newEmail,
        'bio': newBio,
      };
      await widget.userService.updateUser(widget.currentUser.uid, updatedData);
      _showSnackBar('Profile updated successfully');

      // TODO: In a real app, you might want to update the currentUser object
      // in your state management solution (e.g., Provider) after a successful update
      // so that other parts of the app (like ProfilePage) reflect the changes.

    } catch (e) {
      _showSnackBar('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // container mx-auto px-4 py-8
        child: Align( // max-w-2xl mx-auto
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // Max width for content
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (flex items-center gap-3 mb-6)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    children: const [
                      Icon(Icons.settings, size: 32, color: Colors.orange), // SettingsIcon
                      SizedBox(width: 12), // gap-3
                      Text(
                        'Settings',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), // text-3xl font-bold
                      ),
                    ],
                  ),
                ),

                // space-y-4
                Column(
                  children: [
                    // Account Info Card
                    Card( // Card p-6
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 16), // space-y-4
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Information', // h2 text-xl font-semibold mb-4
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16), // mb-4
                            Column( // space-y-3
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAccountInfoRow('Name', widget.currentUser.name ?? 'Not Set'),
                                _buildAccountInfoRow('Username', widget.currentUser.username ?? 'Not Set'),
                                _buildAccountInfoRow('Email', widget.currentUser.email ?? 'Not Set'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Update Profile Card
                    Card( // Card p-6
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 16), // space-y-4
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update Profile', // h2 text-xl font-semibold mb-4
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16), // mb-4
                            Form( // form space-y-4
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInputField(
                                    'Name',
                                    _nameController,
                                    'John Doe',
                                    isRequired: true,
                                  ),
                                  _buildInputField(
                                    'Username',
                                    _usernameController,
                                    'johndoe',
                                    isRequired: true,
                                  ),
                                  _buildInputField(
                                    'Email',
                                    _emailController,
                                    'user@foodguru.com',
                                    keyboardType: TextInputType.emailAddress,
                                    isRequired: true,
                                  ),
                                  _buildTextAreaField(
                                    'Bio',
                                    _bioController,
                                    'Tell us about yourself...',
                                  ),
                                  const SizedBox(height: 16), // gap-3
                                  Row(
                                    children: [
                                      ElevatedButton( // Button type="submit"
                                        onPressed: _isLoading ? null : _handleProfileUpdate,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                            : const Text('Update Profile'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Change Password Card
                    Card( // Card p-6
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 16), // space-y-4
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            GestureDetector( // button w-full flex items-center justify-between text-left
                              onTap: () {
                                setState(() {
                                  _showPasswordChange = !_showPasswordChange;
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row( // flex items-center gap-3
                                    children: [
                                      Icon(Icons.lock, size: 20, color: Colors.grey[600]), // Lock
                                      const SizedBox(width: 12), // gap-3
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Change Password', // h2 text-xl font-semibold
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            'Update your password', // text-sm text-gray-600
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Transform.rotate( // ChevronRight transition-transform
                                    angle: _showPasswordChange ? 1.5708 : 0, // Rotate 90 degrees (pi/2 radians)
                                    child: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                            if (_showPasswordChange) // mt-6 space-y-4
                              Padding(
                                padding: const EdgeInsets.only(top: 24.0),
                                child: Form(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildPasswordField(
                                        'Current Password',
                                        _currentPasswordController,
                                      ),
                                      _buildPasswordField(
                                        'New Password',
                                        _newPasswordController,
                                      ),
                                      _buildPasswordField(
                                        'Confirm New Password',
                                        _confirmPasswordController,
                                      ),
                                      const SizedBox(height: 16),
                                      Row( // flex gap-3
                                        children: [
                                          ElevatedButton( // Button type="submit"
                                            onPressed: _isLoading ? null : _handlePasswordChange,
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                                : const Text('Update Password'),
                                          ),
                                          const SizedBox(width: 12), // gap-3
                                          OutlinedButton( // Button variant="outline"
                                            onPressed: _isLoading ? null : () {
                                              setState(() {
                                                _showPasswordChange = false;
                                                _currentPasswordController.clear();
                                                _newPasswordController.clear();
                                                _confirmPasswordController.clear();
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.grey[400]!),
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Logout Card
                    Card( // Card p-6
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell( // button w-full flex items-center justify-between text-left group
                        onTap: _isLoading ? null : _handleLogout,
                        borderRadius: BorderRadius.circular(12), // Match card border radius
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row( // flex items-center gap-3
                                children: [
                                  const Icon(Icons.logout, size: 20, color: Colors.red), // LogOut text-red-500
                                  const SizedBox(width: 12), // gap-3
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Log Out', // h2 text-xl font-semibold text-red-500
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.red),
                                      ),
                                      Text(
                                        'Sign out of your account', // text-sm text-gray-600
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]), // ChevronRight
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for Form Fields ---

  Widget _buildAccountInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0), // space-y-3
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, // p text-sm text-gray-600
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value, // p font-medium
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
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
      padding: const EdgeInsets.only(bottom: 16.0), // space-y-4
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label, // label htmlFor="name" block text-sm font-medium mb-2
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              children: isRequired
                  ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                  : null,
            ),
          ),
          const SizedBox(height: 8), // mb-2
          TextField( // Input type="text"
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.only(bottom: 16.0), // space-y-4
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, // label htmlFor="bio" block text-sm font-medium mb-2
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8), // mb-2
          TextField( // Textarea
            controller: controller,
            maxLines: 4, // Simulate a textarea
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignLabelWithHint: true, // Aligns hint text to top for multiline
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // space-y-4
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, // label htmlFor="currentPassword" block text-sm font-medium mb-2
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8), // mb-2
          TextField( // Input type="password"
            controller: controller,
            obscureText: true, // Hides password input
            decoration: InputDecoration(
              hintText: '••••••••',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
