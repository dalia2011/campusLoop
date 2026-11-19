import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/theme/app_theme.dart';
import '../state/events_scope.dart';
import '../state/explore_controller.dart';
import 'event_navigation.dart';
import 'search_screen.dart';
import 'widgets/event_widgets.dart';
import 'widgets/filter_widgets.dart';
import 'widgets/results_scroll_view.dart';

/// Explore tab: the feed of upcoming events with search, topic chips and
/// filters (designs 7, 9, 10, 11).
///
/// The [ExploreController] is created here and lives as long as this tab, so
/// opening an event and going back keeps the search text and filters.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExploreController(EventsScope.read(context))..reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResultsScrollView(
          controller: _controller,
          onOpenEvent: (event) =>
              openEvent(context, event, syncedAt: _controller.lastSynced),
          headerBuilder: (context) => [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weekdayName(DateTime.now()).toUpperCase()} · CAMPUSLOOP',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        'Find your next campus moment.',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SearchField(
                      query: _controller.query,
                      onTap: _openSearch,
                      onClear: () => _controller.setQuery('', immediate: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TopicChipRow(
                      selected: _controller.filters.topic,
                      onChanged: (topic) => _controller.setFilters(
                        _controller.filters.copyWith(topic: topic),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilterBar(controller: _controller),
                    ActiveFilterChips(
                      controller: _controller,
                      includeTopic: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a text field but opens the Search screen when tapped.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.query,
    required this.onTap,
    required this.onClear,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: hasQuery
                  ? 'Search events. Current search: $query'
                  : 'Search events or topics',
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.muted),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            hasQuery ? query : 'Search events or topics',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasQuery ? AppColors.ink : AppColors.muted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
