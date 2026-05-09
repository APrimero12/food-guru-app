import 'package:flutter/material.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/services/recipe_services.dart';
import 'package:appdevproject/services/user_services.dart';
import 'package:appdevproject/views/recipe/recipe_detail_page.dart';

class UserProfilePage extends StatefulWidget {
  final String  userId;
  final String? displayName; // shown in the app bar while real data loads

  const UserProfilePage({
    super.key,
    required this.userId,
    this.displayName,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService   _userService   = UserService();
  final RecipeService _recipeService = RecipeService();

  UserModel?                 _user;
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userService.getUser(widget.userId),
        _recipeService.getRecipesByUser(widget.userId),
      ]);
      if (mounted) {
        setState(() {
          _user      = results[0] as UserModel?;
          _recipes   = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          title: Text(
            widget.displayName ?? 'Profile',
            style: const TextStyle(color: Colors.black),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    final screenWidth    = MediaQuery.of(context).size.width;
    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);
    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── gradient app bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Colors.orange,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange, Colors.red],
                  ),
                ),
              ),
            ),
          ),

          // ── profile card ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      // Avatar
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (_user?.avatar != null &&
                            _user!.avatar!.isNotEmpty)
                            ? NetworkImage(_user!.avatar!)
                            : null,
                        child: (_user?.avatar == null ||
                            _user!.avatar!.isEmpty)
                            ? Text(
                          (_user?.name ?? widget.displayName ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54),
                        )
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Text(
                        _user?.name ?? widget.displayName ?? 'User',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (_user?.username != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${_user!.username}',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      // Bio
                      if (_user?.bio != null &&
                          _user!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _user!.bio!,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Recipe count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant_menu,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            '${_recipes.length} ${_recipes.length == 1 ? 'Recipe' : 'Recipes'}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── section label ──────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                Icon(Icons.restaurant_menu, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('Recipes',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),

          // ── empty state ────────────────────────────────────────────────────
          if (_recipes.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 64, color: Colors.grey[200]),
                    const SizedBox(height: 16),
                    const Text('No recipes yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('This user hasn\'t shared any recipes.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
          // ── recipe grid ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   crossAxisCount,
                  childAspectRatio: cardRatio,
                  mainAxisSpacing:  16,
                  crossAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final data = _recipes[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailPage(data: data),
                        ),
                      ),
                      child: Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                width: double.infinity,
                                child: (data['image'] as String? ?? '')
                                    .isNotEmpty
                                    ? Image.network(
                                  data['image'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                )
                                    : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.restaurant,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                            // Info
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['recipeName'] as String? ??
                                          'Untitled',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Icon(Icons.access_time,
                                          size: 12,
                                          color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(
                                          (data['prepTime'] as num?)
                                              ?.toInt() ??
                                              0,
                                          (data['cookTime'] as num?)
                                              ?.toInt() ??
                                              0,
                                        ),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(Icons.favorite,
                                          size: 12,
                                          color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(data['likes'] as num?)?.toInt() ?? 0}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _recipes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}