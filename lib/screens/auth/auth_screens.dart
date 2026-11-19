import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/scope.dart';

/// Picks which sign-in step to show from the current auth state.
class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.auth;
    final (key, step) = auth.needsProfile
        ? ('profile', const ProfileSetupScreen() as Widget)
        : auth.challenge != null
        ? ('otp', const OtpScreen() as Widget)
        : ('phone', const PhoneScreen() as Widget);
    // Steps glide in instead of jumping (and just switch for people who asked
    // their phone to reduce motion).
    final calm = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: calm ? Duration.zero : const Duration(milliseconds: 320),
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: step),
    );
  }
}

/// Shared frame for the three sign-in steps: logo, optional back arrow, and a
/// scrollable body with room for the keyboard.
class _AuthShell extends StatelessWidget {
  final VoidCallback? onBack;
  final List<Widget> children;
  const _AuthShell({this.onBack, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            tooltip: 'Back',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: onBack,
                          )
                        else
                          const LogoTag(height: 36),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.auth.requestOtp(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _AuthShell(
      children: [
        Text('Welcome, seller', style: text.displaySmall),
        const SizedBox(height: 10),
        Text(
          context.auth.isDemoOtp
              ? 'Sign in with your mobile number. This is test mode, so your code '
                    'is shown on the next screen. New here? Your account is created automatically.'
              : 'Sign in with your mobile number. We will text you a code. '
                    'New here? Your account is created automatically.',
          style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 16),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
            LengthLimitingTextInputFormatter(17),
          ],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _send(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Mobile number',
            hintText: '0917 123 4567',
            prefixIcon: const Icon(Icons.phone_iphone),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: _busy ? const _ButtonSpinner() : const Text('Send code'),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: Brand.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your shop data stays on this phone.',
                style: TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
  );
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _tick;
  String? _error;
  bool _busy = false;
  bool _ok = false; // the right code was typed: show the "verified" moment

  /// Shakes the boxes when the code is wrong.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _shake.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.auth;
    // Give the right code a short "verified" moment before moving on. (With a
    // real SMS service this check becomes the server's answer.)
    if (auth.challenge?.code == _code.text.trim()) {
      setState(() => _ok = true);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
    }
    final err = await auth.verifyOtp(_code.text);
    if (!mounted) return;
    // On success the auth state changes and this screen is replaced.
    setState(() {
      _busy = false;
      _error = err;
      if (err != null) {
        _code.clear();
        _ok = false;
      }
    });
    if (err != null) {
      HapticFeedback.heavyImpact();
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
    }
  }

  Future<void> _resend() async {
    final phone = context.auth.challenge?.phone;
    if (phone == null) return;
    final err = await context.auth.requestOtp(phone);
    if (!mounted) return;
    setState(() => _error = err);
    if (err == null) {
      _code.clear();
      showMsg(context, 'New code sent.');
    }
  }

  Widget _boxes() {
    final digits = _code.text;
    return Semantics(
      label: '6-digit code, ${digits.length} entered',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: Stack(
            children: [
              // The real input sits invisibly behind the boxes, so the keyboard,
              // paste and autofill all work as usual.
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _code,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    if (_error != null) setState(() => _error = null);
                    if (v.length == 6) _verify();
                  },
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 6; i++)
                      _CodeBox(
                        char: i < digits.length ? digits[i] : '',
                        active:
                            _focus.hasFocus && i == digits.length.clamp(0, 5),
                        error: _error != null,
                        ok: _ok,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.auth;
    final c = auth.challenge;
    if (c == null) return const SizedBox.shrink();
    final wait = c.resendAt.difference(DateTime.now()).inSeconds;
    final left = c.expiresAt.difference(DateTime.now());
    final expired = left.isNegative;
    final mins = left.inMinutes;
    final secs = left.inSeconds % 60;
    final text = Theme.of(context).textTheme;

    return _AuthShell(
      onBack: auth.cancelChallenge,
      children: [
        Text('Enter your code', style: text.displaySmall),
        const SizedBox(height: 10),
        Text(
          'We sent a 6-digit code to ${prettyPhone(c.phone)}.',
          style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 16),
        ),
        const SizedBox(height: 20),
        if (auth.isDemoOtp) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Brand.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(Rd.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test mode: no SMS is sent yet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    const Text('Your code is'),
                    SelectableText(
                      c.code,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _code.text = c.code;
                        _verify();
                      },
                      child: const Text('Fill in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _boxes(),
        AnimatedSize(
          duration: Motion.quick,
          child: _ok
              ? const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: Brand.good),
                      SizedBox(width: 6),
                      Text(
                        'Code verified',
                        style: TextStyle(
                          color: Brand.good,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Brand.bad),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Brand.bad, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          expired
              ? 'This code has expired.'
              : 'Code expires in $mins:${secs.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: expired ? Brand.bad : Brand.muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy || expired ? null : _verify,
          child: _busy
              ? const _ButtonSpinner()
              : const Text('Verify and continue'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: wait > 0 ? null : _resend,
          child: Text(wait > 0 ? 'Resend code in ${wait}s' : 'Resend code'),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String char;
  final bool active;
  final bool error;
  final bool ok;
  const _CodeBox({
    required this.char,
    required this.active,
    required this.error,
    this.ok = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = ok
        ? Brand.good
        : error
        ? Brand.bad
        : active
        ? Brand.primary
        : char.isNotEmpty
        ? Brand.navy.withValues(alpha: 0.35)
        : Brand.line;
    return AnimatedContainer(
      duration: Motion.quick,
      curve: Motion.curve,
      width: 46,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Rd.md),
        border: Border.all(color: border, width: active ? 2 : 1.2),
      ),
      child: AnimatedSwitcher(
        duration: Motion.quick,
        transitionBuilder: (c, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: c),
        ),
        child: Text(
          char,
          key: ValueKey(char),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ok ? Brand.good : Brand.navy,
          ),
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    // The shop gets a default name; it can be renamed later under Me.
    await context.auth.completeProfile(
      ownerName: name,
      storeName: "${name.split(' ').first}'s Shop",
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.auth;
    final text = Theme.of(context).textTheme;
    return _AuthShell(
      onBack: auth.cancelChallenge,
      children: [
        Text('What is your name?', style: text.displaySmall),
        const SizedBox(height: 10),
        Text(
          'Number verified: ${prettyPhone(auth.pendingPhone ?? '')}. '
          'You can rename your shop anytime under Me.',
          style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 16),
        ),
        const SizedBox(height: 28),
        Form(
          key: _form,
          child: TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => requiredText(v, 'Your name'),
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
