import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/kiln_database.dart';
import 'core/providers.dart';
import 'core/runtime.dart';
import 'core/seed/studio_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final clock = StudioClock();
  final database = await KilnDatabase.openDefault();
  await ensureSeed(database, clock: clock);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
      ],
      child: const KilnApp(),
    ),
  );
}
