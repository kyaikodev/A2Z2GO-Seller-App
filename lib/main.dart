import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/auth.dart';
import 'data/models.dart';
import 'data/storage.dart';
import 'data/store.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/shell.dart';
import 'widgets/scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Shop data lives in files on the phone; the web preview has none, so it
  // keeps using preferences.
  openStorage = () async {
    if (kIsWeb) return null;
    try {
      return await FileStorage.create();
    } catch (_) {
      return null;
    }
  };
  // One place to catch what nothing else caught. Today it only logs; send it
  // to a crash-reporting service here when the app has one.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Unhandled UI error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error');
    return true;
  };
  runApp(const A2Z2GoSellerApp());
}

class A2Z2GoSellerApp extends StatefulWidget {
  const A2Z2GoSellerApp({super.key});

  @override
  State<A2Z2GoSellerApp> createState() => _A2Z2GoSellerAppState();
}

class _A2Z2GoSellerAppState extends State<A2Z2GoSellerApp> {
  Future<AuthController> _auth = AuthController.create();

  void _retry() => setState(() => _auth = AuthController.create());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthController>(
      future: _auth,
      builder: (context, snap) {
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: _StartError(onRetry: _retry),
          );
        }
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: const _Splash(),
          );
        }
        // The scopes sit ABOVE the Navigator so every pushed screen can use them.
        return AuthScope(
          auth: snap.data!,
          child: MaterialApp(
            title: 'A2Z2GO Seller',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            builder: (context, child) => _SessionHost(child: child!),
            home: const _Root(),
          ),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: Brand.primary)),
  );
}

/// Shown when the saved data cannot be opened, instead of spinning forever.
class _StartError extends StatelessWidget {
  final VoidCallback onRetry;
  const _StartError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Brand.muted),
            const SizedBox(height: 14),
            Text(
              'Could not open your shop',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your data is still on this phone. Check that the phone has free space, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Brand.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    switch (context.auth.stage) {
      case AuthStage.loading:
        return const _Splash();
      case AuthStage.signedOut:
        return const AuthFlow();
      case AuthStage.signedIn:
        return const Shell();
    }
  }
}

/// Opens the signed-in seller's saved data and shares it with every screen.
/// Signed out, there is no data and the app shows only the sign-in flow.
class _SessionHost extends StatefulWidget {
  final Widget child;
  const _SessionHost({required this.child});

  @override
  State<_SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<_SessionHost>
    with WidgetsBindingObserver {
  String? _phone;
  AppStore? _store;

  void _sync(SellerAccount? account) {
    if (account?.phone == _phone) return;
    _store?.flush();
    _phone = account?.phone;
    _store = null;
    if (account == null) return;
    final prefs = context.auth.prefs;
    () async {
      return AppStore.open(prefs, account, storage: await openStorage());
    }().then((s) {
      if (mounted && _phone == account.phone) {
        setState(() => _store = s);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Save pending changes as soon as the app leaves the screen, in case the
  /// phone closes it afterwards.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _store?.flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store?.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.auth;
    _sync(auth.stage == AuthStage.signedIn ? auth.current : null);

    if (auth.stage != AuthStage.signedIn) return widget.child;
    final store = _store;
    if (store == null) return const _Splash();
    return StoreScope(
      key: ValueKey(store.account.phone),
      store: store,
      child: widget.child,
    );
  }
}
