import 'package:flutter/material.dart';

import 'analytics/analytics_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'orders/orders_screen.dart';
import 'products/products_screen.dart';
import 'store/my_store_screen.dart';

/// Bottom-bar positions.
class Tabs {
  static const home = 0;
  static const orders = 1;
  static const products = 2;
  static const insights = 3;
  static const me = 4;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = Tabs.home;

  /// Tells the Orders screen which of its tabs to show.
  final _ordersTab = ValueNotifier<int>(0);

  void _go(int i) => setState(() => _index = i);

  void _goOrders(int ordersTab) {
    _ordersTab.value = ordersTab;
    _go(Tabs.orders);
  }

  @override
  void dispose() {
    _ordersTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onGoTab: _go, onGoOrders: _goOrders),
      OrdersScreen(jumpTo: _ordersTab),
      const ProductsScreen(),
      const AnalyticsScreen(),
      const MyStoreScreen(),
    ];
    return PopScope(
      canPop: _index == Tabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(Tabs.home);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}
