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
  List<CountryResponse> _countries = [];
  List<RegionResponse> _regions = [];
  List<CityResponse> _cities = [];
  int? _countryId;
  int? _regionId;
  int? _cityId;
  bool _loadingRegions = false;
  bool _loadingCities = false;

  bool _loading = true;
  String? _loadError;
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
      _currentImageBase64 = user.profileImage;
    }
    _bootstrap();
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

  /// Loads the country list and, if the user already has a home city, resolves it
  /// up the chain (city → region → country) to prefill all three dropdowns.
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final countryProvider = context.read<CountryProvider>();
    final regionProvider = context.read<RegionProvider>();
    final cityProvider = context.read<CityProvider>();
    final user = context.read<AuthProvider>().currentUser;
    try {
      final countries = await countryProvider.get(filter: {'pageSize': 100});
      int? countryId;
      int? regionId;
      int? cityId;
      var regions = <RegionResponse>[];
      var cities = <CityResponse>[];

      if (user?.cityId != null) {
        final city = await cityProvider.getById(user!.cityId!);
        final region = await regionProvider.getById(city.regionId);
        countryId = region.countryId;
        regionId = city.regionId;
        cityId = city.id;
        regions = (await regionProvider.get(
          filter: {'pageSize': 100, 'countryId': countryId},
        )).items;
        cities = (await cityProvider.get(
          filter: {'pageSize': 100, 'regionId': regionId},
        )).items;
      }

      if (!mounted) return;
      setState(() {
        _countries = countries.items;
        _regions = regions;
        _cities = cities;
        _countryId = countryId;
        _regionId = regionId;
        _cityId = cityId;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _onCountryChanged(int? id) async {
    setState(() {
      _countryId = id;
      _regionId = null;
      _cityId = null;
      _regions = [];
      _cities = [];
    });
    if (id == null) return;
    setState(() => _loadingRegions = true);
    try {
      final regions = await context.read<RegionProvider>().get(
        filter: {'pageSize': 100, 'countryId': id},
      );
      if (!mounted) return;
      setState(() {
        _regions = regions.items;
        _loadingRegions = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingRegions = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _onRegionChanged(int? id) async {
    setState(() {
      _regionId = id;
      _cityId = null;
      _cities = [];
    });
    if (id == null) return;
    setState(() => _loadingCities = true);
    try {
      final cities = await context.read<CityProvider>().get(
        filter: {'pageSize': 100, 'regionId': id},
      );
      if (!mounted) return;
      setState(() {
        _cities = cities.items;
        _loadingCities = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
      AppSnackbars.error(context, e.message);
    }
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

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
                      validator: (v) =>
                          Validators.maxLength(v, 20, field: 'Phone number'),
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
                    _buildCountryDropdown(),
                    const SizedBox(height: TravleTokens.space16),
                    _buildRegionDropdown(),
                    const SizedBox(height: TravleTokens.space16),
                    _buildCityDropdown(),
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

  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _countryId,
      decoration: const InputDecoration(
        labelText: 'Country',
        hintText: 'Select a country',
      ),
      items: [
        for (final c in _countries)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
      ],
      onChanged: _busy ? null : _onCountryChanged,
    );
  }

  Widget _buildRegionDropdown() {
    final enabled = _countryId != null && !_loadingRegions && !_busy;
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _regionId,
      decoration: InputDecoration(
        labelText: 'Region',
        hintText: 'Select a region',
        helperText: _countryId == null
            ? 'Select a country first'
            : (_loadingRegions ? 'Loading regions…' : null),
      ),
      items: [
        for (final r in _regions)
          DropdownMenuItem(value: r.id, child: Text(r.name)),
      ],
      onChanged: enabled ? _onRegionChanged : null,
    );
  }

  Widget _buildCityDropdown() {
    final enabled = _regionId != null && !_loadingCities && !_busy;
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _cityId,
      decoration: InputDecoration(
        labelText: 'City',
        hintText: 'Select a city',
        helperText: _regionId == null
            ? 'Select a region first'
            : (_loadingCities ? 'Loading cities…' : null),
      ),
      items: [
        for (final c in _cities)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
      ],
      onChanged: enabled ? (id) => setState(() => _cityId = id) : null,
    );
  }
}
