import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Admin moderation queue for Curator/Organizer role applications: filter by
/// status, review the applicant's motivation and any supporting document, and
/// approve (grants the role live) or reject with a mandatory reason.
class RoleApplicationsReviewScreen extends StatefulWidget {
  const RoleApplicationsReviewScreen({super.key});

  @override
  State<RoleApplicationsReviewScreen> createState() =>
      _RoleApplicationsReviewScreenState();
}

class _RoleApplicationsReviewScreenState
    extends State<RoleApplicationsReviewScreen> {
  // 0 = Pending, 1 = Approved, 2 = Rejected (matches the backend enum).
  int _statusFilter = 0;
  bool _loading = true;
  String? _error;
  List<RoleApplicationResponse> _items = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<RoleApplicationProvider>().get(
        filter: {'status': _statusFilter, 'pageSize': 50},
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _approve(RoleApplicationResponse app) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Approve application',
      message:
          'Grant the ${app.roleName ?? 'requested'} role to ${app.applicantName ?? app.username ?? 'this user'}? '
          'The role takes effect immediately.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    await _runDecision(app.id, () async {
      await context.read<RoleApplicationProvider>().approve(app.id);
      return 'Application approved — role granted.';
    });
  }

  Future<void> _reject(RoleApplicationResponse app) async {
    final reason = await _promptReason();
    if (reason == null) return;
    await _runDecision(app.id, () async {
      await context.read<RoleApplicationProvider>().reject(app.id, reason);
      return 'Application rejected.';
    });
  }

  Future<void> _runDecision(
    int id,
    Future<String> Function() action,
  ) async {
    setState(() => _acting.add(id));
    try {
      final message = await action();
      if (!mounted) return;
      AppSnackbars.success(context, message);
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Future<String?> _promptReason() {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Reject application'),
              content: TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason (sent to the applicant)',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setLocal(() => errorText = 'A reason is required');
                      return;
                    }
                    Navigator.of(context).pop(text);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _downloadDocument(RoleApplicationResponse app) async {
    setState(() => _acting.add(app.id));
    try {
      final bytes =
          await context.read<RoleApplicationProvider>().documentBytes(app.id);
      final ext = DocumentCodec.extensionForContentType(app.documentContentType);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save supporting document',
        fileName: '${_documentBaseName(app)}$ext',
        bytes: bytes,
      );
      if (path == null) return; // Cancelled.
      // On desktop saveFile may only return the path without writing — ensure it.
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
      if (!mounted) return;
      AppSnackbars.success(context, 'Document saved to $path');
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(app.id));
    }
  }

  /// A human, filesystem-safe base name for a downloaded document — the
  /// applicant's name rather than a raw database id, e.g. `Application_John_Doe`.
  String _documentBaseName(RoleApplicationResponse app) {
    final raw = app.applicantName?.trim().isNotEmpty == true
        ? app.applicantName!
        : (app.username ?? 'applicant');
    final safe = raw
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'Application_${safe.isEmpty ? 'applicant' : safe}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Pending')),
                  ButtonSegment(value: 1, label: Text('Approved')),
                  ButtonSegment(value: 2, label: Text('Rejected')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _statusFilter = selection.first);
                        _load();
                      },
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(Theme.of(context))),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No applications in this view.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (context, i) => _ApplicationCard(
        app: _items[i],
        busy: _acting.contains(_items[i].id),
        onApprove: () => _approve(_items[i]),
        onReject: () => _reject(_items[i]),
        onDownload: () => _downloadDocument(_items[i]),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.app,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onDownload,
  });

  final RoleApplicationResponse app;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDownload;

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.applicantName?.trim().isNotEmpty == true
                            ? app.applicantName!
                            : (app.username ?? 'Applicant'),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (app.username != null)
                        Text(
                          '@${app.username}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(label: Text(app.roleName ?? 'Role')),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Wrap(
              spacing: TravleTokens.space16,
              runSpacing: TravleTokens.space4,
              children: [
                if (app.regionName != null)
                  _MetaChip(icon: Icons.map_outlined, label: app.regionName!),
                _MetaChip(
                  icon: Icons.schedule,
                  label: 'Submitted ${_dateTime(app.createdAt)}',
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            Text('Motivation', style: theme.textTheme.labelLarge),
            const SizedBox(height: TravleTokens.space4),
            Text(app.motivation, style: theme.textTheme.bodyMedium),
            if (app.hasDocument) ...[
              const SizedBox(height: TravleTokens.space12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDownload,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download document'),
                ),
              ),
            ],
            if (!app.isPending) ...[
              const SizedBox(height: TravleTokens.space12),
              _DecisionSummary(app: app),
            ],
            if (app.isPending) ...[
              const SizedBox(height: TravleTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(right: TravleTokens.space16),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({required this.app});
  final RoleApplicationResponse app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approved = app.isApproved;
    final color = approved
        ? theme.extension<TravleColors>()!.success
        : theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(approved ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: color, size: 20),
              const SizedBox(width: TravleTokens.space8),
              Text(
                approved ? 'Approved' : 'Rejected',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              if (app.decidedByUsername != null) ...[
                const SizedBox(width: TravleTokens.space8),
                Text(
                  'by @${app.decidedByUsername}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (app.isRejected &&
              app.rejectionReason != null &&
              app.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: TravleTokens.space4),
            Text('Reason: ${app.rejectionReason!}',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: TravleTokens.space4),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
