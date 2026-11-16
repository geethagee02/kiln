import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/sync_status.dart';

class StudioShell extends StatelessWidget {
  const StudioShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandTitle(),
        actions: const [
          SyncAction(),
          SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(index == 0 ? '/firings/new' : '/recipes/new'),
        icon: const Icon(Icons.add),
        label: Text(index == 0 ? 'Book firing' : 'New recipe'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          navigationShell.goBranch(value, initialLocation: value == index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Glaze book',
          ),
        ],
      ),
    );
  }
}
