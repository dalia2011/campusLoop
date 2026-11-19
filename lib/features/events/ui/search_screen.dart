import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/event_filters.dart';
import '../state/explore_controller.dart';
import 'event_navigation.dart';
import 'widgets/event_widgets.dart';
import 'widgets/filter_widgets.dart';
import 'widgets/results_scroll_view.dart';

/// Search (designs 8 and 9): a text field with recent searches and suggested
/// topics while empty, then live results once the user types.
///
/// Shares the Explore tab's controller, so whatever is searched here is still
/// applied when the user goes back to the feed. Results update 300 ms after
/// the last keystroke (debounce lives in the controller).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.controller});

  final ExploreController controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.query,
  );

  ExploreController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncTextWithController);
  }

  // "Clear filters" on the empty state also clears the search text, so the
  // field has to follow.
  void _syncTextWithController() {
    if (_controller.query.isEmpty && _text.text.isNotEmpty) _text.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextWithController);
    _text.dispose();
    super.dispose();
  }

  void _searchFor(String term) {
    _text.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _controller.setQuery(term, immediate: true);
    _controller.commitSearch(term);
  }

  void _clear() {
    _text.clear();
    _controller.setQuery('', immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _controller.commitSearch(_controller.query);
                      Navigator.of(context).pop();
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _controller.setQuery,
                      onSubmitted: (value) {
                        _controller.setQuery(value, immediate: true);
                        _controller.commitSearch(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search events or topics',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: ListenableBuilder(
                          listenable: _text,
                          builder: (context, _) => _text.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close),
                                  onPressed: _clear,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (!_controller.hasCriteria) {
                    return _Suggestions(
                      controller: _controller,
                      onSearchAgain: _searchFor,
                    );
                  }
                  return ResultsScrollView(
                    controller: _controller,
                    onOpenEvent: (event) {
                      _controller.commitSearch(_controller.query);
                      openEvent(
                        context,
                        event,
                        syncedAt: _controller.lastSynced,
                      );
                    },
                    headerBuilder: (context) => [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FilterBar(
                                controller: _controller,
                                title: _resultsTitle(_controller),
                              ),
                              ActiveFilterChips(controller: _controller),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _resultsTitle(ExploreController c) {
    if (c.status != ExploreStatus.ready) return 'Results';
    final n = c.items.length;
    final plus = c.hasMore ? '+' : '';
    return '$n$plus ${n == 1 && !c.hasMore ? 'event' : 'events'} found';
  }
}

/// What the Search screen shows before anything is typed.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.controller, required this.onSearchAgain});

  final ExploreController controller;
  final void Function(String term) onSearchAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final heading = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final recents = controller.recentSearches;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Recent searches', style: heading),
              ),
            ),
            if (recents.isNotEmpty)
              TextButton(
                onPressed: controller.clearRecents,
                child: const Text('Clear'),
              ),
          ],
        ),
        if (recents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'Your recent searches will show up here.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
        for (final term in recents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: const Icon(Icons.history),
            title: Text(term),
            subtitle: const Text('Search again'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSearchAgain(term),
          ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text('Suggested topics', style: heading),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final topic in kTopics)
              TopicChip(
                label: topicLabel(topic),
                selected: false,
                onSelected: () => controller.setFilters(
                  controller.filters.copyWith(topic: topic),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
