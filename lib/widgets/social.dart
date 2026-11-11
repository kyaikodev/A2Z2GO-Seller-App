import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import 'common.dart';

Color platformColor(SocialPlatform p) => switch (p) {
  SocialPlatform.facebook => const Color(0xFF1877F2),
  SocialPlatform.instagram => const Color(0xFFC13584),
  SocialPlatform.tiktok => const Color(0xFF111111),
  SocialPlatform.youtube => const Color(0xFFE0231C),
  SocialPlatform.shopee => const Color(0xFFEE4D2D),
  SocialPlatform.lazada => const Color(0xFF0F136D),
  SocialPlatform.link => const Color(0xFF6E6E6E),
};

IconData platformIcon(SocialPlatform p) => switch (p) {
  SocialPlatform.facebook => Icons.facebook,
  SocialPlatform.instagram => Icons.camera_alt_outlined,
  SocialPlatform.tiktok => Icons.music_note,
  SocialPlatform.youtube => Icons.play_circle_outline,
  SocialPlatform.shopee || SocialPlatform.lazada => Icons.shopping_bag_outlined,
  SocialPlatform.link => Icons.link,
};

class PlatformBadge extends StatelessWidget {
  final SocialPlatform platform;
  const PlatformBadge(this.platform, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = platformColor(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(platformIcon(platform), size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            platform.label,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a link in the phone's browser or the platform's own app.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  var ok = false;
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok && context.mounted) {
    showMsg(context, 'Could not open that link.', error: true);
  }
}
