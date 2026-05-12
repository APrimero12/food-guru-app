// lib/views/home_navigation.dart
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/auth.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/views/cart/cart_page.dart';
import 'package:appdevproject/views/friends/friends_page.dart';
import 'package:appdevproject/views/profile/myprofile_page.dart';
import 'package:appdevproject/views/profile/settings_page.dart';
import 'package:appdevproject/views/recipe/add_recipe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appdevproject/services/message_service.dart';

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
  final MessageService _messageService = MessageService();

  // ── navigation helpers ───────────────────────────────────────────────────

  void _openSettings() =>
      setState(() => _currentAppView = AppView.settingsPage);

  /// Switches the bottom-nav to the Friends tab (index 1).
  void _openCommunity() {
    setState(() {
      _currentAppView = AppView.homeTabs;
      _bottomNavIndex = 1;
    });
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    String titleText;
    List<Widget> appBarActions = [];
    Widget? leadingWidget;

    switch (_currentAppView) {
      case AppView.dmsPage:
        titleText = 'Direct Messages';
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () =>
              setState(() => _currentAppView = AppView.homeTabs),
        );
        break;

      case AppView.settingsPage:
        titleText = 'Settings';
        leadingWidget = IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () =>
              setState(() => _currentAppView = AppView.homeTabs),
        );
        break;

      case AppView.homeTabs:
        titleText = 'FoodGuru';
        appBarActions = [
          StreamBuilder<QuerySnapshot>(
            stream: Provider.of<UserProvider>(context, listen: false).currentUser == null
                ? const Stream.empty()
                : MessageService().conversationsStream(
                Provider.of<UserProvider>(context, listen: false).currentUser!.uid),
            builder: (context, snap) {
              final currentUid =
                  Provider.of<UserProvider>(context, listen: false).currentUser?.uid ?? '';

              int totalUnread = 0;
              for (final doc in snap.data?.docs ?? []) {
                final data = doc.data() as Map<String, dynamic>;
                totalUnread += (data['unread_$currentUid'] as num?)?.toInt() ?? 0;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.black),
                    onPressed: () =>
                        setState(() => _currentAppView = AppView.dmsPage),
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          totalUnread > 99 ? '99+' : '$totalUnread',
                          style:
                          const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ];
        break;
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
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: appBarActions,
    );
  }

  // ── body ────────────────────────────────────────────────────────────────

  Widget _buildBodyContent(UserModel? user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userService = UserService();

    switch (_currentAppView) {
      case AppView.dmsPage:
        return const DmsPage();

      case AppView.settingsPage:
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SettingsPage(
          currentUser: user,
          authService: authService,
          userService: userService,
        );

      case AppView.homeTabs:
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final List<Widget> pages = [
          const ExploreContent(),
          const FriendsPage(),
          const AddRecipe(),
          const CartPage(),
          if (user == null)
            Center(
              child: userProvider.isLoading
                  ? const CircularProgressIndicator(color: Colors.orange)
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Could not load profile.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final uid = Provider.of<AuthService>(
                          context, listen: false)
                          .currentUser
                          ?.uid;
                      if (uid != null) userProvider.loadUser(uid);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            ProfilePage(
              user: user,
              onSettingsTapped: _openSettings,
              onCommunityTapped: _openCommunity,
            ),
        ];
        final safeIndex = _bottomNavIndex.clamp(0, pages.length - 1);
        return pages[safeIndex];
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Scaffold(
          appBar: _buildAppBar(context),
          body: _buildBodyContent(userProvider.currentUser),
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
                  icon: Icon(Icons.search), label: 'Explore'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline), label: 'Friends'),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.add, color: Colors.white, size: 20),
                ),
                label: 'Add',
              ),
              BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}