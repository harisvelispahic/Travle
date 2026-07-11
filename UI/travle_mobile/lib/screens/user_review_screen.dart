import 'package:travle_mobile/layouts/master_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_review.dart';
import '../models/search_result.dart';
import '../providers/auth_provider.dart';
import '../providers/product_review_provider.dart';
import '../utils/utils_widgets.dart';

class UserReviewScreen extends StatefulWidget {
  const UserReviewScreen({super.key});

  @override
  State<UserReviewScreen> createState() => _UserReviewScreenState();
}

class _UserReviewScreenState extends State<UserReviewScreen> {
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

    initData();
  }

  Future<void> initData() async {
    try {
      var data = await _productReviewProvider.get(
        filter: {
          'userId':
              int.tryParse(AuthProvider.accessTokenDecoded?['Id'] ?? '0') ?? 0,
          'rating': selectedRating,
        },
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
      title: "Your reviews",
      child: Column(
        children: [
          _buildSearch(),
          SizedBox(height: 20),
          isLoading ? CircularProgressIndicator() : buildReviewList(),
        ],
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
              await initData();
            },
            child: Text("Search"),
          ),
        ],
      ),
    );
  }

  Expanded buildReviewList() {
    return Expanded(
      child: ListView.builder(
        itemCount: result?.items?.length ?? 0,
        itemBuilder: (context, index) {
          var review = result!.items![index];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Row(
                children: [
                  Text(review.reviewerDisplayName),
                  SizedBox(width: 8),
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(review.comment),
              ),
            ),
          );
        },
      ),
    );
  }
}
