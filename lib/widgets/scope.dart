import 'package:flutter/widgets.dart';

import '../data/auth.dart';
import '../data/store.dart';

/// Gives every screen access to the signed-in seller's data. Screens that call
/// `context.store` rebuild automatically whenever the data changes.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope above this widget');
    return scope!.notifier!;
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope above this widget');
    return scope!.notifier!;
  }
}

extension ScopeX on BuildContext {
  AppStore get store => StoreScope.of(this);
  AuthController get auth => AuthScope.of(this);
}
