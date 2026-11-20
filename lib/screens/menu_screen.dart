import 'package:flutter/material.dart';

import 'analytics/analytics_screen.dart';
import 'store/expenses_screen.dart';
import 'store/loyalty_screen.dart';

/// The "Menu" tab (like the website's): the seller tools that are not in the
/// bottom bar.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String hint, Widget page) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(hint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, page),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          item(
            Icons.insights_outlined,
            'Insights',
            'Sales, profit and what sells',
            const AnalyticsScreen(),
          ),
          const SizedBox(height: 10),
          item(
            Icons.payments_outlined,
            'Expenses',
            'What the shop spends',
            const ExpensesScreen(),
          ),
          const SizedBox(height: 10),
          item(
            Icons.card_giftcard_outlined,
            'Loyalty points',
            'Points your buyers earned',
            const LoyaltyScreen(),
          ),
        ],
      ),
    );
  }
}
