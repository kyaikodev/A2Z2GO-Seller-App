import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';

void showMsg(BuildContext context, String text, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
      duration: const Duration(milliseconds: 2600),
      backgroundColor: error ? Brand.bad : Brand.navy,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? Brand.bad : Brand.primary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Brand.navy,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = Brand.primary,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Brand.navy,
                  ),
                ),
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Brand.tint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Brand.muted),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Brand.muted, height: 1.5),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A photo reference is a file on this phone, or a web address (photos taken
/// from an imported product page, or a picked photo in the web preview).
bool isRemoteImage(String path) =>
    path.startsWith('http') || path.startsWith('blob:');

/// Shows a photo from a file or a web address; [placeholder] on any failure.
Widget photoImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget Function() placeholder,
}) {
  return isRemoteImage(path)
      ? Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Skeleton(width: width, height: height, radius: 0),
          errorBuilder: (_, _, _) => placeholder(),
        )
      : Image.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => placeholder(),
        );
}

/// A fitting icon for products without a photo, chosen from the category.
IconData categoryIcon(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('food') || c.contains('meal') || c.contains('bake')) {
    return Icons.restaurant_outlined;
  }
  if (c.contains('grocer')) return Icons.shopping_basket_outlined;
  if (c.contains('house') || c.contains('clean') || c.contains('home')) {
    return Icons.cleaning_services_outlined;
  }
  if (c.contains('health') || c.contains('care') || c.contains('medic')) {
    return Icons.health_and_safety_outlined;
  }
  if (c.contains('electr') || c.contains('gadget') || c.contains('phone')) {
    return Icons.headphones_outlined;
  }
  if (c.contains('christmas') || c.contains('gift') || c.contains('basket')) {
    return Icons.card_giftcard_outlined;
  }
  return Icons.inventory_2_outlined;
}

/// Square product photo, or a placeholder icon when there is none.
class ProductThumb extends StatelessWidget {
  final String? path;
  final double size;
  final String? category;
  const ProductThumb({super.key, this.path, this.size = 56, this.category});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: size,
      height: size,
      color: Brand.tint,
      child: Icon(
        categoryIcon(category),
        size: size * 0.45,
        color: Brand.muted,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path == null
          ? placeholder()
          : photoImage(
              path!,
              width: size,
              height: size,
              placeholder: placeholder,
            ),
    );
  }
}

/// A tappable list row that grows with the text size (ListTile has a fixed
/// height, which overflows with large fonts when the right side has two lines).
class InfoTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool card;

  const InfoTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.card = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: card ? 14 : 0,
        vertical: card ? 12 : 8,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: Brand.muted, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    final tappable = InkWell(
      borderRadius: card ? BorderRadius.circular(Rd.md) : null,
      onTap: onTap,
      child: row,
    );
    return card ? Card(child: tappable) : tappable;
  }
}

class Pill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const Pill(this.text, this.selected, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(text),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Brand.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Brand.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String? requiredText(String? v, [String what = 'This']) =>
    (v == null || v.trim().isEmpty) ? '$what is required' : null;

String? moneyValidator(
  String? v, {
  bool allowZero = true,
  bool required = true,
}) {
  if (v == null || v.trim().isEmpty) return required ? 'Enter an amount' : null;
  final n = double.tryParse(v.replaceAll(',', ''));
  if (n == null) return 'Numbers only';
  if (n < 0 || (!allowZero && n == 0)) return 'Must be above zero';
  return null;
}

double parseMoney(String s) =>
    double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

String? intValidator(String? v, {int min = 0, bool required = true}) {
  if (v == null || v.trim().isEmpty) return required ? 'Enter a number' : null;
  final n = int.tryParse(v.trim());
  if (n == null) return 'Whole numbers only';
  if (n < min) return 'Must be at least $min';
  return null;
}

/// The A2Z2GO price-tag logo.
class LogoTag extends StatelessWidget {
  final double height;
  const LogoTag({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'A2Z2GO',
      image: true,
      child: Image.asset(
        'assets/brand/a2z_tag.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Quiet pulsing placeholder shown while something is loading. Holds still if
/// the phone asks for reduced motion.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = AnimatedBuilder(
      animation: _c,
      builder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(Brand.tint, const Color(0xFFE2E2E8), _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
    if (widget.width == null && widget.height == null) {
      return SizedBox.expand(child: box);
    }
    return SizedBox(width: widget.width, height: widget.height, child: box);
  }
}

/// Fades and slides its child in, a little later for each [index], so a list
/// appears one item after another. About a quarter of a second; instant if the
/// phone asks for reduced motion.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final bool animate;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _delay = Timer(Duration(milliseconds: 50 * widget.index.clamp(0, 6)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// A form's main button, kept in a bar that rides above the keyboard so it is
/// never hidden while typing.
class FormActionBar extends StatelessWidget {
  final Widget child;
  const FormActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Brand.line)),
          ),
          child: child,
        ),
      ),
    );
  }
}
