import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../state/events_scope.dart';
import 'event_navigation.dart';
import 'registration_helpers.dart';
import 'widgets/event_widgets.dart';

/// My Events tab (designs 16 and 17): Registered, Saved and Past.
///
/// Registered holds both places and waitlist spots, Saved holds starred events,
/// Past holds finished or canceled events. Each tab loads on its own and
/// refreshes itself whenever a registration or save changes anywhere in the app.
class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key, this.onBrowse});

  /// Called by the "Explore events" button on an empty list (switches tabs).
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    'My Events',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Registered'),
                  Tab(text: 'Saved'),
                  Tab(text: 'Past'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _MyEventsTab(
                      tab: MyEventsTab.registered,
                      onBrowse: onBrowse,
                    ),
                    _MyEventsTab(tab: MyEventsTab.saved, onBrowse: onBrowse),
                    _MyEventsTab(tab: MyEventsTab.past, onBrowse: onBrowse),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyEventsTab extends StatefulWidget {
  const _MyEventsTab({required this.tab, this.onBrowse});

  final MyEventsTab tab;
  final VoidCallback? onBrowse;

  @override
  State<_MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<_MyEventsTab>
    with AutomaticKeepAliveClientMixin {
  late final EventsRepository _repository;
  List<Event>? _items;
  ApiException? _error; // Nothing to show.
  ApiException? _refreshError; // Showing older data.
  DateTime? _syncedAt;

  // Stops an older, slower request from overwriting a newer answer.
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repository = EventsScope.read(context);
    _repository.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    try {
      final items = await _repository.myEvents(widget.tab);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = items;
        _error = null;
        _refreshError = null;
        _syncedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      final failure = ApiException.from(e);
      setState(() {
        if (_items == null) {
          _error = failure;
        } else {
          _refreshError = failure;
        }
      });
    }
  }

  Future<void> _unsave(Event event) async {
    final before = _items;
    setState(() => _items = [...?before]..removeWhere((e) => e.id == event.id));
    try {
      await _repository.unsaveEvent(event.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = before); // Put it back.
      showToast(context, actionErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    final items = _items;

    if (items == null) {
      if (_error != null) return EmptyState.error(_error!, onRetry: _load);
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [EventListSkeleton(count: 3)],
      );
    }

    final empty = _emptyCopy(widget.tab);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_refreshError != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: OfflineBanner(
                  error: _refreshError!,
                  lastSynced: _syncedAt,
                  onRetry: _load,
                ),
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: empty.icon,
                title: empty.title,
                message: empty.message,
                actionLabel:
                    widget.tab == MyEventsTab.past || widget.onBrowse == null
                    ? null
                    : 'Explore events',
                onAction: widget.onBrowse,
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => _card(items[index]),
              ),
            ),
            if (widget.tab == MyEventsTab.registered &&
                items.any((e) => e.viewerStatus == ViewerStatus.registered))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(child: _nextUpTip(context)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _card(Event event) {
    switch (widget.tab) {
      case MyEventsTab.registered:
        return EventCard(
          event: event,
          onTap: () => openMyEvent(context, event),
          trailing: const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(Icons.chevron_right, color: AppColors.muted),
          ),
        );
      case MyEventsTab.saved:
        return EventCard(
          event: event,
          onTap: () => openEvent(context, event),
          trailing: IconButton(
            tooltip: 'Remove ${event.title} from saved',
            icon: const Icon(Icons.star, color: AppColors.primary),
            onPressed: () => _unsave(event),
          ),
        );
      case MyEventsTab.past:
        return EventCard(event: event, onTap: () => openEvent(context, event));
    }
  }

  Widget _nextUpTip(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Next up',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bring your ticket to the event for a quick check in.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }

  static ({IconData icon, String title, String message}) _emptyCopy(
    MyEventsTab tab,
  ) {
    switch (tab) {
      case MyEventsTab.registered:
        return (
          icon: Icons.confirmation_number_outlined,
          title: 'No upcoming events yet',
          message: 'Register for an event and your ticket will show up here.',
        );
      case MyEventsTab.saved:
        return (
          icon: Icons.star_border,
          title: 'No saved events',
          message: 'Tap the star on an event to save it for later.',
        );
      case MyEventsTab.past:
        return (
          icon: Icons.history,
          title: 'No past events',
          message: 'Events you attended, canceled or saved appear here once they end.',
        );
    }
  }
}
