import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;

import '../core/theme.dart';
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

/// Forgets any Facebook/TikTok/YouTube login made inside the in-app page, so
/// the next seller on this phone does not inherit it. Safe to call anywhere
/// (it does nothing where there is no web view, such as tests).
Future<void> clearWebSession() async {
  try {
    await WebViewCookieManager().clearCookies();
  } catch (_) {}
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

/// Posts grouped by platform, in the order each platform first appears.
Map<SocialPlatform, List<SocialPost>> groupByPlatform(List<SocialPost> posts) {
  final out = <SocialPlatform, List<SocialPost>>{};
  for (final p in posts) {
    out.putIfAbsent(p.platform, () => []).add(p);
  }
  return out;
}

/// The start of one social's section: its name, how many comments it has, and
/// a line that runs to the edge, so each social is visibly its own block.

/// A round initial for a commenter. Fancy letters and emoji are single
/// characters made of two code units, so take the first real letter or number
/// as a whole; with none, show a plain person icon instead of a broken box.
class CommentAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const CommentAvatar(this.name, {super.key, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final real = RegExp(r'[\p{L}\p{N}]', unicode: true);
    String? letter;
    for (final r in name.runes) {
      final ch = String.fromCharCode(r);
      if (real.hasMatch(ch)) {
        letter = ch.toUpperCase();
        break;
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Brand.tint,
      child: letter == null
          ? Icon(Icons.person_outline, size: radius, color: Brand.muted)
          : Text(
              letter,
              style: TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
              ),
            ),
    );
  }
}
