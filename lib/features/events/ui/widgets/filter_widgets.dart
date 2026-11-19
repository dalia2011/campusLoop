import 'package:flutter/material.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/event_filters.dart';
import '../../state/explore_controller.dart';
import 'event_widgets.dart';

String dateFilterLabel(EventFilters f) {
  switch (f.datePreset) {
    case DatePreset.today:
      return 'Today';
    case DatePreset.thisWeek:
      return 'This week';
    case DatePreset.custom:
      final from = f.customFrom;
      final to = f.customTo;
      if (from == null) return 'Pick dates';
      if (to == null || formatShortDate(from) == formatShortDate(to)) {
        return formatShortDate(from);
      }
      return '${formatShortDate(from)} – ${formatShortDate(to)}';
    case null:
      return 'Any date';
  }
}

/// Opens the filters bottom sheet. Returns the chosen filters, or null if the
/// sheet was dismissed without pressing "Show events".
Future<EventFilters?> showFiltersSheet(
  BuildContext context,
  EventFilters current,
) {
  return showModalBottomSheet<EventFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FiltersSheet(initial: current),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});

  final EventFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  // Edited locally; only applied when the user presses "Show events".
  late EventFilters _draft = widget.initial;

  Future<void> _pickDates() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      initialDateRange:
          _draft.datePreset == DatePreset.custom && _draft.customFrom != null
          ? DateTimeRange(
              start: _draft.customFrom!,
              end: _draft.customTo ?? _draft.customFrom!,
            )
          : null,
    );
    if (range == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        datePreset: DatePreset.custom,
        customFrom: range.start,
        customTo: range.end,
      );
    });
  }

  void _toggleDate(DatePreset preset) {
    setState(() {
      _draft = _draft.datePreset == preset
          ? _draft.copyWith(datePreset: null, customFrom: null, customTo: null)
          : _draft.copyWith(
              datePreset: preset,
              customFrom: null,
              customTo: null,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final heading = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Filter events',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Topic', style: heading),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final topic in kTopics)
                  TopicChip(
                    label: topicLabel(topic),
                    selected: _draft.topic == topic,
                    onSelected: () => setState(() {
                      _draft = _draft.copyWith(
                        topic: _draft.topic == topic ? null : topic,
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Date', style: heading),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TopicChip(
                  label: 'Today',
                  selected: _draft.datePreset == DatePreset.today,
                  onSelected: () => _toggleDate(DatePreset.today),
                ),
                TopicChip(
                  label: 'This week',
                  selected: _draft.datePreset == DatePreset.thisWeek,
                  onSelected: () => _toggleDate(DatePreset.thisWeek),
                ),
                TopicChip(
                  label: _draft.datePreset == DatePreset.custom
                      ? dateFilterLabel(_draft)
                      : 'Pick dates',
                  selected: _draft.datePreset == DatePreset.custom,
                  onSelected: _pickDates,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Availability', style: heading),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _draft.availableOnly,
              onChanged: (v) => setState(() {
                _draft = _draft.copyWith(availableOnly: v ?? false);
              }),
              title: const Text('Spots available'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _draft = EventFilters.none),
                  child: const Text('Clear all'),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    child: const Text('Show events'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Upcoming" title with the Filters button (shows how many are active).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.controller,
    this.title = 'Upcoming',
  });

  final ExploreController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    final count = controller.filters.activeCount;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.tune),
          label: Text(count == 0 ? 'Filters' : 'Filters ($count)'),
          onPressed: () async {
            final result = await showFiltersSheet(context, controller.filters);
            if (result != null) controller.setFilters(result);
          },
        ),
      ],
    );
  }
}

/// Removable chips for the filters that are switched on.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.controller,
    this.includeTopic = true,
  });

  final ExploreController controller;

  /// Explore shows the topic in its own chip row, so it hides it here.
  final bool includeTopic;

  @override
  Widget build(BuildContext context) {
    final f = controller.filters;
    final chips = <Widget>[
      if (includeTopic && f.topic != null)
        _chip(
          topicLabel(f.topic!),
          () => controller.setFilters(f.copyWith(topic: null)),
        ),
      if (f.hasDate)
        _chip(
          dateFilterLabel(f),
          () => controller.setFilters(
            f.copyWith(datePreset: null, customFrom: null, customTo: null),
          ),
        ),
      if (f.availableOnly)
        _chip(
          'Spots available',
          () => controller.setFilters(f.copyWith(availableOnly: false)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(spacing: AppSpacing.xs, children: chips),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => InputChip(
    label: Text(label),
    onDeleted: onRemove,
    deleteButtonTooltipMessage: 'Remove $label filter',
    backgroundColor: AppColors.tint,
    side: BorderSide.none,
    labelStyle: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    ),
    deleteIconColor: AppColors.primary,
  );
}
