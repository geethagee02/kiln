import 'firing.dart';
import 'recipe.dart';

class SyncResponse {
  const SyncResponse({
    required this.serverTime,
    required this.applied,
    required this.recipeConflicts,
    required this.firingConflicts,
    required this.recipes,
    required this.firings,
  });

  final DateTime serverTime;
  final int applied;
  final List<Recipe> recipeConflicts;
  final List<Firing> firingConflicts;
  final List<Recipe> recipes;
  final List<Firing> firings;
}

enum SyncPhase { syncing, offline, ready, error }

class SyncSnapshot {
  const SyncSnapshot({
    required this.phase,
    required this.pending,
    this.message,
  });

  final SyncPhase phase;
  final int pending;
  final String? message;

  String get banner {
    final changes = pending == 1 ? 'change' : 'changes';
    return switch (phase) {
      SyncPhase.syncing => 'Syncing with the studio.',
      SyncPhase.offline => pending == 0
          ? 'Offline. Showing the book saved on this phone.'
          : 'Offline. $pending $changes saved on this phone.',
      SyncPhase.error => message ?? 'The studio service did not respond.',
      SyncPhase.ready => pending == 0
          ? ''
          : '$pending $changes ${pending == 1 ? 'is' : 'are'} waiting to sync.',
    };
  }
}
