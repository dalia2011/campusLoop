import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Makes the [AuthController] available to every screen below it:
///
///   final auth = AuthScope.of(context);
///
/// Widgets that call [of] rebuild when the controller changes.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found above this widget.');
    return scope!.notifier!;
  }

  /// Same controller, but the calling widget does NOT rebuild on changes.
  /// Use inside button handlers.
  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found above this widget.');
    return scope!.notifier!;
  }
}
