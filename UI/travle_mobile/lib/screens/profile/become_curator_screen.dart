import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Lets a traveler apply for the **Curator** role: motivation, the region they'd
/// curate, and an optional supporting document. The target role id is resolved
/// by name from the server's "applicable roles" set (never hardcoded). If the
/// user can't apply right now (a pending application exists, or they already hold
/// the role) the screen explains why instead of showing the form.
class BecomeCuratorScreen extends StatefulWidget {
  const BecomeCuratorScreen({super.key});

  @override
  State<BecomeCuratorScreen> createState() => _BecomeCuratorScreenState();
}

class _BecomeCuratorScreenState extends State<BecomeCuratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivation = TextEditingController();

  List<RegionResponse> _regions = [];
  int? _regionId;

  // Resolved from the server: the Curator role option (null → can't apply now).
  RoleOptionResponse? _curatorOption;
  // The user's latest existing Curator application, if any (drives the status view).
  RoleApplicationResponse? _existingCuratorApp;

  // Optional supporting document.
  String? _docBase64;
  String? _docContentType;
  String? _docFileName;

  bool _loading = true;
  String? _loadError;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _motivation.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final roleApps = context.read<RoleApplicationProvider>();
    final regionProvider = context.read<RegionProvider>();
    try {
      final applicable = await roleApps.applicableRoles();
      final regions = await regionProvider.get(filter: {'pageSize': 100});
      final mine = await roleApps.mine(filter: {'pageSize': 100});

      final curatorApps = mine.items
          .where((a) => a.roleName == AppRole.curator)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final curatorOptions =
          applicable.where((r) => r.name == AppRole.curator).toList();

      if (!mounted) return;
      setState(() {
        _curatorOption =
            curatorOptions.isEmpty ? null : curatorOptions.first;
        _existingCuratorApp = curatorApps.isEmpty ? null : curatorApps.first;
        _regions = regions.items;
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

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (!mounted) return;

    // Trust the bytes, not the extension: sniff the real content type (the server
    // re-checks the magic bytes too).
    final contentType = DocumentCodec.sniffContentType(bytes);
    if (contentType == null) {
      AppSnackbars.error(context, 'Please choose a PDF, JPEG or PNG file.');
      return;
    }
    if (bytes.length > DocumentCodec.maxBytes) {
      AppSnackbars.error(context, 'The document must be 5 MB or smaller.');
      return;
    }
    setState(() {
      _docBase64 = DocumentCodec.encode(bytes);
      _docContentType = contentType;
      _docFileName = file.name;
    });
  }

  void _removeDocument() {
    setState(() {
      _docBase64 = null;
      _docContentType = null;
      _docFileName = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final curator = _curatorOption;
    if (curator == null) return;

    setState(() => _busy = true);
    final roleApps = context.read<RoleApplicationProvider>();
    final navigator = Navigator.of(context);
    try {
      await roleApps.submit(
        RoleApplicationSubmitRequest(
          roleId: curator.id,
          motivation: _motivation.text.trim(),
          regionId: _regionId,
          document: _docBase64,
          documentContentType: _docContentType,
        ),
      );
      if (!mounted) return;
      AppSnackbars.success(
        context,
        'Application submitted — an admin will review it soon.',
      );
      navigator.pop();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a curator')),
      body: SafeArea(child: _buildBody(Theme.of(context))),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _CenteredMessage(
        message: _loadError!,
        isError: true,
        onRetry: _bootstrap,
      );
    }

    // Can't apply right now → explain why (pending review, or already a curator).
    if (_curatorOption == null) {
      final app = _existingCuratorApp;
      if (app != null && app.isPending) {
        return _CenteredMessage(
          icon: Icons.hourglass_top_outlined,
          title: 'Application pending',
          message:
              'Your curator application is awaiting review. You\'ll be notified once an admin decides.',
        );
      }
      return const _CenteredMessage(
        icon: Icons.verified_outlined,
        title: 'You\'re already a curator',
        message: 'You already hold the Curator role.',
      );
    }

    final rejected = _existingCuratorApp?.isRejected == true
        ? _existingCuratorApp
        : null;

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
                    Text(
                      'Curators submit destinations to the platform. Tell us where you\'d like to curate and why.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (rejected != null) ...[
                      const SizedBox(height: TravleTokens.space16),
                      _RejectedBanner(reason: rejected.rejectionReason),
                    ],
                    const SizedBox(height: TravleTokens.space24),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _regionId,
                      decoration: const InputDecoration(
                        labelText: 'Region to curate',
                        hintText: 'Select a region',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: [
                        for (final r in _regions)
                          DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              r.countryName == null
                                  ? r.name
                                  : '${r.name} — ${r.countryName}',
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (id) => setState(() => _regionId = id),
                      validator: (v) =>
                          v == null ? 'Please select a region' : null,
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _motivation,
                      label: 'Motivation',
                      hint: 'Why do you want to become a curator?',
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 1000,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      validator: (v) {
                        final required =
                            Validators.required(v, field: 'Motivation');
                        if (required != null) return required;
                        return Validators.maxLength(v, 1000,
                            field: 'Motivation');
                      },
                    ),
                    const SizedBox(height: TravleTokens.space8),
                    DocumentPickerField(
                      fileName: _docFileName,
                      onPick: _busy ? null : _pickDocument,
                      onRemove: _busy ? null : _removeDocument,
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
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit application'),
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

class _RejectedBanner extends StatelessWidget {
  const _RejectedBanner({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your previous application was rejected.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reason != null && reason!.trim().isNotEmpty) ...[
                  const SizedBox(height: TravleTokens.space4),
                  Text(
                    'Reason: ${reason!}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
                const SizedBox(height: TravleTokens.space4),
                Text(
                  'You can update your details and apply again below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    this.title,
    this.icon,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: TravleTokens.space16),
            ],
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleMedium),
              const SizedBox(height: TravleTokens.space8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
