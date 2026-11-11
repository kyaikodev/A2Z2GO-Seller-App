import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final list = [...store.expenses]..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final month = list
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showExpenseSheet(context),
          ),
        ],
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.receipt_outlined,
              title: 'No expenses yet',
              message: 'Record shipping, rent, ads and other costs so your profit is accurate.',
              actionLabel: 'Add an expense',
              onAction: () => showExpenseSheet(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                SectionCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'This month',
                          style: TextStyle(color: Brand.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        peso(month),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Brand.bad,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => confirmDialog(
                        context,
                        title: 'Delete “${e.title}”?',
                        message: 'This changes your profit figures.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      ),
                      onDismissed: (_) {
                        store.deleteExpense(e);
                        showMsg(context, 'Expense deleted');
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Brand.bad,
                          borderRadius: BorderRadius.circular(Rd.md),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        child: ListTile(
                          onTap: () => showExpenseSheet(context, existing: e),
                          title: Text(e.title),
                          subtitle: Text('${e.category} · ${dateFmt(e.date)}'),
                          trailing: Text(
                            peso(e.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap to edit · swipe left to delete',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

Future<void> showExpenseSheet(BuildContext context, {Expense? existing}) async {
  final store = context.store;
  final title = TextEditingController(text: existing?.title ?? '');
  final amount = TextEditingController(
    text: existing == null ? '' : existing.amount.toString(),
  );
  final note = TextEditingController(text: existing?.note ?? '');
  var category = existing?.category ?? expenseCategories.first;
  var date = existing?.date ?? DateTime.now();
  final form = GlobalKey<FormState>();

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
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add expense' : 'Edit expense',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: title,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    hintText: 'e.g. Boxes and tape',
                  ),
                  validator: (v) => requiredText(v, 'A title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                  ),
                  validator: (v) => moneyValidator(v, allowZero: false),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in expenseCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setSheet(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSheet(() => date = d);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(dateFmt(date)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    if (existing == null) {
                      store.addExpense(
                        Expense(
                          id: newId('e'),
                          title: title.text.trim(),
                          category: category,
                          amount: r2(parseMoney(amount.text)),
                          note: note.text.trim(),
                          date: date,
                        ),
                      );
                    } else {
                      existing
                        ..title = title.text.trim()
                        ..category = category
                        ..amount = r2(parseMoney(amount.text))
                        ..note = note.text.trim()
                        ..date = date;
                      store.updateExpense(existing);
                    }
                    Navigator.pop(ctx);
                    showMsg(context, 'Expense saved');
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  title.dispose();
  amount.dispose();
  note.dispose();
}
