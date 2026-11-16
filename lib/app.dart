import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/kiln_theme.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'features/recipes/recipe_form_screen.dart';
import 'features/recipes/recipe_list_screen.dart';
import 'features/schedule/firing_form_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/shell/studio_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/schedule',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudioShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/book',
                builder: (context, state) => const RecipeListScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/firings/new',
        builder: (context, state) => const FiringFormScreen(),
      ),
      GoRoute(
        path: '/recipes/new',
        builder: (context, state) => const RecipeFormScreen(),
      ),
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) => RecipeDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => RecipeFormScreen(
              recipeId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class KilnApp extends ConsumerWidget {
  const KilnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kiln',
      debugShowCheckedModeBanner: false,
      theme: KilnTheme.light(),
      darkTheme: KilnTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: scheme.surfaceContainerLow,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ColoredBox(
                color: scheme.surface,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
