// lib/views/profile/myprofile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/follow_service.dart';
import 'package:appdevproject/services/recipe_services.dart';
import 'package:appdevproject/views/recipe/recipe_detail_page.dart';
import '../widgets.dart';

class ProfilePage extends StatefulWidget {
  final UserModel    user;
  final VoidCallback? onSettingsTapped;
  final VoidCallback? onCommunityTapped;

  const ProfilePage({
    super.key,
    required this.user,
    this.onSettingsTapped,
    this.onCommunityTapped,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final RecipeService _recipeService = RecipeService();
  final FollowService _followService = FollowService();

  int _followingCount = 0;
  int _followersCount = 0;

  List<Map<String, dynamic>> _myRecipes    = [];
  List<Map<String, dynamic>> _likedRecipes = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _recipeService.getRecipesByUser(widget.user.uid),
        _recipeService.getLikedRecipes(widget.user.uid),
        _followService.getFollowingCount(widget.user.uid),
        _followService.getFollowersCount(widget.user.uid),
      ]);
      if (mounted) {
        setState(() {
          _myRecipes      = results[0] as List<Map<String, dynamic>>;
          _likedRecipes   = results[1] as List<Map<String, dynamic>>;
          _followingCount = results[2] as int;
          _followersCount = results[3] as int;
          _isLoading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── like toggle ───────────────────────────────────────────────────────────
  // UserProvider is the single source of truth for the filled/unfilled heart.
  // We only keep the local lists to know which recipes to show in each tab,
  // and update the displayed like count optimistically.

  Future<void> _toggleLike(String recipeId) async {
    final userProvider =
    Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null) return;

    final wasLiked = userProvider.isLiked(recipeId);

    // Update displayed count immediately.
    _updateLikeCount(_myRecipes, recipeId, wasLiked ? -1 : 1);
    if (!wasLiked) {
      // Recipe will now be liked — add to liked tab if not already there.
      final alreadyInList =
      _likedRecipes.any((r) => r['id'] == recipeId);
      if (!alreadyInList) {
        final recipe =
        _myRecipes.firstWhere((r) => r['id'] == recipeId,
            orElse: () => {});
        if (recipe.isNotEmpty) _likedRecipes.insert(0, recipe);
      }
    } else {
      // Recipe will be unliked — remove from liked tab.
      _likedRecipes.removeWhere((r) => r['id'] == recipeId);
    }
    setState(() {});

    // Provider handles Firestore and reverts on error.
    await userProvider.toggleLike(recipeId);

    // If provider reverted, undo our count change too.
    if (mounted && userProvider.isLiked(recipeId) == wasLiked) {
      _updateLikeCount(_myRecipes, recipeId, wasLiked ? 1 : -1);
      setState(() {});
    }
  }

  void _updateLikeCount(
      List<Map<String, dynamic>> list, String recipeId, int delta) {
    final idx = list.indexWhere((r) => r['id'] == recipeId);
    if (idx == -1) return;
    list[idx] = {
      ...list[idx],
      'likes': ((list[idx]['likes'] as num?) ?? 0).toInt() + delta,
    };
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _formatTime(int prep, int cook) {
    final total = prep + cook;
    if (total == 0) return '—';
    if (total < 60) return '${total}m';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  List<String> _buildTags(Map<String, dynamic> data) {
    final tags        = <String>[];
    final restriction = data['dietaryRestrictions'] as String?;
    final category    = data['category'] as String?;
    if (restriction != null && restriction.isNotEmpty) {
      tags.add(restriction.toLowerCase());
    }
    if (category != null && category.isNotEmpty && tags.length < 3) {
      tags.add(category.toLowerCase());
    }
    return tags;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch provider so hearts re-render when toggled from other pages.
    final userProvider = context.watch<UserProvider>();

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.restaurant_menu, size: 18),
                  text: 'My Recipes (${_myRecipes.length})',
                ),
                Tab(
                  icon: const Icon(Icons.favorite, size: 18),
                  text: 'Liked (${_likedRecipes.length})',
                ),
              ],
            ),
          ),
        ),
      ],
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildGrid(
            _myRecipes,
            userProvider: userProvider,
            emptyIcon: Icons.restaurant_menu,
            emptyTitle: 'No recipes yet',
            emptySubtitle: 'Your published recipes will appear here.',
          ),
          _buildGrid(
            _likedRecipes,
            userProvider: userProvider,
            emptyIcon: Icons.favorite_border,
            emptyTitle: 'No liked recipes',
            emptySubtitle: 'Recipes you like will appear here.',
          ),
        ],
      ),
    );
  }

  // ── profile header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final user = widget.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange, Colors.red],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Transform.translate(
            offset: const Offset(0, -48),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: user.avatar != null &&
                            user.avatar!.isNotEmpty
                            ? NetworkImage(user.avatar!)
                            : null,
                        child: (user.avatar == null || user.avatar!.isEmpty)
                            ? Text(
                          user.name?.isNotEmpty == true
                              ? user.name![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      user.name ?? 'Guest User',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      user.username != null
                          ? '@${user.username}'
                          : '@unknown',
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),

                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem(Icons.restaurant_menu, Colors.orange,
                            '${_myRecipes.length}', 'Recipes'),
                        _divider(),
                        _statItem(Icons.favorite, Colors.red,
                            '${_likedRecipes.length}', 'Liked'),
                        _divider(),
                        GestureDetector(
                          onTap: widget.onCommunityTapped,
                          child: _statItem(Icons.people, Colors.blue,
                              '$_followingCount', 'Following'),
                        ),
                        _divider(),
                        GestureDetector(
                          onTap: widget.onCommunityTapped,
                          child: _statItem(Icons.people, Colors.green,
                              '$_followersCount', 'Followers'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: widget.onCommunityTapped,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.people_alt,
                              size: 18, color: Colors.white),
                          label: const Text('Community',
                              style: TextStyle(color: Colors.white)),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onSettingsTapped,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.settings,
                              size: 18, color: Colors.black87),
                          label: const Text('Settings',
                              style: TextStyle(color: Colors.black87)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(
      IconData icon, Color color, String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(count,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _divider() => Container(
    height: 32,
    width: 1,
    color: Colors.grey[200],
  );

  // ── recipe grid ───────────────────────────────────────────────────────────

  Widget _buildGrid(
      List<Map<String, dynamic>> recipes, {
        required UserProvider userProvider,
        required IconData emptyIcon,
        required String emptyTitle,
        required String emptySubtitle,
      }) {
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 64, color: Colors.grey[200]),
              const SizedBox(height: 16),
              Text(emptyTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(emptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    final screenWidth    = MediaQuery.of(context).size.width;
    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);
    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   crossAxisCount,
          childAspectRatio: cardRatio,
          mainAxisSpacing:  16,
          crossAxisSpacing: 16,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final data     = recipes[index];
          final recipeId = data['id'] as String;

          return RecipeCard(
            imageUrl:    data['image']       as String? ?? '',
            userName:    data['userName']    as String? ?? 'Anonymous',
            userAvatar:  data['userAvatar']  as String? ?? '',
            title:       data['recipeName']  as String? ?? 'Untitled',
            description: data['description'] as String? ?? '',
            time: _formatTime(
              (data['prepTime'] as num?)?.toInt() ?? 0,
              (data['cookTime'] as num?)?.toInt() ?? 0,
            ),
            servings: '${(data['servings'] as num?)?.toInt() ?? 0}',
            tags:    _buildTags(data),
            likes:   '${(data['likes'] as num?)?.toInt() ?? 0}',
            // ← Driven by UserProvider
            isLiked: userProvider.isLiked(recipeId),
            onLikeTapped: () => _toggleLike(recipeId),
            onTapped: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecipeDetailPage(data: data),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── sticky tab bar delegate ────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}