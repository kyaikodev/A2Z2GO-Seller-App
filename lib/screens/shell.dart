import 'package:flutter/material.dart';

import 'analytics/analytics_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'menu_screen.dart';
import 'orders/orders_screen.dart';
import 'products/products_screen.dart';
import 'store/my_store_screen.dart';

/// Bottom-bar positions, in the same order as the website's phone bar
/// (Menu, Search, Home, Cart, Me).
class Tabs {
  static const menu = 0;
  static const products = 1;
  static const home = 2;
  static const orders = 3;
  static const me = 4;

  /// Not a tab: it lives in the Menu and opens as its own page.
  static const insights = 99;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = Tabs.home;

  /// Tabs the seller has opened. The others are not built at all, so a save
  /// does not rebuild screens nobody has looked at.
  final _opened = <int>{Tabs.home};

  /// Tells the Orders screen which of its tabs to show.
  final _ordersTab = ValueNotifier<int>(0);

  /// What the header's search bar typed; the Products tab shows it.
  final _productQuery = ValueNotifier<String>('');

  void _go(int i) => setState(() {
    _index = i;
    _opened.add(i);
  });

  /// Like [_go], but also knows the page that is not a tab (Insights).
  void _goTab(int i) {
    if (i == Tabs.insights) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
      );
    } else {
      _go(i);
    }
  }

  void _goOrders(int ordersTab) {
    _ordersTab.value = ordersTab;
    _go(Tabs.orders);
  }

  void _search(String q) {
    _productQuery.value = q;
    _go(Tabs.products);
  }

  @override
  void dispose() {
    _ordersTab.dispose();
    _productQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MenuScreen(),
      ProductsScreen(queryFrom: _productQuery),
      DashboardScreen(
        onGoTab: _goTab,
        onGoOrders: _goOrders,
        onSearch: _search,
      ),
      OrdersScreen(jumpTo: _ordersTab),
      const MyStoreScreen(),
    ];
    return PopScope(
      canPop: _index == Tabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(Tabs.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < pages.length; i++)
              _opened.contains(i) ? pages[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Orders',
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
