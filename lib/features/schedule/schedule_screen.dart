import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models/firing.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';
import 'schedule_providers.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final week = ref.watch(weekFiringsProvider);
    final monday = mondayOf(selected);
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    return RefreshIndicator(
      onRefresh: () => ref.read(syncControllerProvider.notifier).refresh(),
      child: week.when(
        skipLoadingOnReload: true,
        loading: () => const _ScheduleMessage(text: 'Opening the board…'),
        error: (error, stack) => const _ScheduleMessage(
          text: 'The schedule on this phone could not be read.',
        ),
        data: (firings) {
          final active = firings.where((firing) => firing.status.isActive).toList();
          final activeIds = active.map((firing) => firing.id).toSet();
          final dayFirings = firings
              .where((firing) => firing.overlapsDay(selected) && !activeIds.contains(firing.id))
              .toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
            children: [
              Text('The board', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Shared firings for $studioName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _WeekSwitcher(monday: monday),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: _DayChip(
                        key: Key('day-${day.weekday}'),
                        day: day,
                        selected: dateOnly(day) == dateOnly(selected),
                        hasFiring: firings.any((firing) => firing.overlapsDay(day)),
                      ),
                    ),
                ],
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _SectionLabel('In the kiln'),
                const SizedBox(height: 8),
                for (final firing in active) ...[
                  _FiringCard(firing: firing),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 12),
              _SectionLabel(weekdayName(selected)),
              const SizedBox(height: 4),
              Text(
                monthDay(selected),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (dayFirings.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nothing else on this day. Book a firing, or check another morning.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final firing in dayFirings) ...[
                  _FiringCard(firing: firing),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _WeekSwitcher extends ConsumerWidget {
  const _WeekSwitcher({required this.monday});

  final DateTime monday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: () => ref.read(selectedDayProvider.notifier).shiftWeek(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            weekRangeLabel(monday),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: () => ref.read(selectedDayProvider.notifier).shiftWeek(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DayChip extends ConsumerWidget {
  const _DayChip({
    super.key,
    required this.day,
    required this.selected,
    required this.hasFiring,
  });

  final DateTime day;
  final bool selected;
  final bool hasFiring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ref.read(selectedDayProvider.notifier).select(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  weekdayShort(day),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: hasFiring
                        ? (selected ? scheme.onPrimary : scheme.secondary)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiringCard extends StatelessWidget {
  const _FiringCard({required this.firing});

  final Firing firing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(firing.title, style: text.titleMedium),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: firing.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${firing.kiln} · Cone ${firing.cone} · ${firing.atmosphere.label}',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${clockLabel(firing.startsAt)} – ${clockLabel(firing.endsAt)} · ${firing.lead}',
              style: text.bodyMedium,
            ),
            if (firing.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(firing.notes, style: text.bodySmall),
            ],
            const SizedBox(height: 12),
            _ShelfMeter(
              fraction: firing.capacity == 0 ? 0 : firing.booked / firing.capacity,
            ),
            const SizedBox(height: 6),
            Text(
              '${firing.booked} of ${firing.capacity} shelves',
              style: text.bodySmall,
            ),
            if (firing.pendingSync) ...[
              const SizedBox(height: 6),
              Text('Not synced yet', style: text.labelMedium?.copyWith(color: scheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShelfMeter extends StatelessWidget {
  const _ShelfMeter({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      label: '${(clamped * 100).round()} percent of the kiln is booked',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: ColoredBox(
              color: scheme.secondaryContainer,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 8,
                  width: constraints.maxWidth * clamped,
                  child: ColoredBox(color: scheme.secondary),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final FiringStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      FiringStatus.firing => (scheme.errorContainer, scheme.onErrorContainer),
      FiringStatus.loading => (scheme.primaryContainer, scheme.onPrimaryContainer),
      FiringStatus.cooling => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      FiringStatus.scheduled => (scheme.surfaceContainerHigh, scheme.onSurface),
      FiringStatus.unloaded => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
    );
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
