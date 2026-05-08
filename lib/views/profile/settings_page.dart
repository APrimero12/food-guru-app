import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/auth.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/views/login/login_screen.dart';

// ─── Cloudinary config ────────────────────────────────────────────────────────
// Replace these two values with your own from cloudinary.com → Settings → Upload
const String _cloudinaryCloudName = 'dhagylhdk';
const String _cloudinaryUploadPreset = 'FoodGuru';
// ─────────────────────────────────────────────────────────────────────────────

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

  /// Freshly-picked image waiting to be uploaded.
  File? _pendingAvatarFile;

  /// Upload progress 0.0–1.0; null when not uploading.
  double? _uploadProgress;

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

  // ── Snackbar ─────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ── Avatar helpers ────────────────────────────────────────────────────────

  void _showAvatarOptions(UserModel liveUser) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.photo_library, color: Colors.orange),
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (liveUser.avatar != null && liveUser.avatar!.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child:
                    Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Remove photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar(liveUser);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pendingAvatarFile = File(picked.path));
  }

  /// Uploads [_pendingAvatarFile] to Cloudinary and returns the secure URL.
  /// Progress is tracked via chunked reads of the file.
  Future<String> _uploadToCloudinary(String uid) async {
    final file = _pendingAvatarFile!;
    final bytes = await file.readAsBytes();
    final total = bytes.length;

    // Cloudinary unsigned upload endpoint
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

    // Use a fixed public_id so re-uploads overwrite the old image
    // (no orphaned files accumulate in your Cloudinary account).
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['folder'] = 'foodguru/profile_pictures'
      ..fields['public_id'] =
          'avatars/${uid}_${DateTime.now().millisecondsSinceEpoch}'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '$uid.jpg',
      ));

    // Fake progress: show determinate bar while awaiting the response.
    setState(() => _uploadProgress = 0.1);

    final streamedResponse = await request.send();

    setState(() => _uploadProgress = 0.8);

    final body = await streamedResponse.stream.bytesToString();

    setState(() => _uploadProgress = 1.0);

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${streamedResponse.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    // secure_url is always HTTPS and includes a CDN-optimised URL
    return json['secure_url'] as String;
  }

  Future<void> _uploadAvatar(UserModel liveUser) async {
    if (_pendingAvatarFile == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final downloadUrl = await _uploadToCloudinary(liveUser.uid);

      await widget.userService
          .updateUser(liveUser.uid, {'avatar': downloadUrl});

      final updatedUser = UserModel(
        uid: liveUser.uid,
        name: liveUser.name,
        username: liveUser.username,
        email: liveUser.email,
        bio: liveUser.bio,
        avatar: downloadUrl,
        createdAt: liveUser.createdAt,
        lastActive: liveUser.lastActive,
      );

      if (mounted) {
        Provider.of<UserProvider>(context, listen: false)
            .updateLocalUser(updatedUser);
        setState(() {
          _pendingAvatarFile = null;
          _uploadProgress = null;
        });
        _showSnackBar('Avatar updated!');
      }
    } catch (e) {
      _showSnackBar('Failed to upload avatar: $e', isError: true);
      setState(() => _uploadProgress = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAvatar(UserModel liveUser) async {
    setState(() => _isLoading = true);
    try {
      await widget.userService.updateUser(liveUser.uid, {'avatar': ''});

      final updatedUser = UserModel(
        uid: liveUser.uid,
        name: liveUser.name,
        username: liveUser.username,
        email: liveUser.email,
        bio: liveUser.bio,
        avatar: '',
        createdAt: liveUser.createdAt,
        lastActive: liveUser.lastActive,
      );

      if (mounted) {
        Provider.of<UserProvider>(context, listen: false)
            .updateLocalUser(updatedUser);
        setState(() => _pendingAvatarFile = null);
        _showSnackBar('Avatar removed.');
      }
    } catch (e) {
      _showSnackBar('Failed to remove avatar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await widget.authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => SignInPage()),
              (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to log out: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Password change ───────────────────────────────────────────────────────

  Future<void> _handlePasswordChange() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _showSnackBar('Please enter your current password.', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No logged-in user found.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _showSnackBar('Password changed successfully.');
      setState(() => _showPasswordChange = false);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' => 'Current password is incorrect.',
        'weak-password' => 'New password is too weak.',
        'requires-recent-login' =>
        'Please log out and log back in before changing your password.',
        _ => 'Failed to change password: ${e.message}',
      };
      _showSnackBar(msg, isError: true);
    } catch (e) {
      _showSnackBar('Failed to change password: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Profile update ────────────────────────────────────────────────────────

  Future<void> _handleProfileUpdate(UserModel liveUser) async {
    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newBio = _bioController.text.trim();

    if (newName.isEmpty || newUsername.isEmpty || newEmail.isEmpty) {
      _showSnackBar('Name, username, and email are required.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upload pending avatar first so the URL is included in the update.
      if (_pendingAvatarFile != null) {
        await _uploadAvatar(liveUser);
        liveUser =
            Provider.of<UserProvider>(context, listen: false).currentUser ??
                liveUser;
      }

      await widget.userService.updateUser(liveUser.uid, {
        'name': newName,
        'username': newUsername,
        'email': newEmail,
        'bio': newBio,
      });

      final updatedUser = UserModel(
        uid: liveUser.uid,
        name: newName,
        username: newUsername,
        email: newEmail,
        bio: newBio,
        avatar: liveUser.avatar,
        createdAt: liveUser.createdAt,
        lastActive: liveUser.lastActive,
      );

      if (mounted) {
        Provider.of<UserProvider>(context, listen: false)
            .updateLocalUser(updatedUser);
        _showSnackBar('Profile updated successfully.');
      }
    } catch (e) {
      _showSnackBar('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liveUser =
        context.watch<UserProvider>().currentUser ?? widget.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: const [
                    Icon(Icons.settings, size: 32, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Settings',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // ── Account Information (live)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Account Information'),
                    const SizedBox(height: 16),
                    _buildAccountInfoRow(
                        'Name', liveUser.name ?? 'Not Set'),
                    _buildAccountInfoRow(
                        'Username', liveUser.username ?? 'Not Set'),
                    _buildAccountInfoRow(
                        'Email', liveUser.email ?? 'Not Set'),
                  ],
                ),
              ),

              // ── Update Profile
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Update Profile'),
                    const SizedBox(height: 24),

                    // ── Avatar picker ──────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showAvatarOptions(liveUser),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 52,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _pendingAvatarFile != null
                                      ? FileImage(_pendingAvatarFile!)
                                  as ImageProvider
                                      : (liveUser.avatar != null &&
                                      liveUser.avatar!.isNotEmpty
                                      ? NetworkImage(liveUser.avatar!)
                                      : null),
                                  child: (_pendingAvatarFile == null &&
                                      (liveUser.avatar == null ||
                                          liveUser.avatar!.isEmpty))
                                      ? Text(
                                    liveUser.name != null &&
                                        liveUser.name!.isNotEmpty
                                        ? liveUser.name![0]
                                        .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54),
                                  )
                                      : null,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.camera_alt,
                                      size: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Tap to change photo',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),

                          // Upload progress bar
                          if (_uploadProgress != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _uploadProgress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[200],
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Uploading…',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],

                          // Pending-upload notice
                          if (_pendingAvatarFile != null &&
                              _uploadProgress == null) ...[
                            const SizedBox(height: 10),
                            Chip(
                              avatar: const Icon(Icons.info_outline,
                                  size: 14, color: Colors.orange),
                              label: const Text(
                                'New photo saves with Update Profile',
                                style: TextStyle(fontSize: 11),
                              ),
                              backgroundColor: const Color(0xFFFFF3E0),
                              side: BorderSide.none,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // ── end avatar picker ──────────────────────────────────

                    const SizedBox(height: 24),
                    _buildInputField(
                        'Name', _nameController, 'John Doe',
                        isRequired: true),
                    _buildInputField(
                        'Username', _usernameController, 'johndoe',
                        isRequired: true),
                    _buildInputField(
                        'Email', _emailController, 'user@foodguru.com',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true),
                    _buildTextAreaField('Bio', _bioController,
                        'Tell us about yourself...'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _handleProfileUpdate(liveUser),
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

              // ── Change Password
              _card(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() =>
                      _showPasswordChange = !_showPasswordChange),
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
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPasswordField('Current Password',
                                _currentPasswordController),
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
                                      : () => setState(() {
                                    _showPasswordChange = false;
                                    _currentPasswordController
                                        .clear();
                                    _newPasswordController.clear();
                                    _confirmPasswordController
                                        .clear();
                                  }),
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

              // ── Logout
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

  // ── helper widgets ────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Card(
    elevation: 2,
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600));

  Widget _loadingIndicator() => const SizedBox(
    width: 20,
    height: 20,
    child:
    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  Widget _buildAccountInfoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildInputField(
      String label,
      TextEditingController controller,
      String hintText, {
        TextInputType keyboardType = TextInputType.text,
        bool isRequired = false,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildTextAreaField(
      String label,
      TextEditingController controller,
      String hintText,
      ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildPasswordField(
      String label, TextEditingController controller) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
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