import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/event.dart';
import '../../state/explore_controller.dart';
import 'event_widgets.dart';

/// The scrolling list used by BOTH the Explore feed and the search results:
/// header content on top, then (depending on the controller's state) a loading
/// skeleton, an error, "no results", or the event cards with pagination.
///
/// Pull down to refresh. When the user scrolls near the end, the next page
/// loads, so the app never downloads the whole catalog at once.
class ResultsScrollView extends StatefulWidget {
  const ResultsScrollView({
    super.key,
    required this.controller,
    required this.headerBuilder,
    required this.onOpenEvent,
  });

  final ExploreController controller;

  /// Slivers shown above the results. Called again whenever the controller
  /// changes, so chips and counters stay current.
  final List<Widget> Function(BuildContext context) headerBuilder;

  final void Function(Event event) onOpenEvent;

  @override
  State<ResultsScrollView> createState() => _ResultsScrollViewState();
}

class _ResultsScrollViewState extends State<ResultsScrollView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      widget.controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () => c.reload(keepItems: true),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ...widget.headerBuilder(context),
              if (c.refreshError != null && c.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: OfflineBanner(
                      error: c.refreshError!,
                      lastSynced: c.lastSynced,
                      onRetry: () => c.reload(keepItems: true),
                    ),
                  ),
                ),
              ..._body(c),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(ExploreController c) {
    const sidePadding = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    switch (c.status) {
      case ExploreStatus.loading:
        return const [
          SliverPadding(
            padding: sidePadding,
            sliver: SliverToBoxAdapter(child: EventListSkeleton()),
          ),
        ];
      case ExploreStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState.error(c.error!, onRetry: c.reload),
          ),
        ];
      case ExploreStatus.ready:
        if (c.items.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: c.hasCriteria
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: 'Nothing matched',
                      message:
                          'No events match these filters. Try another keyword '
                          'or remove a filter to find more events.',
                      actionLabel: 'Clear filters',
                      onAction: c.clearAll,
                    )
                  : const EmptyState(
                      icon: Icons.event_outlined,
                      title: 'No upcoming events',
                      message:
                          'New events show up here as soon as they are '
                          'published. Check back soon.',
                    ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: sidePadding,
            sliver: SliverList.builder(
              itemCount: c.items.length,
              itemBuilder: (context, index) {
                final event = c.items[index];
                return EventCard(
                  event: event,
                  onTap: () => widget.onOpenEvent(event),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _footer(c)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        ];
    }
  }

  Widget _footer(ExploreController c) {
    if (c.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (c.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            const Expanded(child: Text('Could not load more events.')),
            TextButton(onPressed: c.loadMore, child: const Text('Retry')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
