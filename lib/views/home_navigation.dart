import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/views/cart/cart_page.dart';
import 'package:appdevproject/views/friends/friends_page.dart';
import 'package:appdevproject/views/profile/myprofile_page.dart';
import 'package:appdevproject/views/recipe/add_recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'explore/explore_content.dart';
import 'messages/dms_page.dart'; // Your DmsPage import

// --- Enum to manage main views ---
// This helps us track whether we are in the main tab navigation or on the DMs page
enum AppView {
  homeTabs, // Represents the views controlled by the BottomNavigationBar
  dmsPage,  // Represents the Direct Messages page
}

class MyExplorePage extends StatefulWidget {
  const MyExplorePage({super.key});

  @override
  State<MyExplorePage> createState() => _MyExplorePageState();
}

class _MyExplorePageState extends State<MyExplorePage> {
  int _bottomNavIndex = 0; // Tracks the selected item in the BottomNavigationBar
  AppView _currentAppView = AppView.homeTabs; // Tracks the currently displayed main view

  late final List<Widget> _bottomNavPages;

  @override
  void initState() {
    super.initState();
    final UserModel currentUserForProfile = UserModel(
      uid: 'temp_user_id',
      name: 'User Name',
      username: '@username',
      bio: '',
      avatar: '',
    );

    //This list has pages accessible by the BottomNavigationBar
    _bottomNavPages = [
      ExploreContent(),
      FriendsPage(),
      AddRecipe(),
      CartPage(),
      ProfilePage(user: currentUserForProfile),
    ];
  }

  // --- Dynamically build the AppBar ---
  // This method creates the AppBar content based on the current view (homeTabs or DmsPage)
  AppBar _buildAppBar(BuildContext context) {
    String titleText;
    List<Widget> appBarActions = [];
    Widget? leadingWidget; // For back button on the DMs page

    if (_currentAppView == AppView.dmsPage) {
      titleText = 'Direct Messages'; // Title for the DMs page
      // Add a back button to return to the home tabs
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          setState(() {
            _currentAppView = AppView.homeTabs; // Go back to the main tabs view
          });
        },
      );
      // You can add specific actions for the DMs page here if needed
      // appBarActions = [ /* DMs specific actions */ ];
    } else { // _currentAppView == AppView.homeTabs
      titleText = 'FoodGuru'; // Default title for main tabs
      // Actions for the main tabs (like the notification icon)
      appBarActions = [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {
                // When notification icon is pressed, switch to the DMs page view
                setState(() {
                  _currentAppView = AppView.dmsPage;
                });
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: const Text(
                  '2', // You would typically make this dynamic
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ];
      // No leading widget for the home tabs by default
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: leadingWidget, // Dynamically set the leading widget (back button)
      title: Row(
        children: [
          // Only show the restaurant icon and extra space for home tabs view
          if (_currentAppView == AppView.homeTabs)
            const Icon(Icons.restaurant_menu, color: Colors.orange),
          if (_currentAppView == AppView.homeTabs)
            const SizedBox(width: 8),
          Text(
            titleText, // Dynamically set the title
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: appBarActions, // Dynamically set the actions
    );
  }

  // --- Dynamically build the body content ---
  // This method determines which widget to show in the main body area
  Widget _buildBodyContent() {
    switch (_currentAppView) {
      case AppView.homeTabs:
        return _bottomNavPages[_bottomNavIndex]; // Show content from selected bottom nav tab
      case AppView.dmsPage:
        return const DmsPage(); // Show the DmsPage content
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context), // Use the dynamically built AppBar
      body: _buildBodyContent(),     // Use the dynamically built body content

      // FOOTER NAVIGATION (always visible)
      // The BottomNavigationBar remains unchanged and visible regardless of _currentAppView
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index; // Update the selected index on tap
            // When a bottom nav item is tapped, always switch to the homeTabs view
            _currentAppView = AppView.homeTabs;
          });
        },
        type: BottomNavigationBarType.fixed, // Use fixed if you have more than 3 items
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.orange,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
