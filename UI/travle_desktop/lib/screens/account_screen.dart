import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/user_detail_card.dart';

/// The signed-in user's own account (desktop). Shows the shared [UserDetailCard]
/// over self-service actions — edit profile and change password — filling the gap
/// left by the mobile-only profile screens. Reads the live profile from
/// [AuthProvider.currentUser], so it refreshes right after an edit.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(TravleTokens.space24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(TravleTokens.space24),
                  child: UserDetailCard(user: user),
                ),
              ),
              const SizedBox(height: TravleTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openEdit(context, user),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openChangePassword(context),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Change password'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, UserResponse user) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EditAccountDialog(user: user),
    );
  }

  Future<void> _openChangePassword(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

/// Self profile edit (personal details, photo, and home city). Every field is a
/// partial update; unchanged values are simply re-sent and an omitted photo leaves
/// the stored one untouched. The home city uses a Country → Region → City cascade
/// (all optional), prefilled by resolving the saved city up its region/country
/// chain — mirroring the mobile edit-profile screen.
class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({required this.user});
  final UserResponse user;

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.user.firstName);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _username = TextEditingController(text: widget.user.username);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phoneNumber ?? '');

  late final String? _currentImageBase64 =
      widget.user.profileImageThumbnail ?? widget.user.profileImage;
  String? _pickedImageBase64;
  String? _pickedContentType;

  // Home-city cascade.
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

  String get _initials {
    final a = _firstName.text.trim().isNotEmpty ? _firstName.text.trim()[0] : '';
    final b = _lastName.text.trim().isNotEmpty ? _lastName.text.trim()[0] : '';
    return (a + b).toUpperCase();
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
    try {
      final countries = await countryProvider.get(filter: {'pageSize': 100});
      int? countryId;
      int? regionId;
      int? cityId;
      var regions = <RegionResponse>[];
      var cities = <CityResponse>[];

      if (widget.user.cityId != null) {
        final city = await cityProvider.getById(widget.user.cityId!);
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
    final result =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
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
    setState(() => _busy = true);
    try {
      final updated = await userProvider.updateProfile(
        widget.user.id,
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

  @override
  Widget build(BuildContext context) => PopScope(
        // Closable by Cancel, Escape, or the barrier — but never mid-save, when
        // tearing the form down would strand the request that is already away.
        canPop: !_busy,
        child: _buildDialog(context),
      );

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        TravleTokens.space24,
        TravleTokens.space16,
        TravleTokens.space8,
        0,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Edit profile')),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(width: 460, child: _buildContent(Theme.of(context))),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _loading ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(
                  onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Column(
                children: [
                  ProfileAvatar(
                    base64Image: _pickedImageBase64 ?? _currentImageBase64,
                    radius: 40,
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
            TravleTextField(
              controller: _firstName,
              label: 'First name',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, field: 'First name'),
            ),
            const SizedBox(height: TravleTokens.space16),
            TravleTextField(
              controller: _lastName,
              label: 'Last name',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, field: 'Last name'),
            ),
            const SizedBox(height: TravleTokens.space16),
            TravleTextField(
              controller: _username,
              label: 'Username',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.minLength(v, 3, field: 'Username'),
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
            Text('Home city', style: theme.textTheme.titleSmall),
            const SizedBox(height: TravleTokens.space4),
            Text(
              'Optional — used to tailor recommendations.',
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
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
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

/// Self password change: the current password is re-entered and verified
/// server-side; the new one must be ≥ 8 chars, differ from the current, and match
/// its confirmation.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    setState(() => _busy = true);
    try {
      await userProvider.changePassword(
        UserPasswordChangeRequest(
          currentPassword: _current.text,
          newPassword: _new.text,
          confirmNewPassword: _confirm.text,
        ),
      );
      if (!mounted) return;
      // The change invalidated every session server-side; drop this device's now-dead
      // session immediately (the AuthGate pops this dialog and shows "sign in again").
      await auth.endSessionAfterPasswordChange();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // Closable by Cancel, Escape, or the barrier — but never mid-save, when
        // tearing the form down would strand the request that is already away.
        canPop: !_busy,
        child: _buildDialog(context),
      );

  Widget _buildDialog(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        TravleTokens.space24,
        TravleTokens.space16,
        TravleTokens.space8,
        0,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Change password')),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TravleTextField(
                  controller: _current,
                  label: 'Current password',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.required(v, field: 'Current password'),
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _new,
                  label: 'New password',
                  prefixIcon: Icons.lock_reset,
                  helperText: 'At least 8 characters',
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final tooShort =
                        Validators.password(v, field: 'New password');
                    if (tooShort != null) return tooShort;
                    if (v == _current.text) {
                      return 'New password must differ from the current one';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleTextField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  prefixIcon: Icons.lock_reset,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => Validators.match(v, _new.text),
                ),
                if (_error != null) ...[
                  const SizedBox(height: TravleTokens.space16),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change password'),
        ),
      ],
    );
  }
}
