import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/studio_types.dart';
import '../core/providers.dart';
import 'kiln_mark.dart';

class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncControllerProvider);
    final snapshot = async.valueOrNull;
    final text = async.hasError
        ? 'The studio book on this phone could not refresh.'
        : snapshot?.banner ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final offline = snapshot?.phase.name == 'offline' || async.hasError;
    return Material(
      color: offline ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.cloud_done_outlined,
              size: 18,
              color: offline ? scheme.onErrorContainer : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: offline ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncAction extends ConsumerWidget {
  const SyncAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncControllerProvider);
    final pending = async.valueOrNull?.pending ?? 0;
    final syncing = async.isLoading;
    return IconButton(
      tooltip: 'Sync',
      onPressed: syncing ? null : () => ref.read(syncControllerProvider.notifier).refresh(),
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: syncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const KilnMark(size: 28),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kiln', style: Theme.of(context).textTheme.titleLarge),
            Text(studioName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

