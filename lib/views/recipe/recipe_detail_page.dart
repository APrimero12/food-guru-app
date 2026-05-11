// lib/views/recipe/recipe_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/recipe_services.dart';
import 'package:appdevproject/services/cart_service.dart';
import 'package:appdevproject/services/cloudinary_service.dart';
import 'package:appdevproject/views/profile/user_profile_page.dart';
import 'package:appdevproject/models/recipe_model.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const RecipeDetailPage({super.key, required this.data});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final RecipeService _recipeService = RecipeService();
  final CartService   _cartService   = CartService();

  // Only track the displayed like count locally for optimistic updates.
  // Like state (filled/unfilled heart) comes from UserProvider.
  late int _likeCount;

  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data      = Map<String, dynamic>.from(widget.data);
    _likeCount = (_data['likes'] as num?)?.toInt() ?? 0;
  }

  void _toggleLike() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null) return;

    final recipeId = _data['id'] as String;

    // toggleLike is now synchronous (debounced internally).
    // It returns the new liked state so we can update the count immediately.
    final nowLiked = userProvider.toggleLike(recipeId);
    setState(() {
      _likeCount = (_likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999);
    });
  }

  bool get _isOwner {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    return uid != null && uid == (_data['userId'] as String?);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recipe'),
        content: Text(
          'Are you sure you want to delete '
              '"${_data['recipeName'] ?? 'this recipe'}"? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) return;

    try {
      await _recipeService.deleteRecipe(_data['id'] as String, uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe deleted.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openEditSheet() async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRecipeSheet(data: _data),
    );

    if (updated == null || !mounted) return;

    try {
      await _recipeService.updateRecipe(_data['id'] as String, updated);
      setState(() => _data = {..._data, ...updated});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Add to Cart ───────────────────────────────────────────────────────────

  Future<void> _showAddToCartSheet() async {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to use the cart.')),
      );
      return;
    }

    final ingredients = _buildIngredientsForCart();
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This recipe has no ingredients listed.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddToCartSheet(
        uid:          uid,
        recipeId:     _data['id'] as String,
        recipeName:   _data['recipeName'] as String? ?? 'Untitled',
        ingredients:  ingredients,
        cartService:  _cartService,
      ),
    );
  }

  List<Map<String, dynamic>> _buildIngredientsForCart() {
    final raw = _data['ingredients'];
    if (raw == null) return [];

    if (raw is Map<String, dynamic>) {
      final name = (raw['name'] ?? '').toString().trim();
      if (name.isEmpty) return [];
      return [
        {
          'name':   name,
          'amount': raw['amount'] ?? 0,
          'unit':   (raw['unit'] ?? '').toString().trim(),
        }
      ];
    }

    if (raw is List) {
      final result = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            result.add({
              'name':   name,
              'amount': item['amount'] ?? 0,
              'unit':   (item['unit'] ?? '').toString().trim(),
            });
          }
        }
      }
      return result;
    }

    return [];
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

  void _goToAuthorProfile() {
    final userId   = _data['userId']   as String?;
    final userName = _data['userName'] as String?;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserProfilePage(userId: userId, displayName: userName),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch UserProvider so the heart icon re-renders on any like toggle.
    final userProvider = context.watch<UserProvider>();
    final recipeId     = _data['id'] as String;
    final isLiked      = userProvider.isLiked(recipeId);

    final imageUrl   = _data['image']       as String? ?? '';
    final title      = _data['recipeName']  as String? ?? 'Untitled';
    final desc       = _data['description'] as String? ?? '';
    final userName   = _data['userName']    as String? ?? 'Anonymous';
    final userAvatar = _data['userAvatar']  as String? ?? '';
    final prepTime   = (_data['prepTime']   as num?)?.toInt() ?? 0;
    final cookTime   = (_data['cookTime']   as num?)?.toInt() ?? 0;
    final servings   = (_data['servings']   as num?)?.toInt() ?? 0;
    final difficulty = _data['difficulty']  as String? ?? '';
    final category   = _data['category']   as String? ?? '';
    final dietary    = _data['dietaryRestrictions'] as String? ?? '';

    final ingredients  = _data['ingredients']  as Map<String, dynamic>?;
    final instructions = (_data['instructions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [];

    final isOwner = _isOwner;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── hero image app bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.35),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // Add to Cart button
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.35),
                  child: IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.white),
                    tooltip: 'Add to cart',
                    onPressed: _showAddToCartSheet,
                  ),
                ),
              ),
              // Like button — driven by UserProvider, no separate loading state needed
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.35),
                  child: IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: _toggleLike,
                  ),
                ),
              ),
              if (isOwner) ...[
                Padding(
                  padding:
                  const EdgeInsets.only(top: 8, bottom: 8, right: 4),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.35),
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white),
                      tooltip: 'Edit recipe',
                      onPressed: _openEditSheet,
                    ),
                  ),
                ),
                Padding(
                  padding:
                  const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.75),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white),
                      tooltip: 'Delete recipe',
                      onPressed: _confirmDelete,
                    ),
                  ),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                    CloudinaryService.detailHero(imageUrl),
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.restaurant,
                        size: 64, color: Colors.grey),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            'You created this recipe',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _openEditSheet,
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit',
                                style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _confirmDelete,
                            icon: const Icon(Icons.delete_outline, size: 14),
                            label: const Text('Delete',
                                style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Title + category chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Chip(
                          label: Text(category,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.orange.shade50,
                          side: BorderSide(color: Colors.orange.shade200),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Author row
                  GestureDetector(
                    onTap: _goToAuthorProfile,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: userAvatar.isNotEmpty
                              ? NetworkImage(userAvatar)
                              : null,
                          child: userAvatar.isEmpty
                              ? Icon(Icons.person,
                              size: 16, color: Colors.grey[500])
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.orange),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            size: 10, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCell(Icons.access_time_rounded,
                            _formatTime(prepTime, cookTime), 'Total Time'),
                        _vertDivider(),
                        _statCell(Icons.restaurant_outlined,
                            '$prepTime min', 'Prep'),
                        _vertDivider(),
                        _statCell(Icons.local_fire_department_outlined,
                            '$cookTime min', 'Cook'),
                        _vertDivider(),
                        _statCell(Icons.people_outline, '$servings',
                            'Servings'),
                        _vertDivider(),
                        _statCell(Icons.signal_cellular_alt, difficulty,
                            'Difficulty'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Likes + dietary tags + Add to Cart
                  Row(children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('$_likeCount likes',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                    if (dietary.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _tag(dietary.toLowerCase()),
                    ],
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddToCartSheet,
                      icon: const Icon(Icons.add_shopping_cart_rounded,
                          size: 16),
                      label: const Text('Add to Cart',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  if (desc.isNotEmpty) ...[
                    _sectionHeader(Icons.description_outlined, 'About'),
                    const SizedBox(height: 8),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.6)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],

                  _sectionHeader(Icons.list_alt_outlined, 'Ingredients'),
                  const SizedBox(height: 12),
                  if (ingredients != null)
                    _ingredientRow(
                      ingredients['name']?.toString() ?? '',
                      ingredients['amount']?.toString() ?? '',
                      ingredients['unit']?.toString() ?? '',
                    )
                  else
                    Text('No ingredients listed.',
                        style: TextStyle(color: Colors.grey[500])),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  _sectionHeader(
                      Icons.format_list_numbered_outlined, 'Instructions'),
                  const SizedBox(height: 12),
                  if (instructions.isEmpty)
                    Text('No instructions provided.',
                        style: TextStyle(color: Colors.grey[500]))
                  else
                    ...instructions.asMap().entries.map(
                          (e) => _stepRow(e.key + 1, e.value),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── sub-widgets ───────────────────────────────────────────────────────────

  Widget _statCell(IconData icon, String value, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: Colors.orange),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ],
  );

  Widget _vertDivider() =>
      Container(height: 36, width: 1, color: Colors.grey[200]);

  Widget _sectionHeader(IconData icon, String title) =>
      Row(children: [
        Icon(icon, size: 20, color: Colors.orange),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ]);

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700)),
  );

  Widget _ingredientRow(String name, String amount, String unit) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Colors.orange, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text('$amount $unit'.trim(),
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ]),
      );

  Widget _stepRow(int step, String instruction) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              color: Colors.orange, shape: BoxShape.circle),
          child: Center(
            child: Text('$step',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(instruction,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.55)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add to Cart Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddToCartSheet extends StatefulWidget {
  final String                     uid;
  final String                     recipeId;
  final String                     recipeName;
  final List<Map<String, dynamic>> ingredients;
  final CartService                cartService;

  const _AddToCartSheet({
    required this.uid,
    required this.recipeId,
    required this.recipeName,
    required this.ingredients,
    required this.cartService,
  });

  @override
  State<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<_AddToCartSheet> {
  List<Map<String, dynamic>> _lists = [];
  String? _selectedListId;
  bool _isLoading   = true;
  bool _isAdding    = false;

  final _newListCtrl = TextEditingController();
  bool _showNewInput = false;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _newListCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await widget.cartService.getLists(widget.uid);
      if (mounted) {
        setState(() {
          _lists          = lists;
          _selectedListId = lists.isNotEmpty ? lists.first['id'] as String : null;
          _isLoading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCart() async {
    if (_isAdding) return;

    String? targetId = _selectedListId;
    if (_showNewInput) {
      final name = _newListCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a list name.')),
        );
        return;
      }
      setState(() => _isAdding = true);
      try {
        targetId = await widget.cartService.createList(widget.uid, name);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isAdding = false);
        return;
      }
    }

    if (targetId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a list first.')));
      return;
    }

    setState(() => _isAdding = true);

    try {
      await widget.cartService.addRecipeToList(
        userId:      widget.uid,
        listId:      targetId,
        recipeId:    widget.recipeId,
        recipeName:  widget.recipeName,
        ingredients: widget.ingredients,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added to "${_showNewInput ? _newListCtrl.text.trim() : (_lists.firstWhere((l) => l['id'] == targetId, orElse: () => {'name': 'list'})['name'])}"',
                ),
              ),
            ]),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.orange, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Add to Shopping List',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ]),
              ),

              const Divider(height: 20),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.restaurant_menu,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.recipeName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ...widget.ingredients.map((ing) {
                        final amount =
                        ing['amount'] != null && ing['amount'] != 0
                            ? '${ing['amount']} '
                            : '';
                        final unit = (ing['unit'] ?? '').toString().trim();
                        final detail = '$amount$unit'.trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Container(
                              width: 5,
                              height: 5,
                              margin:
                              const EdgeInsets.only(right: 8, top: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ing['name']?.toString() ?? '',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade900),
                              ),
                            ),
                            if (detail.isNotEmpty)
                              Text(
                                detail,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700),
                              ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.orange))
                    : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20),
                  children: [
                    Text('Choose a list',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                    const SizedBox(height: 10),

                    ..._lists.map((list) {
                      final id   = list['id'] as String;
                      final name = list['name'] as String? ?? '';
                      final isSelected = !_showNewInput &&
                          _selectedListId == id;

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedListId = id;
                          _showNewInput   = false;
                        }),
                        child: AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 150),
                          margin:
                          const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange.shade50
                                : Colors.grey[50],
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.list_alt_rounded,
                                size: 16,
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey[500]),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.orange.shade800
                                    : Colors.black87,
                              ),
                            ),
                          ]),
                        ),
                      );
                    }),

                    GestureDetector(
                      onTap: () => setState(
                              () => _showNewInput = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _showNewInput
                              ? Colors.orange.shade50
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _showNewInput
                                ? Colors.orange
                                : Colors.grey.shade200,
                            width: _showNewInput ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _showNewInput
                                ? Icons.radio_button_checked
                                : Icons.add_circle_outline,
                            size: 20,
                            color: _showNewInput
                                ? Colors.orange
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _showNewInput
                                ? TextField(
                              controller: _newListCtrl,
                              autofocus: true,
                              textCapitalization:
                              TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText:
                                'e.g. Sunday BBQ…',
                                hintStyle: TextStyle(
                                    color:
                                    Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding:
                                EdgeInsets.zero,
                                isDense: true,
                              ),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight.w600),
                            )
                                : Text(
                              'Create new list',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedListId != null || _showNewInput) &&
                        !_isAdding
                        ? _addToCart
                        : null,
                    icon: _isAdding
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.add_shopping_cart_rounded,
                        size: 18),
                    label: Text(
                      _isAdding ? 'Adding…' : 'Add to List',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.orange.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Recipe Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditRecipeSheet extends StatefulWidget {
  final Map<String, dynamic> data;

  const _EditRecipeSheet({required this.data});

  @override
  State<_EditRecipeSheet> createState() => _EditRecipeSheetState();
}

class _EditRecipeSheetState extends State<_EditRecipeSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _servingsController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _ingNameController;
  late final TextEditingController _ingAmountController;
  late final TextEditingController _ingUnitController;

  late Diffculty             _selectedDifficulty;
  late Category?             _selectedCategory;
  late DietaryResrictions?   _selectedRestriction;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _titleController       = TextEditingController(text: d['recipeName']  as String? ?? '');
    _descriptionController = TextEditingController(text: d['description'] as String? ?? '');
    _prepTimeController    = TextEditingController(text: '${(d['prepTime'] as num?)?.toInt() ?? 0}');
    _cookTimeController    = TextEditingController(text: '${(d['cookTime'] as num?)?.toInt() ?? 0}');
    _servingsController    = TextEditingController(text: '${(d['servings'] as num?)?.toInt() ?? 1}');

    final instrList = (d['instructions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .join('\n') ??
        '';
    _instructionsController = TextEditingController(text: instrList);

    final ing = d['ingredients'] as Map<String, dynamic>?;
    _ingNameController   = TextEditingController(text: ing?['name']?.toString()   ?? '');
    _ingAmountController = TextEditingController(text: ing?['amount']?.toString() ?? '');
    _ingUnitController   = TextEditingController(text: ing?['unit']?.toString()   ?? '');

    _selectedDifficulty = Diffculty.values.firstWhere(
          (e) => e.name == (d['difficulty'] as String?),
      orElse: () => Diffculty.Easy,
    );
    _selectedCategory = Category.values.firstWhere(
          (e) => e.name == (d['category'] as String?),
      orElse: () => Category.Lunch,
    ) as Category?;
    _selectedRestriction = DietaryResrictions.values.firstWhere(
          (e) => e.name == (d['dietaryRestrictions'] as String?),
      orElse: () => DietaryResrictions.Vegan,
    ) as DietaryResrictions?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _instructionsController.dispose();
    _ingNameController.dispose();
    _ingAmountController.dispose();
    _ingUnitController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
      return;
    }

    final updated = <String, dynamic>{
      'recipeName':          _titleController.text.trim(),
      'description':         _descriptionController.text.trim(),
      'prepTime':            int.tryParse(_prepTimeController.text.trim()) ?? 0,
      'cookTime':            int.tryParse(_cookTimeController.text.trim()) ?? 0,
      'servings':            int.tryParse(_servingsController.text.trim()) ?? 1,
      'difficulty':          _selectedDifficulty.name,
      'category':            _selectedCategory?.name ?? '',
      'dietaryRestrictions': _selectedRestriction?.name ?? '',
      'instructions': _instructionsController.text
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList(),
      'ingredients': {
        'id': (widget.data['ingredients'] as Map?)?.containsKey('id') == true
            ? widget.data['ingredients']['id']
            : 0,
        'name':   _ingNameController.text.trim(),
        'amount': int.tryParse(_ingAmountController.text.trim()) ?? 0,
        'unit':   _ingUnitController.text.trim(),
      },
    };

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Edit Recipe',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                              : const Text('Save'),
                        ),
                      ]),
                    ],
                  ),
                ]),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    _label('Recipe Title *'),
                    _field(_titleController, 'Enter recipe title'),
                    const SizedBox(height: 16),
                    _label('Description'),
                    _field(_descriptionController, 'Describe your recipe…',
                        maxLines: 3),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Prep (min)'),
                            _field(_prepTimeController, '0'),
                          ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Cook (min)'),
                            _field(_cookTimeController, '0'),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Servings'),
                            _field(_servingsController, '1'),
                          ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Difficulty'),
                            _dropdown<Diffculty>(
                              value: _selectedDifficulty,
                              items: Diffculty.values,
                              onChanged: (v) =>
                                  setState(() => _selectedDifficulty = v!),
                            ),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    _label('Category'),
                    _dropdown<Category>(
                      value: _selectedCategory,
                      items: Category.values,
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 16),
                    _label('Dietary Restriction'),
                    _dropdown<DietaryResrictions>(
                      value: _selectedRestriction,
                      items: DietaryResrictions.values,
                      onChanged: (v) =>
                          setState(() => _selectedRestriction = v),
                    ),
                    const SizedBox(height: 16),
                    _label('Ingredient'),
                    Row(children: [
                      Expanded(flex: 2, child: _field(_ingNameController, 'Name')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_ingAmountController, 'Qty')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_ingUnitController, 'Unit')),
                    ]),
                    const SizedBox(height: 16),
                    _label('Instructions (one step per line)'),
                    _field(_instructionsController, 'Step 1…\nStep 2…',
                        maxLines: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Colors.orange, width: 1.5)),
        ),
      );

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon:
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            items: items
                .map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                item is Enum ? item.name : item.toString(),
                style: const TextStyle(fontSize: 14),
              ),
            ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}