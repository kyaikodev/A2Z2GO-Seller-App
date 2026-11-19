import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'buyer_product_screen.dart';

/// The link a buyer would open. A product listed on the shop's website shares
/// that real page; otherwise this is a placeholder address that becomes a real
/// page once the shop server is connected. (The product's own id is unique
/// everywhere; a SKU is only unique inside one shop.)
String shareLink(Product p) => p.sourceUrl.isNotEmpty
    ? p.sourceUrl
    : 'https://a2z2go.com/p/${Uri.encodeComponent(p.id)}';

/// True when [shareLink] points at a real page, not the placeholder.
bool hasRealLink(Product p) => p.sourceUrl.isNotEmpty;

/// The text sent to a chat or post: name, price and link.
String shareMessage(Product p) =>
    '${p.name}\n${peso(p.price, decimals: p.price != p.price.roundToDouble())}\n${shareLink(p)}';

/// Opens [uri] in another app. Returns false when that app is not installed.
Future<bool> _open(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The cover photo as a file the phone's share menu can attach, or null when
/// the product has no photo that lives on this phone or in the app.
Future<XFile?> _coverPhoto(Product p) async {
  final path = p.imagePath;
  if (path == null || isRemoteImage(path)) return null;
  try {
    if (isAssetImage(path)) {
      final bytes = await rootBundle.load(path.substring('asset:'.length));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/share-${p.id}.jpg');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return XFile(file.path);
    }
    return File(path).existsSync() ? XFile(path) : null;
  } catch (_) {
    return null;
  }
}

Future<void> showShareSheet(BuildContext context, Product p) {
  final link = shareLink(p);
  final text = shareMessage(p);
  final encodedText = Uri.encodeComponent(text);
  final encodedLink = Uri.encodeComponent(link);

  Future<void> via(BuildContext ctx, Uri uri, String app) async {
    final ok = await _open(uri);
    if (!ok && ctx.mounted) {
      showMsg(ctx, '$app is not installed. Try "More" instead.', error: true);
    }
  }

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
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShareButton(
                  label: 'Messenger',
                  icon: Icons.forum,
                  color: const Color(0xFF0084FF),
                  onTap: () => via(
                    ctx,
                    Uri.parse('fb-messenger://share/?link=$encodedLink'),
                    'Messenger',
                  ),
                ),
                _ShareButton(
                  label: 'Facebook',
                  icon: Icons.facebook,
                  color: const Color(0xFF1877F2),
                  onTap: () => via(
                    ctx,
                    Uri.parse(
                      'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                    ),
                    'Facebook',
                  ),
                ),
                _ShareButton(
                  label: 'Viber',
                  icon: Icons.call,
                  color: const Color(0xFF7360F2),
                  onTap: () => via(
                    ctx,
                    Uri.parse('viber://forward?text=$encodedText'),
                    'Viber',
                  ),
                ),
                _ShareButton(
                  label: 'WhatsApp',
                  icon: Icons.chat,
                  color: const Color(0xFF25D366),
                  onTap: () => via(
                    ctx,
                    Uri.parse('whatsapp://send?text=$encodedText'),
                    'WhatsApp',
                  ),
                ),
                _ShareButton(
                  label: 'More',
                  icon: Icons.ios_share,
                  color: Brand.navy,
                  onTap: () async {
                    // The phone's own share menu: Instagram, TikTok, Telegram,
                    // email, and so on. The cover photo goes along with it.
                    final photo = await _coverPhoto(p);
                    await SharePlus.instance.share(
                      ShareParams(
                        text: text,
                        subject: p.name,
                        files: photo == null ? null : [photo],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Brand.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: link,
                size: 170,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            if (!hasRealLink(p)) ...[
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
            ],
            const SizedBox(height: 16),
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
            const SizedBox(height: 10),
            TextButton.icon(
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
          ],
        ),
      ),
    ),
  );
}

/// A round brand-coloured button with its name underneath.
class _ShareButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ShareButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Share on $label',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Rd.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12, color: Brand.navy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
