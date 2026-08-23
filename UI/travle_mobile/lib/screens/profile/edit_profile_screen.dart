import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Edit the signed-in user's profile: photo, personal details, and a home
/// **Location** (Country → Region → City cascade, all optional). Every field is a
/// partial update — unchanged values are simply re-sent, and an omitted photo or
/// city leaves the stored one untouched. The location is prefilled by resolving
/// the saved city up its region/country chain.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  // Photo: the currently stored image, and a newly picked replacement (if any).
  String? _currentImageBase64;
  String? _pickedImageBase64;
  String? _pickedContentType;

  // Location cascade.
  /// The chosen home city; the Country → Region → City chain above it is owned by
  /// [LocationCascadeField].
  int? _cityId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _firstName.text = user.firstName;
      _lastName.text = user.lastName;
      _username.text = user.username;
      _email.text = user.email;
      _phone.text = user.phoneNumber ?? '';
      // Self reads carry only the thumbnail now; use it as the current-photo preview.
      _currentImageBase64 = user.profileImageThumbnail ?? user.profileImage;
      _cityId = user.cityId;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    if (!mounted) return;

    final contentType = ImageCodec.sniffContentType(bytes);
    if (contentType == null) {
      AppSnackbars.error(context, 'Please choose a JPEG or PNG image.');
      return;
    }
    if (bytes.length > ImageCodec.maxImageBytes) {
      AppSnackbars.error(context, 'The image must be 5 MB or smaller.');
      return;
    }
    setState(() {
      _pickedImageBase64 = ImageCodec.encode(bytes);
      _pickedContentType = contentType;
    });
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final userId = auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'Your session is not ready. Please try again.');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await userProvider.updateProfile(
        userId,
        UserUpdateRequest(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          cityId: _cityId,
          profileImage: _pickedImageBase64,
          profileImageContentType: _pickedContentType,
        ),
      );
      auth.updateCurrentUser(updated);
      if (!mounted) return;
      AppSnackbars.success(context, 'Your profile has been updated.');
      navigator.pop();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _initials {
    final a = _firstName.text.trim().isNotEmpty
        ? _firstName.text.trim()[0]
        : '';
    final b = _lastName.text.trim().isNotEmpty ? _lastName.text.trim()[0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(child: _buildBody(Theme.of(context))),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(TravleTokens.space24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUnfocus,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ProfileAvatar(
                            base64Image:
                                _pickedImageBase64 ?? _currentImageBase64,
                            radius: 44,
                            initials: _initials,
                          ),
                          const SizedBox(height: TravleTokens.space12),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pickImage,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Change photo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TravleTokens.space24),
                    Text(
                      'Personal information',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _firstName,
                      label: 'First name',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.required(v, field: 'First name'),
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _lastName,
                      label: 'Last name',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.required(v, field: 'Last name'),
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _username,
                      label: 'Username',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.minLength(v, 3, field: 'Username'),
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _email,
                      label: 'Email',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _phone,
                      label: 'Phone (optional)',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: TravleTokens.space24),
                    Text('Location', style: theme.textTheme.titleMedium),
                    const SizedBox(height: TravleTokens.space4),
                    Text(
                      'Optional — helps tailor your recommendations.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    LocationCascadeField(
                      initialCityId:
                          context.read<AuthProvider>().currentUser?.cityId,
                      isRequired: false,
                      enabled: !_busy,
                      onChanged: (cityId) => _cityId = cityId,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: TravleTokens.space16),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: TravleTokens.space24),
                    ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
