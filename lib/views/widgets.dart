import 'package:flutter/material.dart';
import 'package:appdevproject/services/cloudinary_service.dart';
import 'package:appdevproject/services/cloudinary_service.dart';
import 'package:appdevproject/services/cloudinary_service.dart';

class RecipeCard extends StatelessWidget {
  final String imageUrl;
  final String userName;
  final String userAvatar;
  final String title;
  final String description;
  final String time;
  final String servings;
  final List<String> tags;
  final String likes;
  final bool isLiked;
  final VoidCallback? onLikeTapped;
  final VoidCallback? onTapped;

  const RecipeCard({
    super.key,
    required this.imageUrl,
    required this.userName,
    required this.userAvatar,
    required this.title,
    required this.description,
    required this.time,
    required this.servings,
    required this.tags,
    required this.likes,
    this.isLiked = false,
    this.onLikeTapped,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapped,
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
            // ── image + like button ─────────────────────────────────────────
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                children: [
                  // Recipe photo
                  Positioned.fill(
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                      CloudinaryService.cardThumbnail(imageUrl),
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange),
                        ),
                      ),
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey),
                      ),
                    )
                        : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.restaurant,
                          color: Colors.grey, size: 40),
                    ),
                  ),

                  // Like button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onLikeTapped,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? Colors.red
                              : Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isLiked ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── card body ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author row
                    Row(children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userAvatar.isNotEmpty
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar.isEmpty
                            ? Icon(Icons.person,
                            size: 12, color: Colors.grey[500])
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                    const Spacer(),

                    // Time + servings
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(time,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                      Icon(Icons.people_outline,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('$servings servings',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ]),
                    const SizedBox(height: 8),

                    // Tags + like count
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                            tags.map((t) => _buildTag(t)).toList(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(children: [
                          Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: isLiked
                                ? Colors.red
                                : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(likes,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    final Color bg = switch (label.toLowerCase()) {
      'vegan'       => const Color(0xFFE8F5E9),
      'vegetarian'  => const Color(0xFFF3E5F5),
      'gluten'      => const Color(0xFFE3F2FD),
      'dairy'       => const Color(0xFFFFF8E1),
      'nuts'        => const Color(0xFFFFF3E0),
      'fish'        => const Color(0xFFE0F7FA),
      _             => const Color(0xFFF5F5F5),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54),
      ),
    );
  }
}