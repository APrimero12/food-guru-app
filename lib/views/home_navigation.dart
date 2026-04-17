import 'package:appdevproject/views/cart/cart_page.dart';
import 'package:appdevproject/views/friends/friends_page.dart';
import 'package:appdevproject/views/profile/myprofile_page.dart';
import 'package:appdevproject/views/recipe/add_recipe.dart';
import 'package:flutter/material.dart';

import 'explore/explore_content.dart';

class ExploreContentPage extends StatelessWidget {
  const ExploreContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Explore Content Page'));
  }
}

class MyExplorePage extends StatefulWidget {
  const MyExplorePage({super.key});

  @override
  State<MyExplorePage> createState() => _MyExplorePageState();
}

class _MyExplorePageState extends State<MyExplorePage> {
  int _selectedIndex = 0;

  // IMPORTANT: Ensure this list matches the order and number of your BottomNavigationBarItems
  final List<Widget> _pages = const [
    ExploreContent(),
    FriendsPage(),
    AddRecipe(),
    CartPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.restaurant_menu, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'FoodGuru',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black),
                onPressed: () {
                  // TODO: Handle notification icon press
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
        ],
      ),
      body: _pages[_selectedIndex], // Display the widget corresponding to the selected index

      // FOOTER NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // Update the selected index on tap
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
