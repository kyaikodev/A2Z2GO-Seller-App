import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  final _earn = TextEditingController();
  final _value = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final l = context.store.loyalty;
    _earn.text = _clean(l.pesoPerPoint);
    _value.text = _clean(l.pesoPerPointValue);
  }

  String _clean(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _earn.dispose();
    _value.dispose();
    super.dispose();
  }

  void _saveRules() {
    final earn = parseMoney(_earn.text);
    final value = parseMoney(_value.text);
    if (earn <= 0 || value <= 0) {
      showMsg(context, 'Both amounts must be above zero.', error: true);
      return;
    }
    context.store.setLoyaltyRules(earn: earn, value: value);
    FocusScope.of(context).unfocus();
    showMsg(context, 'Loyalty rules saved');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final l = store.loyalty;
    final snap = store.snapshot;
    final customers = store.loyaltyCustomers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty points'),
        actions: [
          IconButton(
            tooltip: 'Give points',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => _addPoints(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Outstanding',
                  value: intFmt(snap.pointsOutstanding),
                  icon: Icons.card_giftcard,
                  color: Brand.accent,
                  sub:
                      '≈ ${peso(snap.pointsOutstanding * l.pesoPerPointValue, decimals: false)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Redeemed',
                  value: intFmt(snap.pointsRedeemed),
                  icon: Icons.redeem,
                  color: Brand.good,
                  sub: '${intFmt(snap.pointsEarned)} earned',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reward customers with points'),
                  subtitle: const Text(
                    'Points are earned when an order with the customer’s mobile number is completed',
                  ),
                  value: l.enabled,
                  activeThumbColor: Brand.primary,
                  onChanged: store.setLoyaltyEnabled,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _earn,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Spend to earn 1 point',
                          prefixText: '₱ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _value,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: '1 point is worth',
                          prefixText: '₱ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _saveRules,
                  child: const Text('Save rules'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Customers (${customers.length})',
            child: customers.isEmpty
                ? const Text(
                    'No points yet. Customers show up here once an order with their mobile number is completed, or when you give points by hand.',
                    style: TextStyle(color: Brand.muted, height: 1.4),
                  )
                : Column(
                    children: [
                      for (final c in customers)
                        InfoTile(
                          card: false,
                          leading: CircleAvatar(
                            backgroundColor: Brand.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              (c.name.isEmpty ? '#' : c.name[0]).toUpperCase(),
                              style: const TextStyle(
                                color: Brand.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: c.name.isEmpty ? 'Customer' : c.name,
                          subtitle: prettyPhone(c.phone),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${c.balance} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Brand.primary,
                                ),
                              ),
                              Text(
                                '≈ ${peso(c.balance * l.pesoPerPointValue, decimals: false)}',
                                style: const TextStyle(
                                  color: Brand.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LoyaltyCustomerScreen(phone: c.phone),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPoints(BuildContext context) async {
    final store = context.store;
    final phone = TextEditingController();
    final name = TextEditingController();
    final pts = TextEditingController();
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
                  'Give points',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Customer mobile',
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  validator: (v) => normalizePhone(v ?? '') == null
                      ? 'Enter a valid mobile'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pts,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Points'),
                  validator: (v) => intValidator(v, min: 1),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    final res = store.addCustomerPoints(
                      normalizePhone(phone.text)!,
                      name.text,
                      int.parse(pts.text.trim()),
                      'Manual points',
                    );
                    if (!res.ok) {
                      showMsg(ctx, res.error!, error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    showMsg(context, 'Points added');
                  },
                  child: const Text('Add points'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    phone.dispose();
    name.dispose();
    pts.dispose();
  }
}

class LoyaltyCustomerScreen extends StatelessWidget {
  final String phone;
  const LoyaltyCustomerScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final c = store.loyaltyCustomers.where((e) => e.phone == phone).firstOrNull;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'No points history',
          message: 'This customer has no loyalty activity.',
        ),
      );
    }
    final txns = store.txnsFor(phone);
    final worth = store.loyalty.pesoPerPointValue;

    return Scaffold(
      appBar: AppBar(title: Text(c.name.isEmpty ? 'Customer' : c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SectionCard(
            child: Column(
              children: [
                Text(
                  prettyPhone(c.phone),
                  style: const TextStyle(color: Brand.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  '${c.balance} points',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Brand.primary,
                  ),
                ),
                Text(
                  'worth ${peso(c.balance * worth)}',
                  style: const TextStyle(color: Brand.muted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: c.balance <= 0
                            ? null
                            : () => _points(context, c, redeem: true),
                        child: const Text('Redeem'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _points(context, c, redeem: false),
                        child: const Text('Adjust'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'History',
            child: Column(
              children: [
                for (final t in txns)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(t.type.label),
                    subtitle: Text(
                      '${dateTimeFmt(t.at)}${t.note.isEmpty ? '' : '\n${t.note}'}',
                    ),
                    isThreeLine: t.note.isNotEmpty,
                    trailing: Text(
                      '${t.points > 0 ? '+' : ''}${t.points}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.points >= 0 ? Brand.good : Brand.bad,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _points(
    BuildContext context,
    LoyaltyCustomer c, {
    required bool redeem,
  }) async {
    final store = context.store;
    final pts = TextEditingController();
    final note = TextEditingController();
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  redeem ? 'Redeem points' : 'Adjust points',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  redeem
                      ? 'Available: ${c.balance} points'
                      : 'Use a negative number to remove points, like -20.',
                  style: const TextStyle(color: Brand.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pts,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(redeem ? r'[0-9]' : r'[0-9\-]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Points',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final n = int.tryParse(pts.text.trim());
                    if (n == null) {
                      setSheet(() => error = 'Enter a whole number');
                      return;
                    }
                    final res = redeem
                        ? store.redeemPoints(c, n, note.text.trim())
                        : store.adjustPoints(c, n, note.text.trim());
                    if (!res.ok) {
                      setSheet(() => error = res.error);
                      return;
                    }
                    Navigator.pop(ctx);
                    showMsg(
                      context,
                      redeem ? 'Points redeemed' : 'Points adjusted',
                    );
                  },
                  child: Text(redeem ? 'Redeem' : 'Save adjustment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    pts.dispose();
    note.dispose();
  }
}
