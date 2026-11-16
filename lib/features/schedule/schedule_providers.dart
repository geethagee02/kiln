import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models/firing.dart';
import '../../core/providers.dart';

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(ref.watch(clockProvider).now().toLocal());

  void select(DateTime day) => state = dateOnly(day);

  void shiftWeek(int weeks) => state = dateOnly(state.add(Duration(days: 7 * weeks)));
}

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(SelectedDay.new);

final weekFiringsProvider = FutureProvider<List<Firing>>((ref) async {
  ref.watch(revisionProvider);
  final day = ref.watch(selectedDayProvider);
  return ref.watch(firingRepositoryProvider).forWeek(day);
});
