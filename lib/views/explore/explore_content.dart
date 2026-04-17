import 'package:flutter/material.dart';

import '../widgets.dart';

class ExploreContent extends StatelessWidget {
  const ExploreContent({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);

    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

    return SingleChildScrollView(
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
              children: [
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}