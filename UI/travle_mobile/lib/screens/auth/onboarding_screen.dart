import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Post-registration interest picks (chip grid of categories + tags), shown by
/// the [AuthGate] for a not-yet-onboarded traveler. Each display is recorded so
/// the backend can enforce the re-prompt cap. Continue submits picks (onboarded);
/// Skip dismisses for this launch. Completing/skipping clears the gate latch, so
/// no navigation happens here — the gate advances to the shell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  List<DestinationCategoryResponse> _categories = [];
  List<TagResponse> _tags = [];
  final Set<int> _selectedCategories = {};
  final Set<int> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _registerPrompt();
    _load();
  }

  /// Records this display against the re-prompt cap (non-blocking, best-effort).
  Future<void> _registerPrompt() async {
    try {
      final updated =
          await context.read<UserProvider>().registerOnboardingPrompt();
      if (!mounted) return;
      context.read<AuthProvider>().updateCurrentUser(updated);
    } catch (_) {
      // Non-critical: a failed count just means one more prompt later.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final categoryProvider = context.read<DestinationCategoryProvider>();
    final tagProvider = context.read<TagProvider>();
    try {
      final categories =
          await categoryProvider.get(filter: BaseSearchObject(pageSize: 100));
      final tags = await tagProvider.get(filter: BaseSearchObject(pageSize: 100));
      if (!mounted) return;
      setState(() {
        _categories = categories.items;
        _tags = tags.items;
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

  bool get _hasSelection =>
      _selectedCategories.isNotEmpty || _selectedTags.isNotEmpty;

  Future<void> _continue() async {
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    try {
      final updated = await userProvider.completeOnboarding(
        UserOnboardingRequest(
          categoryIds: _selectedCategories.toList(),
          tagIds: _selectedTags.toList(),
        ),
      );
      auth.finishOnboarding(updated);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbars.error(context, e.message);
    }
  }

  void _skip() => context.read<AuthProvider>().snoozeOnboarding();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What interests you?'),
        automaticallyImplyLeading: false,
      ),
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
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
              const SizedBox(height: TravleTokens.space8),
              TextButton(
                onPressed: _submitting ? null : _skip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(TravleTokens.space16),
            children: [
              Text(
                "Pick a few things you love and we'll tailor your recommendations. You can skip this.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: TravleTokens.space24),
              Text('Categories', style: theme.textTheme.titleMedium),
              const SizedBox(height: TravleTokens.space12),
              Wrap(
                spacing: TravleTokens.space8,
                runSpacing: TravleTokens.space8,
                children: [
                  for (final c in _categories)
                    FilterChip(
                      label: Text(c.name),
                      selected: _selectedCategories.contains(c.id),
                      onSelected: (v) => setState(() => v
                          ? _selectedCategories.add(c.id)
                          : _selectedCategories.remove(c.id)),
                    ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: TravleTokens.space24),
                Text('Tags', style: theme.textTheme.titleMedium),
                const SizedBox(height: TravleTokens.space12),
                Wrap(
                  spacing: TravleTokens.space8,
                  runSpacing: TravleTokens.space8,
                  children: [
                    for (final t in _tags)
                      FilterChip(
                        label: Text(t.name),
                        selected: _selectedTags.contains(t.id),
                        onSelected: (v) => setState(() => v
                            ? _selectedTags.add(t.id)
                            : _selectedTags.remove(t.id)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: Row(
            children: [
              TextButton(
                onPressed: _submitting ? null : _skip,
                child: const Text('Skip'),
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_submitting || !_hasSelection) ? null : _continue,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
