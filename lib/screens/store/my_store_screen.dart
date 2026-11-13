import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';
import '../../widgets/social.dart' show clearWebSession;
import 'backup.dart';
import 'expenses_screen.dart';
import 'loyalty_screen.dart';

class MyStoreScreen extends StatelessWidget {
  const MyStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final a = store.account;
    final snap = store.snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Brand.primary,
              borderRadius: BorderRadius.circular(Rd.lg),
              boxShadow: Brand.softShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    (a.storeName.isEmpty ? 'S' : a.storeName[0]).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Brand.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.storeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        a.ownerName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        prettyPhone(a.phone),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: () => _editProfile(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _tile(
            context,
            Icons.card_giftcard,
            'Loyalty points',
            '${intFmt(snap.pointsOutstanding)} points outstanding',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
            ),
          ),
          _tile(
            context,
            Icons.receipt_outlined,
            'Expenses',
            '${store.expenses.length} recorded',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
          ),
          // Demo data is only offered on a brand-new shop (or in debug builds),
          // so it can never be mixed into real records.
          if (kDebugMode ||
              (store.products.isEmpty &&
                  store.orders.isEmpty &&
                  store.expenses.isEmpty))
            _tile(
              context,
              Icons.auto_awesome_outlined,
              'Load sample data',
              'Fill an empty shop with example products and orders',
              () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Load sample data?',
                  message: 'Adds about 20 example products, 17 orders from the last 10 days, a return and a few expenses. You can edit or delete any of it. Nothing you already have is removed.',
                  confirmLabel: 'Load it',
                );
                if (!ok || !context.mounted) return;
                final res = store.loadSampleData();
                showMsg(
                  context,
                  res.ok ? 'Sample data added' : res.error!,
                  error: !res.ok,
                );
              },
            ),
          _tile(
            context,
            Icons.cloud_upload_outlined,
            'Backup',
            'Save a copy of your records, or restore one',
            () => showBackupSheet(context),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Account',
              style: TextStyle(
                color: Brand.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Sign out?',
                message: 'Your products, orders and records stay saved on this phone. You can sign in again with your mobile number.',
                confirmLabel: 'Sign out',
              );
              if (ok && context.mounted) {
                final auth = context.auth;
                await clearWebSession();
                await auth.signOut();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.navy,
              side: const BorderSide(color: Brand.line, width: 1.4),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Danger zone',
              style: TextStyle(
                color: Brand.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Erase all shop data?',
                message: 'This deletes every product, order, return, expense and loyalty record. Your account stays. This cannot be undone.',
                confirmLabel: 'Erase everything',
                destructive: true,
              );
              if (ok && context.mounted) {
                store.eraseAllData();
                showMsg(context, 'All store data erased');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Brand.bad,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Erase all shop data'),
          ),
          TextButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete your account?',
                message: 'Your account and all of its data are removed from this phone permanently.',
                confirmLabel: 'Delete account',
                destructive: true,
              );
              if (ok && context.mounted) {
                final auth = context.auth;
                await clearWebSession();
                await auth.deleteAccount();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Brand.bad,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Delete account'),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'A2Z2GO Seller · data is stored on this phone',
              style: TextStyle(color: Brand.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Brand.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Brand.navy),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final store = context.store;
    final auth = context.auth;
    final a = store.account;
    final name = TextEditingController(text: a.ownerName);
    final shop = TextEditingController(text: a.storeName);
    final addr = TextEditingController(text: a.address);
    final form = GlobalKey<FormState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shop profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: shop,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Shop name'),
                  validator: (v) => requiredText(v, 'Shop name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) => requiredText(v, 'Your name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addr,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    store.updateAccount(
                      ownerName: name.text.trim(),
                      storeName: shop.text.trim(),
                      address: addr.text.trim(),
                    );
                    await auth.persistAccount();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) showMsg(context, 'Profile saved');
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    shop.dispose();
    addr.dispose();
  }
}
