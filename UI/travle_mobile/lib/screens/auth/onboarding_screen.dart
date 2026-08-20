import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Post-registration interest picks, shown by the [AuthGate] for a not-yet-onboarded
/// traveler. Two steps: a square image-card grid of categories, then pill tags. Each
/// display is recorded so the backend can enforce the re-prompt cap. Continue submits
/// the picks (onboarded); Skip dismisses for this launch. Completing/skipping clears
/// the gate latch, so no navigation happens here — the gate advances to the shell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 2;

  final PageController _pageController = PageController();

  bool _loading = true;
  bool _submitting = false;
  int _step = 0;
  String? _loadError;
  List<DestinationCategoryResponse> _categories = [];
  List<TagResponse> _tags = [];
  final Set<int> _selectedCategories = {};
  final Set<int> _selectedTags = {};

  /// Category thumbnails decoded once at load (never inside build — constraint §12).
  final Map<int, Uint8List?> _categoryImages = {};

  @override
  void initState() {
    super.initState();
    _registerPrompt();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        _categoryImages
          ..clear()
          ..addEntries(categories.items.map(
              (c) => MapEntry(c.id, ImageCodec.decode(c.imageThumbnail))));
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

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

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
        // A neutral wizard title — each step asks its own question below it.
        title: const Text('Personalize Travle'),
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
        _StepProgress(step: _step, count: _stepCount),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _step = i),
            children: [
              _buildCategoriesStep(theme),
              _buildTagsStep(theme),
            ],
          ),
        ),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildCategoriesStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
              TravleTokens.space16, TravleTokens.space16, TravleTokens.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you interested in?',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: TravleTokens.space4),
              Text(
                'Pick the kinds of places you enjoy — we\'ll tailor your recommendations.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const hPad = TravleTokens.space16;
              const spacing = TravleTokens.space12;
              const cardPad = TravleTokens.space12;
              const titleGap = TravleTokens.space4;
              final cellWidth =
                  (constraints.maxWidth - hPad * 2 - spacing) / 2;
              // Reserve exactly enough height below the square image for the title
              // plus the *fully wrapped* longest description, so every card shows
              // its whole description (no clipping) while the grid stays uniform.
              final textArea =
                  _categoryTextAreaHeight(context, cellWidth - cardPad * 2) +
                      cardPad * 2 +
                      titleGap;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: cellWidth + textArea,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final selected = _selectedCategories.contains(c.id);
                  return SelectableImageCard(
                    title: c.name,
                    description: c.description,
                    imageBytes: _categoryImages[c.id],
                    selected: selected,
                    onTap: () => setState(() => selected
                        ? _selectedCategories.remove(c.id)
                        : _selectedCategories.add(c.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Height for the title (one line) plus the tallest *fully wrapped* description
  /// at [textWidth], so the grid cells can reserve exactly enough room for every
  /// description without clipping. Honors the current text scale.
  double _categoryTextAreaHeight(BuildContext context, double textWidth) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final descStyle = theme.textTheme.bodySmall;

    double measure(String text, TextStyle? style, {int? maxLines}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: maxLines,
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: textWidth);
      return painter.height;
    }

    // Titles wrap up to 2 lines (some category names don't fit one line at this
    // width), so reserve for the tallest title as well as the tallest description.
    var maxTitleHeight = 0.0;
    var maxDescHeight = 0.0;
    for (final c in _categories) {
      final th = measure(c.name, titleStyle, maxLines: 2);
      if (th > maxTitleHeight) maxTitleHeight = th;
      final d = c.description;
      if (d != null && d.isNotEmpty) {
        final h = measure(d, descStyle);
        if (h > maxDescHeight) maxDescHeight = h;
      }
    }
    // Small buffer against sub-pixel rounding so the tallest line never clips.
    return maxTitleHeight + maxDescHeight + 2;
  }

  Widget _buildTagsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Not "favourites" — Favorites is a separate feature (saved
          // destinations/tours), and these are just interest tags.
          Text('Anything more specific?', style: theme.textTheme.titleLarge),
          const SizedBox(height: TravleTokens.space4),
          Text(
            'Add tags to fine-tune what we suggest. Optional — pick as many as you like.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: TravleTokens.space24),
          if (_tags.isEmpty)
            Text('No tags available.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: TravleTokens.space8,
              runSpacing: TravleTokens.space8,
              children: [for (final t in _tags) _buildTagChip(theme, t)],
            ),
        ],
      ),
    );
  }

  /// A pill tag chip. Selected chips get a primary outline + tinted fill so they
  /// read clearly against the mint scaffold — the M3 default (borderless
  /// secondaryContainer fill) blends into the background here.
  Widget _buildTagChip(ThemeData theme, TagResponse t) {
    final scheme = theme.colorScheme;
    final selected = _selectedTags.contains(t.id);
    return FilterChip(
      label: Text(t.name),
      showCheckmark: false,
      selected: selected,
      selectedColor: scheme.primaryContainer,
      side: selected
          ? BorderSide(color: scheme.primary, width: 1.5)
          : null,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (v) => setState(() =>
          v ? _selectedTags.add(t.id) : _selectedTags.remove(t.id)),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isLastStep = _step == _stepCount - 1;
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: _submitting ? null : () => _goToStep(_step - 1),
              child: const Text('Back'),
            ),
          const Spacer(),
          // Skip dismisses onboarding for this launch; the per-display count still
          // increments (initState), so after MaxOnboardingPrompts displays it stops.
          TextButton(
            onPressed: _submitting ? null : _skip,
            child: const Text('Skip'),
          ),
          const SizedBox(width: TravleTokens.space12),
          if (!isLastStep)
            FilledButton(
              onPressed: () => _goToStep(_step + 1),
              child: const Text('Next'),
            )
          else
            FilledButton(
              onPressed: (_submitting || !_hasSelection) ? null : _continue,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
        ],
      ),
    );
  }
}

/// A slim two-segment progress bar with a "Step X of N" caption above the wizard.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
          TravleTokens.space12, TravleTokens.space16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${step + 1} of $count',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: TravleTokens.space8),
          Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: TravleTokens.space8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(TravleTokens.radiusPill),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
