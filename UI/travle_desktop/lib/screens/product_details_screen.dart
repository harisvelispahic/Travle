import 'dart:convert';
import 'dart:ui';

import 'package:travle_desktop/layouts/master_screen.dart';
import 'package:travle_desktop/models/product.dart';
import 'package:travle_desktop/models/product_type.dart';
import 'package:travle_desktop/models/search_result.dart';
import 'package:travle_desktop/models/unit_of_measure.dart';
import 'package:travle_desktop/providers/product_provider.dart';
import 'package:travle_desktop/providers/product_type_provider.dart';
import 'package:travle_desktop/providers/unit_of_measure_provider.dart';
import 'package:travle_desktop/utils/utils_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/asset_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product? product;

  const ProductDetailsScreen({super.key, this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic> _initalValue = {};

  late ProductProvider _productProvider;
  late ProductTypeProvider _productTypeProvider;
  late UnitOfMeasureProvider _unitOfMeasureProvider;
  late AssetProvider _assetProvider;

  bool isLoading = true;

  SearchResult<UnitOfMeasure>? unitsOfMeasureResult;
  SearchResult<ProductType>? productTypesResult;
  SearchResult<Asset>? assetsResult;

  List<Asset> newAssets = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _initalValue = {
      'name': widget.product?.name,
      'price': widget.product?.price.toString(),
      'productTypeId': widget.product?.productTypeId,
      'unitOfMeasureId': widget.product?.unitOfMeasureId,
    };

    _productProvider = context.read<ProductProvider>();
    _productTypeProvider = context.read<ProductTypeProvider>();
    _unitOfMeasureProvider = context.read<UnitOfMeasureProvider>();
    _assetProvider = context.read<AssetProvider>();

    initForm();
  }

  Future initForm() async {
    try {
      var productTypes = await _productTypeProvider.get(filter: {});
      var unitsOfMeasure = await _unitOfMeasureProvider.get(filter: {});

      var assets = SearchResult<Asset>();

      if (widget.product != null) {
        assets = await _assetProvider.get(
          filter: {'productId': widget.product!.id},
        );
      }

      setState(() {
        productTypesResult = productTypes;
        unitsOfMeasureResult = unitsOfMeasure;

        if (widget.product != null) {
          assetsResult = assets;
        }

        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, "Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: widget.product == null ? "New Product" : "Update product",
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildForm(),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                child: Row(
                  children: [
                    Text("Products assets", style: TextStyle(fontSize: 22)),
                    SizedBox(width: 16),
                    IconButton(onPressed: _pickFiles, icon: Icon(Icons.add)),
                  ],
                ),
              ),
              (assetsResult == null || assetsResult!.items!.isEmpty)
                  ? (newAssets.isEmpty ? SizedBox() : _buildAssetList())
                  : _buildAssetList(),
              _saveButton(context),
            ],
          ),
        ),
      ),
    );
  }

  SizedBox _buildAssetList() {
    List<Asset> allAssets = [];

    // Add existing assets
    if (assetsResult?.items != null) {
      allAssets.addAll(assetsResult!.items!);
    }

    // Add newly selected assets
    allAssets.addAll(newAssets);

    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        // Add a custom scroll behavior that
        // allows all devices to drag the list.
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {...PointerDeviceKind.values},
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: allAssets.length,
          itemBuilder: (context, index) => SizedBox(
            width: 200,
            child: Stack(
              children: [
                imageFromBase64String(allAssets[index].base64Content!),
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton(
                    onPressed: () {
                      if (allAssets[index].id != null &&
                          allAssets[index].id! > 0) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Delete"),
                            content: Text(
                              "Are you sure you want to delete this asset?",
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
                                    _assetProvider.remove(allAssets[index].id!);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Asset deleted successfully",
                                        ),
                                      ),
                                    );

                                    Navigator.pop(context);

                                    setState(() {
                                      assetsResult!.items!.remove(
                                        allAssets[index],
                                      );
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
                      } else {
                        setState(() {
                          newAssets.remove(allAssets[index]);
                        });
                      }
                    },
                    icon: Icon(Icons.delete),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red, // icon color
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null) {
        for (var file in result.files) {
          var bytes = await file.xFile.readAsBytes();
          final base64String = base64Encode(bytes);

          setState(() {
            newAssets.add(
              Asset(
                id: 0,
                fileName: file.name,
                contentType: file.extension != null
                    ? 'image/${file.extension}'
                    : 'image/png',
                base64Content: base64String,
                productId: 0,
              ),
            );
          });
        }
      }
    } catch (e) {
      alertBox(context, "Error", e.toString());
    }
  }

  Padding _saveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: ElevatedButton(
        onPressed: () async {
          _formKey.currentState?.save();

          try {
            if (_formKey.currentState!.validate()) {
              if (widget.product != null) {
                Map<String, dynamic> request = Map.of(
                  _formKey.currentState!.value,
                );

                request['id'] = widget.product?.id;

                var price = double.parse(_formKey.currentState!.value['price']);

                request['price'] = price;
                print(request);

                // Add selected assets to request
                if (newAssets.isNotEmpty) {
                  request['assets'] = newAssets
                      .map((asset) => asset.toJson())
                      .toList();
                }

                print(widget.product!.productTypeId);
                print(_formKey.currentState!.value['productTypeId']);

                await _productProvider.update(widget.product!.id!, request);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Product successfully modified")),
                );

                Navigator.pop(context, 'reload');
              } else {
                Map<String, dynamic> request = Map.of(
                  _formKey.currentState!.value,
                );

                var price = double.parse(_formKey.currentState!.value['price']);

                request['price'] = price;

                // Add selected assets to request
                if (newAssets.isNotEmpty) {
                  request['assets'] = newAssets
                      .map((asset) => asset.toJson())
                      .toList();
                }

                await _productProvider.insert(request);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Product successfully added")),
                );

                Navigator.pop(context, 'reload');
              }
            }
          } on Exception catch (e) {
            alertBox(context, "Error", e.toString());
          }
        },
        child: Text("Save", style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _buildForm() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return mField;
                    } else {
                      return null;
                    }
                  },
                  decoration: InputDecoration(label: Text("Name")),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FormBuilderTextField(
                  name: 'price',
                  validator: (value) {
                    if (value == null) {
                      return mField;
                    } else if (double.tryParse(value) == null) {
                      return numericField;
                    } else {
                      return null;
                    }
                  },
                  decoration: InputDecoration(label: Text("Price")),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: FormBuilderDropdown(
                  name: "unitOfMeasureId",
                  decoration: InputDecoration(labelText: "Unit of Measure"),
                  items:
                      unitsOfMeasureResult?.items
                          ?.map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name!),
                            ),
                          )
                          .toList() ??
                      [],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FormBuilderDropdown(
                  name: "productTypeId",
                  decoration: InputDecoration(labelText: "Product Type"),
                  items:
                      productTypesResult?.items
                          ?.map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name!),
                            ),
                          )
                          .toList() ??
                      [],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
