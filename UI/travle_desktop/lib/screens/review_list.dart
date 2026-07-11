import 'package:travle_desktop/layouts/master_screen.dart';
import 'package:travle_desktop/screens/review_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_review.dart';
import '../models/search_result.dart';
import '../providers/product_review_provider.dart';
import '../utils/utils_widgets.dart';

class ReviewList extends StatefulWidget {
  const ReviewList({super.key});

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  late ProductReviewProvider _productReviewProvider;
  SearchResult<ProductReview>? result;
  bool isLoading = true;

  int? selectedRating;

  final Map<int, String> ratings = {
    0: "All ratings",
    5: "Excellent",
    4: "Very good",
    3: "Good",
    2: "Bad",
    1: "Very bad",
  };

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _productReviewProvider = context.read<ProductReviewProvider>();

    initTable();
  }

  Future<void> initTable() async {
    try {
      var data = await _productReviewProvider.get(
        filter: {'rating': selectedRating},
      );

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
      title: "Review List",
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

  Padding _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField(
              initialValue: selectedRating,
              hint: const Text('Select rating'),
              items: ratings.entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: entry.key == 0
                      ? Text(entry.value)
                      : Text('${entry.key} - ${entry.value}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value == 0) {
                  value = null;
                }

                setState(() {
                  selectedRating = value;
                });
              },
            ),
          ),
          SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              initTable();
            },
            child: Text("Search"),
          ),
          SizedBox(width: 10),
        ],
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
              DataColumn(label: Text("Comment")),
              DataColumn(label: Text("Reviewer")),
              DataColumn(label: Text("Rating")),
              DataColumn(label: Text("Created At")),
              DataColumn(label: Text("Delete")),
            ],
            rows:
                result?.items
                    ?.map(
                      (e) => DataRow(
                        onSelectChanged: (value) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReviewDetailsScreen(review: e),
                            ),
                          );
                        },
                        cells: [
                          DataCell(
                            Text(
                              e.comment.length > 10
                                  ? "${e.comment.substring(0, 10)}..."
                                  : e.comment,
                            ),
                          ),
                          DataCell(Text(e.reviewerDisplayName)),
                          DataCell(Text(e.rating.toString())),
                          DataCell(
                            Text(
                              "${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}",
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("Delete"),
                                    content: Text(
                                      "Are you sure you want to delete this review?",
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
                                            await _productReviewProvider.remove(
                                              e.id,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Review deleted successfully",
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
}
