import 'package:travle_desktop/layouts/master_screen.dart';
import 'package:travle_desktop/models/category.dart';
import 'package:travle_desktop/models/search_result.dart';
import 'package:travle_desktop/providers/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final Category? category;

  const CategoryDetailsScreen({super.key, this.category});

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic> _initalValue = {};

  late CategoryProvider _categoryProvider;
  SearchResult<Category>? _categoriesResult;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _initalValue = {
      'name': widget.category?.name ?? '',
      'description': widget.category?.description ?? '',
      'parentCategoryId': widget.category?.parentCategoryId,
      'isActive': widget.category?.isActive ?? true,
    };

    _categoryProvider = context.read<CategoryProvider>();
    initForm();
  }

  Future initForm() async {
    var categories = await _categoryProvider.get(filter: {});

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (this.widget.category != null) {
        categories.items?.removeWhere((c) => c.id == this.widget.category!.id);
      }

      _categoriesResult = categories;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MasterScreen(
      title: widget.category != null ? 'Edit Category' : 'Create Category',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24.0),
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: theme.colorScheme.primaryContainer,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildForm(theme),
                  ),
                ),
                SizedBox(height: 24.0),
                _buildActions(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(
            Icons.category_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16.0),
        Column(
          children: [
            Text(
              widget.category != null
                  ? widget.category!.name!
                  : 'Create Category',
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              widget.category != null
                  ? 'Edit the category details'
                  : 'Fill the form to create a new category',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return FormBuilder(
      key: _formKey,
      initialValue: _initalValue,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'name',
                  decoration: const InputDecoration(label: Text("Name")),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: FormBuilderDropdown(
                  name: 'parentCategoryId',
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("None - top level"),
                    ),
                    ...?_categoriesResult?.items?.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          FormBuilderTextField(
            name: 'description',
            decoration: const InputDecoration(label: Text("Description")),
            maxLines: 4,
          ),
          const SizedBox(height: 16.0),
          FormBuilderCheckbox(
            name: 'isActive',
            title: const Text("Is Active"),
            subtitle: const Text("Check to activate the category"),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        const SizedBox(width: 16.0),
        ElevatedButton(onPressed: _save, child: const Text("Save")),
      ],
    );
  }

  Future _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      var formData = _formKey.currentState!.value;

      try {
        if (widget.category != null) {
          await _categoryProvider.update(widget.category!.id!, formData);
        } else {
          await _categoryProvider.insert(formData);
        }

        if (!mounted) return;
        Navigator.of(context).pop("reload");
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving category: $e")));
      }
    }
  }
}
