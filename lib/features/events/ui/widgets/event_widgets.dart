import 'package:flutter/material.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/event.dart';
import '../../data/models/event_filters.dart';

IconData topicIcon(String topic) {
  switch (topic) {
    case 'technology':
      return Icons.code;
    case 'arts':
      return Icons.palette_outlined;
    case 'sports':
      return Icons.sports_soccer_outlined;
    case 'volunteering':
      return Icons.volunteer_activism_outlined;
    case 'careers':
      return Icons.work_outline;
    default:
      return Icons.event_outlined;
  }
}

/// The single status label for an event, from the viewer's point of view.
/// The most important fact wins: canceled > ended > your own status > seats.
({String label, IconData icon, BadgeTone tone}) eventStatusInfo(
  Event event,
  DateTime now,
) {
  if (event.isCanceled) {
    return (
      label: 'Canceled',
      icon: Icons.cancel_outlined,
      tone: BadgeTone.danger,
    );
  }
  if (event.viewerStatus == ViewerStatus.checkedIn) {
    return (
      label: 'Checked in',
      icon: Icons.verified_outlined,
      tone: BadgeTone.success,
    );
  }
  if (event.hasEnded(now)) {
    return (
      label: 'Ended',
      icon: Icons.event_busy_outlined,
      tone: BadgeTone.neutral,
    );
  }
  switch (event.viewerStatus) {
    case ViewerStatus.registered:
      return (
        label: 'Registered',
        icon: Icons.check_circle_outline,
        tone: BadgeTone.success,
      );
    case ViewerStatus.waitlisted:
      final position = event.waitlistPosition;
      return (
        label: position == null
            ? 'Waitlisted'
            : 'Waitlisted · Position $position',
        icon: Icons.hourglass_top,
        tone: BadgeTone.warning,
      );
    default:
      break;
  }
  if (event.hasStarted(now)) {
    return (
      label: 'Registration closed',
      icon: Icons.lock_outline,
      tone: BadgeTone.neutral,
    );
  }
  if (event.isFull) {
    return (
      label: 'Full · Waitlist open',
      icon: Icons.people_outline,
      tone: BadgeTone.warning,
    );
  }
  final n = event.remainingSeats;
  return (
    label: '$n ${n == 1 ? 'seat' : 'seats'} left',
    icon: Icons.event_seat_outlined,
    tone: BadgeTone.info,
  );
}

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge(this.event, {super.key});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final info = eventStatusInfo(event, DateTime.now());
    return StatusBadge(label: info.label, icon: info.icon, tone: info.tone);
  }
}

/// Square tile showing the event photo, or a topic icon when there is none.
class EventCover extends StatelessWidget {
  const EventCover(this.event, {super.key, this.size = 64, this.radius = 16});

  final Event event;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    final fallback = Container(
      width: size,
      height: size,
      color: AppColors.tint,
      child: Icon(
        topicIcon(event.topic),
        size: size * 0.45,
        color: AppColors.primary,
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url == null
            ? fallback
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// One row in any event list (Explore, search results, My Events).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.trailing,
  });

  final Event event;
  final VoidCallback onTap;

  /// Optional widget at the right edge, e.g. the save star.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final info = eventStatusInfo(event, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        label:
            '${event.title}. ${formatCardDate(event.startsAt)}. '
            '${event.venue}. ${info.label}.',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventCover(event),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCardDate(event.startsAt),
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.venue,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(
                          label: info.label,
                          icon: info.icon,
                          tone: info.tone,
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable topic pill. The checkmark means the selected state is not
/// shown by colour alone.
class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: true,
      selectedColor: AppColors.tint,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// "All" plus the five topics, as one horizontally scrolling row.
class TopicChipRow extends StatelessWidget {
  const TopicChipRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TopicChip(
            label: 'All',
            selected: selected == null,
            onSelected: () => onChanged(null),
          ),
          for (final topic in kTopics) ...[
            const SizedBox(width: AppSpacing.xs),
            TopicChip(
              label: topicLabel(topic),
              selected: selected == topic,
              onSelected: () => onChanged(topic),
            ),
          ],
        ],
      ),
    );
  }
}

/// One info line on the detail screens: icon, main text, optional second line.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
