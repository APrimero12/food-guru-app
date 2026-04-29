import 'package:flutter/material.dart';
import '../../models/recipe_model.dart';

class AddRecipe extends StatefulWidget {
  const AddRecipe({super.key});

  @override
  State<AddRecipe> createState() => _AddRecipeState();
}

class _AddRecipeState extends State<AddRecipe> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  
  Diffculty _selectedDifficulty = Diffculty.Easy;
  Category? _selectedCategory;
  final List<DietaryResrictions> _selectedRestrictions = [];

  final List<Map<String, TextEditingController>> _ingredients = [
    {
      'name': TextEditingController(),
      'amount': TextEditingController(),
      'unit': TextEditingController(),
    }
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (var controllers in _ingredients) {
      controllers['name']?.dispose();
      controllers['amount']?.dispose();
      controllers['unit']?.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
        'unit': TextEditingController(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.upload_outlined, size: 40, color: Colors.orange.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload Your Recipe',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Recipe Title *'),
                  _buildTextField(_titleController, 'e.g., Classic Chocolate Chip Cookies'),
                  const SizedBox(height: 20),
                  _buildLabel('Description *'),
                  _buildTextField(_descriptionController, 'Briefly describe your recipe...', maxLines: 3),
                  const SizedBox(height: 20),
                  _buildLabel('Image URL *'),
                  _buildTextField(_imageUrlController, 'https://example.com/image.jpg'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Prep (min) *'),
                            _buildTextField(_prepTimeController, ''),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Cook (min) *'),
                            _buildTextField(_cookTimeController, ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Servings *'),
                            _buildTextField(_servingsController, ''),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Difficulty *'),
                            _buildDropdown<Diffculty>(
                              value: _selectedDifficulty,
                              items: Diffculty.values,
                              onChanged: (val) => setState(() => _selectedDifficulty = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Category *'),
                  _buildDropdown<Category>(
                    value: _selectedCategory,
                    items: Category.values,
                    hint: 'Select a category',
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Dietary Restrictions'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DietaryResrictions.values.map((restriction) {
                      final isSelected = _selectedRestrictions.contains(restriction);
                      return ChoiceChip(
                        label: Text(
                          restriction.name.toLowerCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.orange.shade800 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedRestrictions.add(restriction);
                            } else {
                              _selectedRestrictions.remove(restriction);
                            }
                          });
                        },
                        selectedColor: Colors.orange.shade50,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? Colors.orange.shade200 : Colors.grey.shade300,
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Ingredients *'),
                  ..._ingredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _buildTextField(ingredient['name']!, 'Name')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(ingredient['amount']!, 'Amount')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(ingredient['unit']!, 'Unit')),
                      ],
                    ),
                  )).toList(),
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
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Instructions *'),
                  _buildTextField(TextEditingController(), 'Step 1...', maxLines: 4),
                  const SizedBox(height: 32),
                  /// TODO: change the sized box into an elevated button
                  /// add functionality where it saves the data into the firebase
                  /// instead into an array of recipes

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Publish Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF1F3F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 1),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(
      {required T? value, required List<T> items, String? hint, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null ? Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)) : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item is Enum ? item.name : item.toString(),
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
