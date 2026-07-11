import 'package:travle_desktop/layouts/master_screen.dart';
import 'package:travle_desktop/models/search_result.dart';
import 'package:travle_desktop/providers/category_provider.dart';
import 'package:travle_desktop/screens/category_details_screen.dart';
import 'package:travle_desktop/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';

class CategoryList extends StatefulWidget {
  const CategoryList({super.key});

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  late CategoryProvider _categoryProvider;
  SearchResult<Category>? result;
  bool isLoading = true;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _categoryProvider = context.read<CategoryProvider>();

    initTable();
  }

  Future<void> initTable() async {
    try {
      var data = await _categoryProvider.get(filter: {});

      setState(() {
        result = data;
        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, 'Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: "Category List",
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearch(),
            isLoading ? CircularProgressIndicator() : _buildTable(),
          ],
        ),
      ),
    );
  }

  Expanded _buildTable() {
    return Expanded(
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: Text("Name")),
              DataColumn(label: Text("Description")),
              DataColumn(label: Text("Is Active")),
              DataColumn(label: Text("Delete")),
            ],
            rows:
                result?.items
                    ?.map(
                      (e) => DataRow(
                        onSelectChanged: (value) async {
                          var refresh = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryDetailsScreen(category: e),
                            ),
                          );

                          if (refresh == "reload") {
                            initTable();
                          }
                        },
                        cells: [
                          DataCell(Text(e.name ?? '')),
                          DataCell(Text(e.description.toString())),
                          DataCell(Text(e.isActive.toString())),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("Delete"),
                                    content: Text(
                                      "Are you sure you want to delete this category?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await _categoryProvider.remove(
                                              e.id!,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Category deleted successfully",
                                                ),
                                              ),
                                            );

                                            Navigator.pop(context);

                                            setState(() {
                                              initTable();
                                            });
                                          } on Exception catch (e) {
                                            alertBoxMoveBack(
                                              context,
                                              "Error",
                                              e.toString(),
                                            );
                                          }
                                        },
                                        child: Text("Yes"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList() ??
                List.empty(),
          ),
        ),
      ),
    );
  }

  Padding _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(label: Text("Name")),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                var data = await _categoryProvider.get(
                  filter: {"name": _nameController.text},
                );

                setState(() {
                  result = data;
                  isLoading = false;
                });
              } on Exception catch (e) {
                alertBox(context, 'Error', e.toString());
              }
            },
            child: Text("Search"),
          ),
          SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              var refresh = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const CategoryDetailsScreen(category: null),
                ),
              );

              if (refresh == "reload") {
                initTable();
              }
            },
            child: Text("New"),
          ),
        ],
      ),
    );
  }
}
