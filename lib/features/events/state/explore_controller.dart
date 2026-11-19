import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../data/models/event_filters.dart';

enum ExploreStatus { loading, ready, error }

/// State of the Explore feed: the search text, filters, loaded pages and what
/// to show while loading or when a request fails.
///
/// ONE controller lives as long as the Explore tab, and the Search screen
/// shares it. That is what keeps search and filters when the user goes into an
/// event and comes back (the spec's "back navigation must preserve search
/// and filters").
class ExploreController extends ChangeNotifier {
  ExploreController(
    this._repository, {
    this.debounce = const Duration(milliseconds: 300),
  }) {
    _repository.changes.addListener(_onRepositoryChanged);
  }

  final EventsRepository _repository;

  /// The spec asks for a 300 ms search debounce.
  final Duration debounce;

  String query = '';
  EventFilters filters = EventFilters.none;

  List<Event> items = const [];
  String? nextCursor;
  ExploreStatus status = ExploreStatus.loading;

  /// Set when [status] is error (nothing could be shown at all).
  ApiException? error;

  /// Set when a refresh failed but older results are still on screen. The UI
  /// shows them with "Showing saved information from [time]" and a Retry.
  ApiException? refreshError;

  bool loadingMore = false;
  ApiException? loadMoreError;

  /// When the visible results were last received from the server.
  DateTime? lastSynced;

  /// Most recent first, kept in memory only (cleared when the app closes).
  final List<String> recentSearches = [];

  Timer? _debounceTimer;
  int _requestId = 0;
  bool _disposed = false;

  bool get hasMore => nextCursor != null;
  bool get hasCriteria => query.trim().isNotEmpty || filters.isActive;

  /// Loads the first page (also used for pull to refresh and Retry).
  ///
  /// With [keepItems] the old results stay visible while loading, which is
  /// what pull to refresh wants. Without it, the list is replaced by a
  /// loading skeleton.
  Future<void> reload({bool keepItems = false}) async {
    final id = ++_requestId;
    loadingMore = false;
    loadMoreError = null;
    if (!keepItems) {
      items = const [];
      nextCursor = null;
      status = ExploreStatus.loading;
      error = null;
      refreshError = null;
      _notify();
    }
    try {
      final page = await _repository.listEvents(filters, query: query);
      if (id != _requestId) return; // A newer request replaced this one.
      items = page.items;
      nextCursor = page.nextCursor;
      status = ExploreStatus.ready;
      error = null;
      refreshError = null;
      lastSynced = DateTime.now();
    } catch (e) {
      if (id != _requestId) return;
      final failure = ApiException.from(e);
      if (items.isEmpty) {
        status = ExploreStatus.error;
        error = failure;
      } else {
        refreshError = failure; // Keep what we already have on screen.
      }
    }
    _notify();
  }

  Future<void> loadMore() async {
    if (loadingMore || nextCursor == null || status != ExploreStatus.ready) {
      return;
    }
    final id = _requestId;
    loadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await _repository.listEvents(
        filters,
        query: query,
        cursor: nextCursor,
      );
      if (id != _requestId) return;
      final known = {for (final e in items) e.id};
      items = [...items, ...page.items.where((e) => !known.contains(e.id))];
      nextCursor = page.nextCursor;
    } catch (e) {
      if (id != _requestId) return;
      loadMoreError = ApiException.from(e);
    }
    loadingMore = false;
    _notify();
  }

  /// Called on every keystroke. The search runs 300 ms after the user stops
  /// typing; [immediate] (keyboard "search" or the clear button) skips the wait.
  void setQuery(String text, {bool immediate = false}) {
    if (text == query) return;
    query = text;
    _debounceTimer?.cancel();
    if (immediate) {
      reload();
    } else {
      _debounceTimer = Timer(debounce, reload);
    }
    _notify();
  }

  void setFilters(EventFilters value) {
    if (value == filters) return;
    filters = value;
    _debounceTimer?.cancel();
    reload();
    _notify();
  }

  /// "Clear filters": removes the search text and every filter.
  void clearAll() {
    _debounceTimer?.cancel();
    query = '';
    filters = EventFilters.none;
    reload();
  }

  void commitSearch(String term) {
    final text = term.trim();
    if (text.isEmpty) return;
    recentSearches.removeWhere((r) => r.toLowerCase() == text.toLowerCase());
    recentSearches.insert(0, text);
    if (recentSearches.length > 5) recentSearches.removeLast();
    _notify();
  }

  void removeRecent(String term) {
    recentSearches.remove(term);
    _notify();
  }

  void clearRecents() {
    recentSearches.clear();
    _notify();
  }

  // Someone registered/saved somewhere: refresh seat counts and statuses
  // without flashing a skeleton.
  void _onRepositoryChanged() {
    if (status == ExploreStatus.loading) return;
    reload(keepItems: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _repository.changes.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
