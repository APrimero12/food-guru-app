import 'package:flutter/material.dart';
import 'package:appdevproject/models/user_model.dart';

class ProfilePage extends StatelessWidget {
  final UserModel user;

  /// Called when the user taps the Settings button.
  final VoidCallback? onSettingsTapped;

  /// Called when the user taps View Community — switches to the Friends tab.
  final VoidCallback? onCommunityTapped;

  const ProfilePage({
    super.key,
    required this.user,
    this.onSettingsTapped,
    this.onCommunityTapped,
  });

  Widget _buildStatItem(
      IconData icon, Color iconColor, String count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: count,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' '),
              TextSpan(text: label),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const int userRecipesCount = 0;
    const int likedRecipesCount = 0;
    const int followingCount = 0;
    const int followersCount = 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange, Colors.red],
              ),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile card overlapping the gradient
                Transform.translate(
                  offset: const Offset(0.0, -80.0),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.grey[300],
                              backgroundImage:
                              user.avatar != null && user.avatar!.isNotEmpty
                                  ? NetworkImage(user.avatar!)
                                  : null,
                              child: (user.avatar == null ||
                                  user.avatar!.isEmpty)
                                  ? Text(
                                user.name != null &&
                                    user.name!.isNotEmpty
                                    ? user.name![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name & username
                          Text(
                            user.name ?? 'Guest User',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            user.username != null
                                ? '@${user.username}'
                                : '@unknown',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Bio
                          if (user.bio != null && user.bio!.isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                user.bio!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Stats
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16.0,
                            runSpacing: 8.0,
                            children: [
                              _buildStatItem(Icons.restaurant_menu,
                                  Colors.orange, '$userRecipesCount', 'Recipes'),
                              _buildStatItem(Icons.favorite, Colors.red,
                                  '$likedRecipesCount', 'Liked'),
                              GestureDetector(
                                onTap: onCommunityTapped,
                                child: _buildStatItem(Icons.people,
                                    Colors.blue, '$followingCount', 'Following'),
                              ),
                              GestureDetector(
                                onTap: onCommunityTapped,
                                child: _buildStatItem(Icons.people,
                                    Colors.green, '$followersCount', 'Followers'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Action buttons
                          Wrap(
                            spacing: 12.0,
                            runSpacing: 12.0,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                // Navigate to the Friends tab
                                onPressed: onCommunityTapped,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Theme.of(context).primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.people_alt,
                                    size: 20, color: Colors.white),
                                label: const Text('View Community',
                                    style:
                                    TextStyle(color: Colors.white)),
                              ),
                              OutlinedButton.icon(
                                onPressed: onSettingsTapped,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.grey[400]!),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.settings,
                                    size: 20, color: Colors.black87),
                                label: const Text('Settings',
                                    style: TextStyle(
                                        color: Colors.black87)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}