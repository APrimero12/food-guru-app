// lib/views/profile/myprofile_page.dart
import 'package:appdevproject/views/profile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:appdevproject/models/user_model.dart';    // Import UserModel
// import 'package:appdevproject/components/custom_badge.dart'; // Import custom badge (if you use it for counts)
// import 'package:appdevproject/components/recipe_card.dart'; // Not needed for just the profile card

class ProfilePage extends StatelessWidget {
  final UserModel user; // ProfilePage now requires a UserModel to be passed in

  const ProfilePage({super.key, required this.user}); // Constructor takes user

  // Helper method to build stat items (Recipes, Liked, Following, Followers)
  Widget _buildStatItem(IconData icon, Color iconColor, String count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Make row take minimum space
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
              const TextSpan(text: ' '), // Space between count and label
              TextSpan(text: label),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Default/Placeholder Values ---
    // These will be replaced with actual fetched data later.
    // For now, they provide a visual representation.
    final int userRecipesCount = 0;   // Default to 0 recipes
    final int likedRecipesCount = 0;  // Default to 0 liked recipes
    final int followingCount = 0;     // Default to 0 following
    final int followersCount = 0;     // Default to 0 followers

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Header background gradient (h-48 equivalent)
        Container(
        height: 150, // Corresponds to h-48 in Tailwind, adjusted for -mt-20 effect
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange, Colors.red],
          ),
        ),
      ),

      // Main content area with overlapping card (container mx-auto px-4 equivalent)
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // px-4
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // User Info Card (overlapping the gradient, -mt-20 equivalent)
          Transform.translate(
          offset: const Offset(0.0, -80.0), // Adjusted to visually overlap correctly
          child: Card(
              elevation: 6, // shadow-lg equivalent
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 0), // Remove default card margin to control spacing
              child: Padding(
                padding: const EdgeInsets.all(24.0), // p-6 equivalent
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // text-center for smaller screens
                  children: [
                // Avatar
                Container(
                decoration: BoxDecoration(
                shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4), // border-4 border-white
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26, // shadow-lg
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 64, // w-32 h-32 -> radius is half
                  backgroundColor: Colors.grey[300], // Fallback background
                  backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                      ? NetworkImage(user.avatar!) // Use user.avatar
                      : null,
                  child: (user.avatar == null || user.avatar!.isEmpty)
                      ? Text(
                    user.name != null && user.name!.isNotEmpty ? user.name![0].toUpperCase() : '?', // AvatarFallback
                    style: const TextStyle(
                        fontSize: 48, // text-3xl
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 16), // gap-6 adjusted vertically

              // Name and Username
              Text(
                user.name ?? 'Guest User', // Default name
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                user.username ?? '@unknown', // Default username
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Bio
              if (user.bio != null && user.bio!.isNotEmpty)
          Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // mb-4
      child: Text(
        user.bio!, // Use user.bio
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        textAlign: TextAlign.center,
      ),
    ),

    // Stats Row (Recipes, Liked, Following, Followers)
    Wrap(
    alignment: WrapAlignment.center, // justify-center
    spacing: 16.0, // horizontal gap-4
    runSpacing: 8.0, // vertical gap for wrap
    children: [
    _buildStatItem(Icons.restaurant_menu, Colors.orange, '$userRecipesCount', 'Recipes'), // ChefHat text-orange-500
    _buildStatItem(Icons.favorite, Colors.red, '$likedRecipesCount', 'Liked'), // Heart text-red-500
    GestureDetector( // Link to /following
    onTap: () {
    // TODO: Implement navigation to Following page
    print('Navigate to Following');
    },
    child: _buildStatItem(Icons.people, Colors.blue, '$followingCount', 'Following'), // Users text-blue-500
    ),
    GestureDetector( // Link to /followers
    onTap: () {
    // TODO: Implement navigation to Followers page
    print('Navigate to Followers');
    },
    child: _buildStatItem(Icons.people, Colors.green, '$followersCount', 'Followers'), // Users text-green-500
    ),
    ],
    ),
     SizedBox(height: 24),

    // Action Buttons
    Wrap(
    spacing: 12.0, // gap-3
    runSpacing: 12.0,
    alignment: WrapAlignment.center, // justify-center
    children: [
    ElevatedButton.icon(
    onPressed: () {
    // TODO: Handle View Community action
    print('View Community button pressed');
    },
    style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).primaryColor, // Use app's primary color
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: const Icon(Icons.people_alt, size: 20, color: Colors.white), // Users w-4 h-4
    label: const Text('View Community', style: TextStyle(color: Colors.white)),
    ),
    OutlinedButton.icon(
    onPressed: () {
    // TODO: Handle Settings action
    print('Settings button pressed');
    
    },
    style: OutlinedButton.styleFrom(
    side: BorderSide(color: Colors.grey[400]!), // variant="outline"
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: const Icon(Icons.settings, size: 20, color: Colors.black87), // Settings w-4 h-4
    label: const Text('Settings', style: TextStyle(color: Colors.black87)),
    ),
    ],
    ),
    ],
    ),
    ),
    ),
    ),
    // Add some space after the profile card if needed before other sections start
    const SizedBox(height: 16),
    ],
    ),
    ),
    // Sections for "My Recipes" and "Liked Recipes" can go here later,
    // using the RecipeCard component and fetching relevant data.
    ],
    ),
    );
  }
}
