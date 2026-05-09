import 'package:flutter/material.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/recipe_services.dart';
import '../widgets.dart';

class ProfilePage extends StatefulWidget {
  final UserModel user;
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

  List<Map<String, dynamic>> _myRecipes    = [];
  List<Map<String, dynamic>> _likedRecipes = [];
  final Set<String> _likedIds = {};

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
    // Reload if the logged-in user switches.
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
      ]);
      if (mounted) {
        setState(() {
          _myRecipes    = results[0];
          _likedRecipes = results[1];
          _likedIds
            ..clear()
            ..addAll(_likedRecipes.map((r) => r['id'] as String));
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── like toggle ───────────────────────────────────────────────────────────

  Future<void> _toggleLike(String recipeId) async {
    setState(() {
      if (_likedIds.contains(recipeId)) {
        _likedIds.remove(recipeId);
        _likedRecipes.removeWhere((r) => r['id'] == recipeId);
        _updateLikeCount(_myRecipes, recipeId, -1);
      } else {
        _likedIds.add(recipeId);
        _updateLikeCount(_myRecipes, recipeId, 1);
      }
    });

    try {
      await _recipeService.toggleLike(recipeId, widget.user.uid);
    } catch (_) {
      // Revert on failure.
      if (mounted) {
        setState(() {
          if (_likedIds.contains(recipeId)) {
            _likedIds.remove(recipeId);
            _likedRecipes.removeWhere((r) => r['id'] == recipeId);
            _updateLikeCount(_myRecipes, recipeId, -1);
          } else {
            _likedIds.add(recipeId);
            _updateLikeCount(_myRecipes, recipeId, 1);
          }
        });
      }
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
            emptyIcon: Icons.restaurant_menu,
            emptyTitle: 'No recipes yet',
            emptySubtitle: 'Your published recipes will appear here.',
          ),
          _buildGrid(
            _likedRecipes,
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
        // Gradient banner
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

        // Profile card
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
                    // Avatar
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

                    // Name
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
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),

                    // Bio
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

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem(
                            Icons.restaurant_menu,
                            Colors.orange,
                            '${_myRecipes.length}',
                            'Recipes'),
                        _divider(),
                        _statItem(
                            Icons.favorite, Colors.red,
                            '${_likedRecipes.length}', 'Liked'),
                        _divider(),
                        GestureDetector(
                          onTap: widget.onCommunityTapped,
                          child: _statItem(
                              Icons.people, Colors.blue, '0', 'Following'),
                        ),
                        _divider(),
                        GestureDetector(
                          onTap: widget.onCommunityTapped,
                          child: _statItem(
                              Icons.people, Colors.green, '0', 'Followers'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
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
            isLiked: _likedIds.contains(recipeId),
            onLikeTapped: () => _toggleLike(recipeId),
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
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}