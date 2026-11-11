import 'dart:async';

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
    if (auth.needsProfile) return const ProfileSetupScreen();
    if (auth.challenge != null) return const OtpScreen();
    return const PhoneScreen();
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
        const Text(
          'Sign in with your mobile number. We will text you a code. '
          'New here? Your account is created automatically.',
          style: TextStyle(color: Brand.muted, height: 1.5, fontSize: 15),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _tick;
  String? _error;
  bool _busy = false;

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
    final err = await context.auth.verifyOtp(_code.text);
    if (!mounted) return;
    // On success the auth state changes and this screen is replaced.
    setState(() {
      _busy = false;
      _error = err;
      if (err != null) _code.clear();
    });
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
                      active: _focus.hasFocus && i == digits.length.clamp(0, 5),
                      error: _error != null,
                    ),
                ],
              ),
            ),
          ],
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
          style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 15),
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
                        fontSize: 22,
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
                    style: const TextStyle(color: Brand.bad, fontSize: 13.5),
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
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: auth.cancelChallenge,
            child: const Text('Use a different number'),
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String char;
  final bool active;
  final bool error;
  const _CodeBox({
    required this.char,
    required this.active,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final border = error
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
      child: Text(
        char,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
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
          style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 15),
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
