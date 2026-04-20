import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/auth.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/views/cart/cart_page.dart';
import 'package:appdevproject/views/friends/friends_page.dart';
import 'package:appdevproject/views/profile/myprofile_page.dart';
import 'package:appdevproject/views/profile/settings_page.dart';
import 'package:appdevproject/views/recipe/add_recipe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'explore/explore_content.dart';
import 'messages/dms_page.dart';

enum AppView {
  homeTabs,
  dmsPage,
  settingsPage,
}

class MyExplorePage extends StatefulWidget {
  const MyExplorePage({super.key});

  @override
  State<MyExplorePage> createState() => _MyExplorePageState();
}

class _MyExplorePageState extends State<MyExplorePage> {
  int _bottomNavIndex = 0;
  AppView _currentAppView = AppView.homeTabs;

  // A real app would load this from Firestore via a stream/provider.
  // For now we use a placeholder that mirrors what initState previously had.
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = UserModel(
      uid: 'temp_user_id',
      name: 'User Name',
      username: '@username',
      bio: '',
      avatar: '',
    );
  }

  // Called by ProfilePage when the user taps "Settings"
  void _openSettings() {
    setState(() {
      _currentAppView = AppView.settingsPage;
    });
  }

  AppBar _buildAppBar(BuildContext context) {
    String titleText;
    List<Widget> appBarActions = [];
    Widget? leadingWidget;

    if (_currentAppView == AppView.dmsPage) {
      titleText = 'Direct Messages';
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => setState(() => _currentAppView = AppView.homeTabs),
      );
    } else if (_currentAppView == AppView.settingsPage) {
      titleText = 'Settings';
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => setState(() => _currentAppView = AppView.homeTabs),
      );
    } else {
      titleText = 'FoodGuru';
      appBarActions = [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () =>
                  setState(() => _currentAppView = AppView.dmsPage),
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
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: const Text(
                  '2',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ];
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: leadingWidget,
      title: Row(
        children: [
          if (_currentAppView == AppView.homeTabs)
            const Icon(Icons.restaurant_menu, color: Colors.orange),
          if (_currentAppView == AppView.homeTabs) const SizedBox(width: 8),
          Text(
            titleText,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: appBarActions,
    );
  }

  Widget _buildBodyContent() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userService = UserService();

    switch (_currentAppView) {
      case AppView.dmsPage:
        return const DmsPage();

      case AppView.settingsPage:
        return SettingsPage(
          currentUser: _currentUser,
          authService: authService,
          userService: userService,
        );

      case AppView.homeTabs:
      // Build the tab pages inline so ProfilePage can receive the callback.
        final List<Widget> pages = [
          ExploreContent(),
          FriendsPage(),
          AddRecipe(),
          CartPage(),
          ProfilePage(
            user: _currentUser,
            onSettingsTapped: _openSettings,
          ),
        ];
        return pages[_bottomNavIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
            _currentAppView = AppView.homeTabs;
          });
        },
        type: BottomNavigationBarType.fixed,
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