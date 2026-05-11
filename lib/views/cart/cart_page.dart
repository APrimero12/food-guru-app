// lib/views/cart/cart_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/cart_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  String? _selectedListId;

  // ── helpers ───────────────────────────────────────────────────────────────

  String? get _uid =>
      Provider.of<UserProvider>(context, listen: false).currentUser?.uid;

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ── create list dialog ────────────────────────────────────────────────────

  Future<void> _showCreateListDialog({String? initialName, String? editId}) async {
    final ctrl = TextEditingController(text: initialName ?? '');
    final isEdit = editId != null;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Rename List' : 'New Shopping List'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Sunday BBQ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isEdit ? 'Rename' : 'Create'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || _uid == null) return;

    try {
      if (isEdit) {
        await _cartService.renameList(_uid!, editId, result);
      } else {
        final id = await _cartService.createList(_uid!, result);
        setState(() => _selectedListId = id);
      }
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  // ── delete list confirm ───────────────────────────────────────────────────

  Future<void> _confirmDeleteList(String listId, String listName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete List'),
        content: Text('Delete "$listName" and all its items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
    if (ok != true || _uid == null) return;

    try {
      await _cartService.deleteList(_uid!, listId);
      if (_selectedListId == listId) {
        setState(() => _selectedListId = null);
      }
    } catch (e) {
      _snack('Failed to delete list: $e', isError: true);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _cartService.listsStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }

        final lists = snap.data?.docs ?? [];

        // Auto-select first list if none selected or selected was deleted.
        if (lists.isNotEmpty &&
            (_selectedListId == null ||
                !lists.any((d) => d.id == _selectedListId))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedListId = lists.first.id);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header ──────────────────────────────────────────────────────
            _buildHeader(lists, uid),

            // ── list chips ───────────────────────────────────────────────────
            if (lists.isNotEmpty) _buildListChips(lists, uid),

            const Divider(height: 1),

            // ── items panel ──────────────────────────────────────────────────
            Expanded(
              child: lists.isEmpty
                  ? _buildEmptyState()
                  : _selectedListId == null
                  ? const SizedBox.shrink()
                  : _buildItemsPanel(uid, _selectedListId!,
                  (lists.firstWhere((d) => d.id == _selectedListId)
                      .data() as Map<String, dynamic>)['name']
                  as String? ??
                      ''),
            ),
          ],
        );
      },
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(List<QueryDocumentSnapshot> lists, String uid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined,
              color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Shopping Lists',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showCreateListDialog(),
            icon: const Icon(Icons.add, size: 18, color: Colors.orange),
            label: const Text('New List',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
            style: TextButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.orange)),
            ),
          ),
        ],
      ),
    );
  }

  // ── list chips ────────────────────────────────────────────────────────────

  Widget _buildListChips(
      List<QueryDocumentSnapshot> lists, String uid) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final doc  = lists[i];
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] as String? ?? '';
          final isSelected = _selectedListId == doc.id;

          return GestureDetector(
            onTap: () => setState(() => _selectedListId = doc.id),
            onLongPress: () => _showListOptions(doc.id, name, uid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                  isSelected ? Colors.orange : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showListOptions(String listId, String name, String uid) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.edit_outlined, color: Colors.orange)),
                title: const Text('Rename list'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateListDialog(
                      initialName: name, editId: listId);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child:
                    Icon(Icons.delete_outline, color: Colors.red)),
                title: const Text('Delete list',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteList(listId, name);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 72, color: Colors.grey[200]),
            const SizedBox(height: 20),
            const Text('No shopping lists yet',
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Create a list like "Sunday BBQ" and add ingredients from any recipe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateListDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create First List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── items panel ───────────────────────────────────────────────────────────

  Widget _buildItemsPanel(String uid, String listId, String listName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cartService.itemsStream(uid, listId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }

        final items = snap.data?.docs ?? [];

        if (items.isEmpty) {
          return _buildEmptyItems(listName);
        }

        // Group items by recipe.
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in items) {
          final data     = doc.data() as Map<String, dynamic>;
          final key      = '${data['recipeId'] ?? ''}|${data['recipeName'] ?? 'Other'}';
          grouped[key] ??= [];
          grouped[key]!.add(doc);
        }

        final checkedCount =
            items.where((d) => (d.data() as Map)['checked'] == true).length;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: grouped.length,
                itemBuilder: (context, i) {
                  final key     = grouped.keys.elementAt(i);
                  final group   = grouped[key]!;
                  final data0   = group.first.data() as Map<String, dynamic>;
                  final recipe  = data0['recipeName'] as String? ?? 'Unknown Recipe';

                  return _buildRecipeGroup(
                      uid, listId, recipe, group);
                },
              ),
            ),

            // ── footer bar ─────────────────────────────────────────────────
            if (checkedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border:
                  Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  Text(
                    '$checkedCount item${checkedCount > 1 ? 's' : ''} checked',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await _cartService.clearCheckedItems(uid, listId);
                        _snack('Checked items removed.');
                      } catch (e) {
                        _snack('Failed: $e', isError: true);
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_outlined,
                        size: 16, color: Colors.red),
                    label: const Text('Clear checked',
                        style:
                        TextStyle(color: Colors.red, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  ),
                ]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyItems(String listName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              '"$listName" is empty',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Open any recipe and tap "Add to Cart"\nto build your shopping list.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── recipe group card ─────────────────────────────────────────────────────

  Widget _buildRecipeGroup(
      String uid,
      String listId,
      String recipeName,
      List<QueryDocumentSnapshot> items) {
    final allChecked =
    items.every((d) => (d.data() as Map)['checked'] == true);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe header
          Padding(
            padding:
            const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.restaurant_menu,
                      size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    recipeName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              // Remove entire recipe from list
              IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    size: 18, color: Colors.grey[400]),
                tooltip: 'Remove recipe from list',
                onPressed: () async {
                  final recipeId =
                  (items.first.data() as Map)['recipeId'] as String?;
                  if (recipeId == null) return;
                  try {
                    await _cartService.removeRecipeFromList(
                        uid, listId, recipeId);
                  } catch (e) {
                    _snack('Failed: $e', isError: true);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // Ingredient rows
          ...items.map((doc) => _buildIngredientRow(uid, listId, doc)),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(
      String uid, String listId, QueryDocumentSnapshot doc) {
    final data    = doc.data() as Map<String, dynamic>;
    final checked = data['checked'] as bool? ?? false;
    final name    = data['name']   as String? ?? '';
    final amount  = data['amount'];
    final unit    = data['unit']   as String? ?? '';

    final amountStr = amount != null && amount != 0 ? '$amount ' : '';
    final detail    = '$amountStr$unit'.trim();

    return InkWell(
      onTap: () async {
        try {
          await _cartService.toggleItem(
            userId:  uid,
            listId:  listId,
            itemId:  doc.id,
            checked: !checked,
          );
        } catch (_) {}
      },
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? Colors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: checked ? Colors.orange : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: checked
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: checked ? Colors.grey[400] : Colors.black87,
                decoration: checked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
          // Amount + unit badge
          if (detail.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: checked ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // Delete
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
            tooltip: 'Remove item',
            onPressed: () async {
              try {
                await _cartService.removeItem(uid, listId, doc.id);
              } catch (e) {
                _snack('Failed: $e', isError: true);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}