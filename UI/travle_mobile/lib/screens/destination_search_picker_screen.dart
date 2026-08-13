import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// A focused, full-screen destination picker built on the same search-autocomplete
/// as the Search tab (`GET /Destinations/suggest`): the user types, debounced
/// suggestions stream in, and tapping one returns it to the caller. Used by the map
/// browse screen to fly to and select a destination. Unlike the Search tab it runs
/// no full search and shows no result cards — its only job is to return a pick
/// (`Navigator.pop` with the chosen [DestinationSuggestion], or null on back).
class DestinationSearchPickerScreen extends StatefulWidget {
  const DestinationSearchPickerScreen({super.key});

  @override
  State<DestinationSearchPickerScreen> createState() =>
      _DestinationSearchPickerScreenState();
}

class _DestinationSearchPickerScreenState
    extends State<DestinationSearchPickerScreen> {
  /// Match the Search tab: a 1-char probe matches nearly everything, so wait for a
  /// second letter, then a pause in typing, before hitting the network.
  static const int _minSuggestChars = 2;
  static const int _suggestDebounceMs = 300;

  final TextEditingController _textController = TextEditingController();

  Timer? _debounce;
  // Bumped on every keystroke so a slow, out-of-order response is discarded.
  int _seq = 0;
  List<DestinationSuggestion> _suggestions = const [];
  bool _loading = false;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  /// Debounced typeahead: every keystroke invalidates older fetches; a term below
  /// the floor clears the panel; a qualifying term shows the spinner immediately and
  /// hits the network after a pause in typing.
  void _onChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    final seq = ++_seq;
    if (term.length < _minSuggestChars) {
      setState(() {
        _term = term;
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _term = term;
      _loading = true; // spinner during the debounce + fetch
    });
    _debounce = Timer(
      const Duration(milliseconds: _suggestDebounceMs),
      () => _fetch(term, seq),
    );
  }

  Future<void> _fetch(String term, int seq) async {
    try {
      final items = await context.read<DestinationProvider>().suggest(term);
      if (!mounted || seq != _seq) return; // a newer keystroke superseded this
      setState(() {
        _suggestions = items;
        _loading = false;
      });
    } on ApiClientException {
      if (!mounted || seq != _seq) return;
      // A typeahead shouldn't shout: drop the suggestions quietly on error.
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
    }
  }

  void _clear() {
    _textController.clear();
    _onChanged('');
  }

  void _pick(DestinationSuggestion suggestion) =>
      Navigator.of(context).pop(suggestion);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search destinations',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_term.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: _clear,
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_term.length < _minSuggestChars) {
      return _Hint(
        icon: Icons.search,
        text: 'Type at least $_minSuggestChars letters to find a destination.',
      );
    }
    if (_loading && _suggestions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suggestions.isEmpty) {
      return const _Hint(
        icon: Icons.location_off_outlined,
        text: 'No matching destinations',
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final suggestion = _suggestions[i];
        final subtitle = [suggestion.cityName, suggestion.categoryName]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' · ');
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(
            suggestion.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _pick(suggestion),
        );
      },
    );
  }
}

/// A centred icon + message shown before typing and when nothing matches.
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space32),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: TravleTokens.space12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
