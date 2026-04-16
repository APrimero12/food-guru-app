import 'package:flutter/material.dart';
import '../widgets.dart';

class MyExplorePage extends StatefulWidget {
  const MyExplorePage({super.key});

  @override
  State<MyExplorePage> createState() => _MyExplorePageState();
}

class _MyExplorePageState extends State<MyExplorePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);

    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

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
                onPressed: () {},
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
                    '2',
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discover Amazing Recipes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share your favorite recipes and discover new ones from the community',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: cardRatio,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: const [
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1473093226795-af9932fe5856?auto=format&fit=crop&w=800&q=80',
                    userName: 'Uncle Roger',
                    userAvatar: '',
                    title: 'Classic Pasta Carbonara',
                    description:
                    'An authentic Italian pasta dish with crispy pancetta, eggs, and Parmesan cheese. Simple yet incredibly delicious!',
                    time: '30m',
                    servings: '4',
                    tags: ['vegetarian'],
                    likes: '342',
                    isLiked: true,
                  ),
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
                    userName: 'Gordon Ramsay',
                    userAvatar: '',
                    title: 'Vibrant Buddha Bowl',
                    description:
                    'A nutritious and colorful plant-based bowl packed with quinoa, roasted vegetables, and tahini dressing.',
                    time: '50m',
                    servings: '2',
                    tags: ['vegan', 'gluten-free'],
                    likes: '521',
                    isLiked: true,
                  ),
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=800&q=80',
                    userName: 'Angelo Primero',
                    userAvatar: '',
                    title: 'Authentic Bun Bo Hue',
                    description:
                    'Traditional Vietnamese spicy beef noodle soup from Hue with aromatic lemongrass, tender beef, and rice vermicelli.',
                    time: '210m',
                    servings: '6',
                    tags: [],
                    likes: '789',
                    isLiked: false,
                  ),
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
                    userName: 'James Miller',
                    userAvatar: '',
                    title: 'Herb-Crusted Grilled Salmon',
                    description:
                    'Perfectly grilled salmon with a crispy herb crust. Healthy, elegant, and ready in 20 minutes!',
                    time: '25m',
                    servings: '4',
                    tags: ['gluten-free', 'pescatarian'],
                    likes: '455',
                    isLiked: true,
                  ),
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80',
                    userName: 'Uncle Roger',
                    userAvatar: '',
                    title: 'Fresh Greek Salad',
                    description:
                    'A refreshing Mediterranean salad with crisp vegetables, feta cheese, and tangy vinaigrette.',
                    time: '15m',
                    servings: '4',
                    tags: ['vegetarian', 'gluten-free'],
                    likes: '235',
                    isLiked: false,
                  ),
                  RecipeCard(
                    imageUrl:
                    'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=800&q=80',
                    userName: 'Angelo Primero',
                    userAvatar: '',
                    title: 'Fluffy Blueberry Pancakes',
                    description:
                    'Light and fluffy pancakes bursting with fresh blueberries. The perfect weekend breakfast!',
                    time: '25m',
                    servings: '4',
                    tags: ['vegetarian'],
                    likes: '654',
                    isLiked: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
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