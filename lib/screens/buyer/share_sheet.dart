import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'buyer_product_screen.dart';

/// The link a buyer would open. Placeholder address: it becomes a real page
/// once the shop server is connected.
String shareLink(Product p) =>
    'https://a2z2go.com/p/${Uri.encodeComponent(p.sku.toLowerCase())}';

Future<void> showShareSheet(BuildContext context, Product p) {
  final link = shareLink(p);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              p.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Brand.muted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Brand.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: link,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Brand.warn.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Preview only. This link will work for buyers once your shop is online.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuyerProductScreen(productId: p.id),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview as buyer'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  Navigator.pop(ctx);
                  showMsg(context, 'Link copied');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy link'),
            ),
          ],
        ),
      ),
    ),
  );
}
