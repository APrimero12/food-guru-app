// lib/views/explore/explore_content.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/recipe_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/recipe_services.dart';
import 'package:appdevproject/views/recipe/recipe_detail_page.dart';

import '../widgets.dart';

const int _pageSize = 10;

class ExploreContent extends StatefulWidget {
  const ExploreContent({super.key});

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  final RecipeService       _recipeService    = RecipeService();
  final ScrollController    _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // ── paginated "all recipes" state ─────────────────────────────────────────
  final List<Map<String, dynamic>> _recipes = [];
  DocumentSnapshot? _lastDoc;
  bool _isInitialLoading = true;
  bool _isLoadingMore    = false;
  bool _hasMore          = true;
  bool _hasError         = false;

  // ── filter / search state ─────────────────────────────────────────────────
  String    _searchQuery      = '';
  Category? _selectedCategory;
  List<Map<String, dynamic>> _filteredRecipes = [];
  bool _isFiltering     = false;
  bool _isFilterLoading = false;

  bool get _activeFilter =>
      _searchQuery.isNotEmpty || _selectedCategory != null;

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── scroll ────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_activeFilter &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  // ── search ────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() => _searchQuery = q);
    _applyFilter();
  }

  void _selectCategory(Category? cat) {
    setState(() => _selectedCategory = cat);
    _applyFilter();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery      = '';
      _selectedCategory = null;
      _filteredRecipes  = [];
      _isFiltering      = false;
    });
  }

  Future<void> _applyFilter() async {
    if (!_activeFilter) {
      setState(() {
        _filteredRecipes = [];
        _isFiltering     = false;
      });
      return;
    }

    setState(() {
      _isFiltering     = true;
      _isFilterLoading = true;
    });

    try {
      List<Map<String, dynamic>> results;

      if (_selectedCategory != null) {
        results = await _recipeService
            .getRecipesByCategory(_selectedCategory!);
      } else {
        results = await _recipeService.getAllRecipes(limit: 100);
      }

      if (_searchQuery.isNotEmpty) {
        results = results.where((r) {
          final name = (r['recipeName'] as String? ?? '').toLowerCase();
          final desc = (r['description'] as String? ?? '').toLowerCase();
          return name.contains(_searchQuery) || desc.contains(_searchQuery);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _filteredRecipes  = results;
          _isFilterLoading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFilterLoading = false);
    }
  }

  // ── pagination ────────────────────────────────────────────────────────────

  Future<void> _fetchFirstPage() async {
    setState(() {
      _isInitialLoading = true;
      _hasError         = false;
      _recipes.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final result = await _recipeService.getRecipesPage(limit: _pageSize);
      if (mounted) {
        setState(() {
          _recipes.addAll(result.recipes);
          _lastDoc          = result.lastDoc;
          _hasMore          = result.recipes.length == _pageSize;
          _isInitialLoading = false;
        });
      }
    } catch (_) {
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

  // ── like toggle ───────────────────────────────────────────────────────────
  // Like state now lives in UserProvider — just update the local count for
  // immediate feedback on the card, then let the provider handle Firestore.

  Future<void> _toggleLike(String recipeId) async {
    final userProvider =
    Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null) return;

    final wasLiked = userProvider.isLiked(recipeId);

    // Update the displayed like count on the card immediately.
    _updateCount(_recipes, recipeId, wasLiked ? -1 : 1);
    _updateCount(_filteredRecipes, recipeId, wasLiked ? -1 : 1);
    setState(() {});

    // Provider handles Firestore + reverts on error.
    await userProvider.toggleLike(recipeId);

    // If the provider reverted (error), revert the count too.
    if (mounted && userProvider.isLiked(recipeId) == wasLiked) {
      _updateCount(_recipes, recipeId, wasLiked ? 1 : -1);
      _updateCount(_filteredRecipes, recipeId, wasLiked ? 1 : -1);
      setState(() {});
    }
  }

  void _updateCount(
      List<Map<String, dynamic>> list, String id, int delta) {
    final idx = list.indexWhere((r) => r['id'] == id);
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
    if (_isInitialLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    if (_hasError) {
      return Center(
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
      );
    }

    final displayList    = _activeFilter ? _filteredRecipes : _recipes;
    final screenWidth    = MediaQuery.of(context).size.width;
    final crossAxisCount =
    screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1);
    final cardRatio =
    screenWidth > 1100 ? 0.68 : (screenWidth > 700 ? 0.72 : 0.90);

    // Watch UserProvider so cards re-render when like state changes.
    final userProvider = context.watch<UserProvider>();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── header ───────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discover Amazing Recipes',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Share your favourite recipes and discover new ones',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search recipes…',
                    hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon:
                    const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.grey, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // category chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _categoryChip(null, 'All'),
                      ...Category.values.map(
                              (c) => _categoryChip(c, c.name)),
                    ],
                  ),
                ),

                if (_activeFilter) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.filter_list,
                        size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      _isFilterLoading
                          ? 'Searching…'
                          : '${_filteredRecipes.length} result${_filteredRecipes.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange[700]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (_isFilterLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                  child:
                  CircularProgressIndicator(color: Colors.orange)),
            ),
          )
        else if (_activeFilter && _filteredRecipes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No recipes found',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Try a different search or category.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          )
        else if (displayList.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(64),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 72, color: Colors.grey[200]),
                    const SizedBox(height: 20),
                    const Text('No recipes yet!',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Be the first to share one.',
                        style:
                        TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else ...[
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
                      final data     = displayList[index];
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
                        servings:
                        '${(data['servings'] as num?)?.toInt() ?? 0}',
                        tags:    _buildTags(data),
                        likes:   '${(data['likes'] as num?)?.toInt() ?? 0}',
                        // ← Now driven by UserProvider, consistent across all pages
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
                    childCount: displayList.length,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(
                        color: Colors.orange, strokeWidth: 2)
                        : (!_hasMore && !_activeFilter)
                        ? Text("You've seen it all!",
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 13))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
      ],
    );
  }

  Widget _categoryChip(Category? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _selectCategory(isSelected ? null : category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
              isSelected ? Colors.orange : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}