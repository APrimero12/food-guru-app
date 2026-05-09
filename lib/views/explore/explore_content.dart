import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/recipe_services.dart';

import '../widgets.dart';

const int _pageSize = 10;

class ExploreContent extends StatefulWidget {
  const ExploreContent({super.key});

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  final RecipeService    _recipeService    = RecipeService();
  final ScrollController _scrollController = ScrollController();

  // ── recipe list state ─────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _recipes = [];
  DocumentSnapshot? _lastDoc;
  bool _isInitialLoading = true;
  bool _isLoadingMore    = false;
  bool _hasMore          = true;
  bool _hasError         = false;

  // ── like state ────────────────────────────────────────────────────────────
  final Set<String> _likedIds = {};
  bool _likesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLikedIds();
    _fetchFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── scroll listener ───────────────────────────────────────────────────────

  void _onScroll() {
    // Start loading the next page when the user is within 300px of the bottom.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  // ── data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchFirstPage() async {
    setState(() {
      _isInitialLoading = true;
      _hasError         = false;
      _recipes.clear();
      _lastDoc  = null;
      _hasMore  = true;
    });

    try {
      final result =
      await _recipeService.getRecipesPage(limit: _pageSize);

      if (mounted) {
        setState(() {
          _recipes.addAll(result.recipes);
          _lastDoc          = result.lastDoc;
          _hasMore          = result.recipes.length == _pageSize;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError         = true;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await _recipeService.getRecipesPage(
        limit:        _pageSize,
        lastDocument: _lastDoc,
      );

      if (mounted) {
        setState(() {
          _recipes.addAll(result.recipes);
          _lastDoc       = result.lastDoc ?? _lastDoc;
          _hasMore       = result.recipes.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── likes ─────────────────────────────────────────────────────────────────

  Future<void> _loadLikedIds() async {
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) {
      setState(() => _likesLoaded = true);
      return;
    }
    try {
      final liked = await _recipeService.getLikedRecipes(user.uid);
      if (mounted) {
        setState(() {
          _likedIds
            ..clear()
            ..addAll(liked.map((r) => r['id'] as String));
          _likesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _likesLoaded = true);
    }
  }

  Future<void> _toggleLike(String recipeId) async {
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;

    // Flip locally first for instant feedback.
    setState(() {
      if (_likedIds.contains(recipeId)) {
        _likedIds.remove(recipeId);
        // Decrement local like count
        final idx = _recipes.indexWhere((r) => r['id'] == recipeId);
        if (idx != -1) {
          _recipes[idx] = {
            ..._recipes[idx],
            'likes': ((_recipes[idx]['likes'] as num?) ?? 1).toInt() - 1,
          };
        }
      } else {
        _likedIds.add(recipeId);
        final idx = _recipes.indexWhere((r) => r['id'] == recipeId);
        if (idx != -1) {
          _recipes[idx] = {
            ..._recipes[idx],
            'likes': ((_recipes[idx]['likes'] as num?) ?? 0).toInt() + 1,
          };
        }
      }
    });

    try {
      await _recipeService.toggleLike(recipeId, user.uid);
    } catch (_) {
      // Revert on failure.
      if (mounted) {
        setState(() {
          if (_likedIds.contains(recipeId)) {
            _likedIds.remove(recipeId);
            final idx =
            _recipes.indexWhere((r) => r['id'] == recipeId);
            if (idx != -1) {
              _recipes[idx] = {
                ..._recipes[idx],
                'likes':
                ((_recipes[idx]['likes'] as num?) ?? 1).toInt() - 1,
              };
            }
          } else {
            _likedIds.add(recipeId);
            final idx =
            _recipes.indexWhere((r) => r['id'] == recipeId);
            if (idx != -1) {
              _recipes[idx] = {
                ..._recipes[idx],
                'likes':
                ((_recipes[idx]['likes'] as num?) ?? 0).toInt() + 1,
              };
            }
          }
        });
      }
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
    // ── initial loading ───────────────────────────────────────────────────────
    if (_isInitialLoading || !_likesLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    // ── error ─────────────────────────────────────────────────────────────────
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Could not load recipes.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _fetchFirstPage,
                child: const Text('Retry',
                    style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        ),
      );
    }

    // ── empty state ───────────────────────────────────────────────────────────
    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: 72, color: Colors.grey[200]),
              const SizedBox(height: 20),
              const Text('No recipes yet!',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Be the first to share one.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    // ── recipe grid ───────────────────────────────────────────────────────────
    final screenWidth    = MediaQuery.of(context).size.width;
    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);
    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── header ────────────────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discover Amazing Recipes',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Share your favourite recipes and discover new ones from the community',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── grid ──────────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   crossAxisCount,
              childAspectRatio: cardRatio,
              mainAxisSpacing:  16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final data     = _recipes[index];
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
              childCount: _recipes.length,
            ),
          ),
        ),

        // ── load-more indicator / end-of-feed label ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(
                  color: Colors.orange, strokeWidth: 2)
                  : !_hasMore
                  ? Text("You've seen it all!",
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 13))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}