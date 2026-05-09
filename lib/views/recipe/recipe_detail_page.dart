import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/recipe_services.dart';
import 'package:appdevproject/services/cloudinary_service.dart';
import 'package:appdevproject/views/profile/user_profile_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const RecipeDetailPage({super.key, required this.data});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final RecipeService _recipeService = RecipeService();

  bool _isLiked     = false;
  bool _likeLoading = false;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.data['likes'] as num?)?.toInt() ?? 0;
    _checkLiked();
  }

  Future<void> _checkLiked() async {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) return;
    final liked = await _recipeService.isLikedByUser(
        widget.data['id'] as String, uid);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null || _likeLoading) return;

    setState(() {
      _likeLoading = true;
      _isLiked    = !_isLiked;
      _likeCount  += _isLiked ? 1 : -1;
    });

    try {
      await _recipeService.toggleLike(widget.data['id'] as String, uid);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked   = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
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

  void _goToAuthorProfile() {
    final userId   = widget.data['userId']   as String?;
    final userName = widget.data['userName'] as String?;
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
    final data       = widget.data;
    final imageUrl   = data['image']       as String? ?? '';
    final title      = data['recipeName']  as String? ?? 'Untitled';
    final desc       = data['description'] as String? ?? '';
    final userName   = data['userName']    as String? ?? 'Anonymous';
    final userAvatar = data['userAvatar']  as String? ?? '';
    final prepTime   = (data['prepTime']   as num?)?.toInt() ?? 0;
    final cookTime   = (data['cookTime']   as num?)?.toInt() ?? 0;
    final servings   = (data['servings']   as num?)?.toInt() ?? 0;
    final difficulty = data['difficulty']  as String? ?? '';
    final category   = data['category']   as String? ?? '';
    final dietary    = data['dietaryRestrictions'] as String? ?? '';

    final ingredients  = data['ingredients']  as Map<String, dynamic>?;
    final instructions = (data['instructions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── hero image app bar ───────────────────────────────────────────
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
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.35),
                  child: _likeLoading
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: _toggleLike,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
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
                  // Gradient fade at the bottom so the app bar title is readable
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

          // ── content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // Author row — tappable
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
                        _statCell(Icons.people_outline,
                            '$servings', 'Servings'),
                        _vertDivider(),
                        _statCell(Icons.signal_cellular_alt,
                            difficulty, 'Difficulty'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Likes + dietary tags
                  Row(children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('$_likeCount likes',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                    if (dietary.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _tag(dietary.toLowerCase()),
                    ],
                  ]),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Description
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

                  // Ingredients
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

                  // Instructions
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

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
    Icon(icon, size: 20, color: Colors.orange),
    const SizedBox(width: 8),
    Text(title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold)),
  ]);

  Widget _tag(String label) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Text('$amount ${unit}'.trim(),
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