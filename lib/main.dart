import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/auth.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/shell.dart';
import 'widgets/scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const A2Z2GoSellerApp());
}

class A2Z2GoSellerApp extends StatefulWidget {
  const A2Z2GoSellerApp({super.key});

  @override
  State<A2Z2GoSellerApp> createState() => _A2Z2GoSellerAppState();
}

class _A2Z2GoSellerAppState extends State<A2Z2GoSellerApp> {
  late final Future<AuthController> _auth = AuthController.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthController>(
      future: _auth,
      builder: (context, snap) {
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

class _SessionHostState extends State<_SessionHost> {
  String? _phone;
  AppStore? _store;

  void _sync(SellerAccount? account) {
    if (account?.phone == _phone) return;
    _store?.flush();
    _phone = account?.phone;
    _store = null;
    if (account == null) return;
    final prefs = context.auth.prefs;
    AppStore.open(prefs, account).then((s) {
      if (mounted && _phone == account.phone) {
        setState(() => _store = s);
      }
    });
  }

  @override
  void dispose() {
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
