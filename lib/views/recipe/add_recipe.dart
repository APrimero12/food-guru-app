import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/recipe_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/cloudinary_service.dart';
import 'package:appdevproject/services/recipe_services.dart';

class AddRecipe extends StatefulWidget {
  const AddRecipe({super.key});

  @override
  State<AddRecipe> createState() => _AddRecipeState();
}

class _AddRecipeState extends State<AddRecipe> {
  final _titleController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController    = TextEditingController();
  final _cookTimeController    = TextEditingController();
  final _servingsController    = TextEditingController();
  final _instructionsController = TextEditingController();

  Diffculty _selectedDifficulty = Diffculty.Easy;
  Category? _selectedCategory;
  final List<DietaryResrictions> _selectedRestrictions = [];

  final List<Map<String, TextEditingController>> _ingredients = [
    {
      'name':   TextEditingController(),
      'amount': TextEditingController(),
      'unit':   TextEditingController(),
    }
  ];

  // ── Image state ───────────────────────────────────────────────────────────
  File?   _imageFile;
  double? _uploadProgress;
  bool    _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _instructionsController.dispose();
    for (final c in _ingredients) {
      c['name']?.dispose();
      c['amount']?.dispose();
      c['unit']?.dispose();
    }
    super.dispose();
  }

  // ── Image helpers ─────────────────────────────────────────────────────────

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.photo_library, color: Colors.orange),
                ),
                title: const Text('Choose from gallery'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Take a photo'),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              if (_imageFile != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Remove photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _imageFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  // ── Ingredient row ────────────────────────────────────────────────────────

  void _addIngredient() {
    setState(() {
      _ingredients.add({
        'name':   TextEditingController(),
        'amount': TextEditingController(),
        'unit':   TextEditingController(),
      });
    });
  }

  void _removeIngredient(int index) {
    if (_ingredients.length == 1) return; // keep at least one row
    setState(() {
      _ingredients[index]['name']?.dispose();
      _ingredients[index]['amount']?.dispose();
      _ingredients[index]['unit']?.dispose();
      _ingredients.removeAt(index);
    });
  }

  // ── Publish ───────────────────────────────────────────────────────────────

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _publish() async {
    // Basic validation
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a recipe title.', isError: true); return;
    }
    if (_imageFile == null) {
      _showSnackBar('Please add a photo for your recipe.', isError: true); return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category.', isError: true); return;
    }

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) {
      _showSnackBar('You must be logged in to post a recipe.', isError: true); return;
    }

    setState(() { _isPublishing = true; _uploadProgress = 0; });

    try {
      // 1. Upload image to Cloudinary
      final imageUrl = await CloudinaryService.upload(
        file: _imageFile!,
        folder: 'foodguru/recipe_photos',
        publicId:
        'recipe_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      setState(() => _uploadProgress = null);

      // 2. Build ingredient (only first row for now — matches the model)
      final ing = Ingredients(
        0,
        _ingredients[0]['name']!.text.trim(),
        int.tryParse(_ingredients[0]['amount']!.text.trim()) ?? 0,
        _ingredients[0]['unit']!.text.trim(),
      );

      // 3. Save to Firestore
      await RecipeService().createRecipe(
        user: user,
        image: imageUrl,
        recipeName: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        prepTime: int.tryParse(_prepTimeController.text.trim()) ?? 0,
        cookTime: int.tryParse(_cookTimeController.text.trim()) ?? 0,
        servings: int.tryParse(_servingsController.text.trim()) ?? 1,
        difficulty: _selectedDifficulty,
        category: _selectedCategory!,
        dietaryRestrictions: _selectedRestrictions.isNotEmpty
            ? _selectedRestrictions.first
            : DietaryResrictions.Vegan,
        ingredients: ing,
        instructions: _instructionsController.text.trim().isNotEmpty
            ? [Instruction(_instructionsController.text.trim())]
            : null,
      );

      _showSnackBar('Recipe published!');
      _resetForm();
    } catch (e) {
      _showSnackBar('Failed to publish: $e', isError: true);
      setState(() => _uploadProgress = null);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _prepTimeController.clear();
    _cookTimeController.clear();
    _servingsController.clear();
    _instructionsController.clear();
    for (final c in _ingredients) {
      c['name']?.clear(); c['amount']?.clear(); c['unit']?.clear();
    }
    setState(() {
      _imageFile = null;
      _selectedCategory = null;
      _selectedRestrictions.clear();
      _selectedDifficulty = Diffculty.Easy;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Column(children: [
                    Icon(Icons.upload_outlined, size: 40, color: Colors.orange.shade400),
                    const SizedBox(height: 8),
                    const Text('Upload Your Recipe',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ])),
                  const SizedBox(height: 32),

                  // ── Recipe photo picker ──────────────────────────────────
                  _buildLabel('Recipe Photo *'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isPublishing ? null : _showImageOptions,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _imageFile != null
                              ? Colors.orange
                              : Colors.grey.shade300,
                          width: _imageFile != null ? 2 : 1,
                          style: _imageFile != null
                              ? BorderStyle.solid
                              : BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageFile != null
                          ? Stack(fit: StackFit.expand, children: [
                        Image.file(_imageFile!, fit: BoxFit.cover),
                        // Edit overlay
                        Positioned(
                          bottom: 8, right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Change', style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ])
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Tap to add a photo',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text('Gallery or camera',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ),

                  // Upload progress
                  if (_uploadProgress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Uploading photo…',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],

                  const SizedBox(height: 20),

                  // ── Rest of the form ─────────────────────────────────────
                  _buildLabel('Recipe Title *'),
                  _buildTextField(_titleController,
                      'e.g., Classic Chocolate Chip Cookies'),
                  const SizedBox(height: 20),

                  _buildLabel('Description *'),
                  _buildTextField(_descriptionController,
                      'Briefly describe your recipe...', maxLines: 3),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Prep (min) *'),
                        _buildTextField(_prepTimeController, ''),
                      ],
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Cook (min) *'),
                        _buildTextField(_cookTimeController, ''),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Servings *'),
                        _buildTextField(_servingsController, ''),
                      ],
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Difficulty *'),
                        _buildDropdown<Diffculty>(
                          value: _selectedDifficulty,
                          items: Diffculty.values,
                          onChanged: (v) =>
                              setState(() => _selectedDifficulty = v!),
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),

                  _buildLabel('Category *'),
                  _buildDropdown<Category>(
                    value: _selectedCategory,
                    items: Category.values,
                    hint: 'Select a category',
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Dietary Restrictions'),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: DietaryResrictions.values.map((r) {
                      final selected = _selectedRestrictions.contains(r);
                      return ChoiceChip(
                        label: Text(r.name.toLowerCase(),
                            style: TextStyle(
                                color: selected
                                    ? Colors.orange.shade800
                                    : Colors.black87,
                                fontSize: 12)),
                        selected: selected,
                        onSelected: (on) => setState(() => on
                            ? _selectedRestrictions.add(r)
                            : _selectedRestrictions.remove(r)),
                        selectedColor: Colors.orange.shade50,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: selected
                                  ? Colors.orange.shade200
                                  : Colors.grey.shade300),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Ingredients *'),
                  ...List.generate(_ingredients.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(flex: 2,
                          child: _buildTextField(_ingredients[i]['name']!, 'Name')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildTextField(_ingredients[i]['amount']!, 'Qty')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildTextField(_ingredients[i]['unit']!, 'Unit')),
                      const SizedBox(width: 4),
                      // Remove row button (hidden on the first row)
                      if (i > 0)
                        GestureDetector(
                          onTap: () => _removeIngredient(i),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                          ),
                        )
                      else
                        const SizedBox(width: 28),
                    ]),
                  )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _addIngredient,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1C1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Instructions *'),
                  _buildTextField(_instructionsController,
                      'Step 1…', maxLines: 4),
                  const SizedBox(height: 32),

                  // Publish button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPublishing ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        disabledBackgroundColor: Colors.orange.shade200,
                      ),
                      child: _isPublishing
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Publish Recipe',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── form helpers ──────────────────────────────────────────────────────────

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange, width: 1)),
        ),
      );

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    String? hint,
    required ValueChanged<T?> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: hint != null
                ? Text(hint,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14))
                : null,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            items: items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                  item is Enum ? item.name : item.toString(),
                  style: const TextStyle(fontSize: 14)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      );
}