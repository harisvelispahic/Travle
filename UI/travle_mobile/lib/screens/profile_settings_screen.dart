import 'dart:convert';

import 'package:travle_mobile/layouts/master_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/user_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final User user;

  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, dynamic> _initalValue = {};

  late UserProvider _userProvider;

  String? base64ProfileImage;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    base64ProfileImage = widget.user.profileImageBase64;

    _initalValue = {
      'firstName': widget.user.firstName,
      'lastName': widget.user.lastName,
      'email': widget.user.email,
      'username': widget.user.username,
      'phoneNumber': widget.user.phoneNumber,
    };

    _userProvider = context.read<UserProvider>();
  }

  Future _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        var file = result.files.first;
        var bytes = await file.xFile.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          base64ProfileImage = base64String;
        });
      }
    } catch (e) {
      alertBox(context, "Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: "Profile Settings",
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildForm(),
                  SizedBox(height: 15),
                  _buildSaveButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ElevatedButton _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        _formKey.currentState?.save();

        try {
          if (_formKey.currentState!.validate()) {
            Map<String, dynamic> request = Map.of(_formKey.currentState!.value);

            if (base64ProfileImage != null) {
              request['profileImageBase64'] = base64ProfileImage;
            }

            await _userProvider.update(widget.user.id!, request);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Profile successfully edited")),
            );

            Navigator.pop(context, 'reload');
          }
        } on Exception catch (e) {
          alertBox(context, "Error", e.toString());
        }
        if (_formKey.currentState!.validate()) {
          Map<String, dynamic> request = Map.of(_formKey.currentState!.value);

          await _userProvider.update(widget.user.id!, request);
        }
      },
      child: Text("Save", style: TextStyle(fontSize: 16)),
    );
  }

  FormBuilder _buildForm() {
    return FormBuilder(
      key: _formKey,
      initialValue: _initalValue,
      child: Column(
        children: [
          InkWell(
            onTap: _pickFile,
            child: CircleAvatar(
              backgroundImage: base64ProfileImage != null
                  ? ImageFromBase64StringWithoutDimnesions(base64ProfileImage!)
                  : AssetImage("assets/images/no_profile.png"),
              radius: 70,
            ),
          ),
          FormBuilderTextField(
            name: "firstName",
            decoration: InputDecoration(labelText: "First Name"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return mField;
              } else {
                return null;
              }
            },
          ),
          SizedBox(height: 10),
          FormBuilderTextField(
            name: "lastName",
            decoration: InputDecoration(labelText: "Last Name"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return mField;
              } else {
                return null;
              }
            },
          ),
          SizedBox(height: 10),
          FormBuilderTextField(
            name: "username",
            decoration: InputDecoration(labelText: "Userame"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return mField;
              } else {
                return null;
              }
            },
          ),
          SizedBox(height: 10),
          FormBuilderTextField(
            name: "email",
            decoration: InputDecoration(labelText: "Email"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return mField;
              } else if (!RegExp(
                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
              ).hasMatch(value)) {
                return "Invalid email";
              } else {
                return null;
              }
            },
          ),
          SizedBox(height: 10),
          FormBuilderTextField(
            name: "phoneNumber",
            decoration: InputDecoration(labelText: "Phone"),
          ),
        ],
      ),
    );
  }
}
