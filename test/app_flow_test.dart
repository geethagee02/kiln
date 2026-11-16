import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiln/app.dart';
import 'package:kiln/core/db/kiln_database.dart';
import 'package:kiln/core/providers.dart';
import 'package:kiln/core/runtime.dart';
import 'package:kiln/core/seed/studio_seed.dart';

import 'support/fake_kiln_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KilnDatabase db;

  setUp(() async {
    db = await KilnDatabase.openMemory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) {
    final list = find
        .byWidgetPredicate(
          (widget) => widget is ScrollView && widget.scrollDirection == Axis.vertical,
        )
        .last;
    final scrollable = find.descendant(of: list, matching: find.byType(Scrollable)).first;
    return tester.scrollUntilVisible(finder, 400, scrollable: scrollable);
  }

  Future<void> pumpKiln(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = StudioClock(() => DateTime(2026, 11, 16, 9));
    await ensureSeed(
      db,
      clock: clock,
      raw: File('assets/seed/studio.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          kilnApiProvider.overrideWithValue(FakeKilnApi(online: false)),
        ],
        child: const KilnApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Monday board shows the members bisque', (tester) async {
    await pumpKiln(tester);
    expect(find.text('Members bisque'), findsOneWidget);
    expect(find.text('In the kiln'.toUpperCase()), findsOneWidget);
  });

  testWidgets('booking a firing lands on the board', (tester) async {
    await pumpKiln(tester);
    await tester.tap(find.text('Book firing'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('firing-title')), 'Test soda');
    await tester.enterText(find.byKey(const Key('firing-lead')), 'Helen Park');
    await tester.tap(find.byKey(const Key('save-firing')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Test soda'));
    expect(find.text('Test soda'), findsOneWidget);
    expect(find.textContaining('Helen Park'), findsOneWidget);
  });

  testWidgets('search opens a recipe and the batch is enforced offline', (tester) async {
    await pumpKiln(tester);
    await tester.tap(find.text('Glaze book'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('recipe-search')), 'shino');
    await tester.pumpAndSettle();
    expect(find.text('First Snow Shino'), findsOneWidget);
    expect(find.text('Night Tenmoku'), findsNothing);

    await tester.enterText(find.byKey(const Key('recipe-search')), 'Night');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Tenmoku'));
    await tester.pumpAndSettle();
    expect(find.text('Red iron oxide'), findsOneWidget);
    expect(find.text('Cobalt carbonate'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recipe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('recipe-name')), 'Widget Test Celadon');
    await tester.enterText(find.byKey(const Key('recipe-author')), 'Priya Shah');
    await scrollTo(tester, find.byKey(const Key('ingredient-name-0')));
    await tester.enterText(find.byKey(const Key('ingredient-name-0')), 'Silica');
    await scrollTo(tester, find.byKey(const Key('ingredient-percent-0')));
    await tester.enterText(find.byKey(const Key('ingredient-percent-0')), '80');
    await tester.tap(find.byKey(const Key('save-recipe')));
    await tester.pumpAndSettle();
    expect(find.textContaining('must total 100%'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ingredient-percent-0')), '100');
    await tester.tap(find.byKey(const Key('save-recipe')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recipe-search')), '');
    await tester.pump();
    await scrollTo(tester, find.text('Widget Test Celadon'));
    expect(find.text('Widget Test Celadon'), findsOneWidget);
    expect(find.text('Not synced yet'), findsWidgets);
  });
}
