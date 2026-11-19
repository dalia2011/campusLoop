import 'package:flutter/material.dart';

/// Short message at the bottom of the screen (the spec's "toast").
/// Screen readers announce it.
void showToast(BuildContext context, String message) =>
    showToastOn(ScaffoldMessenger.of(context), message);

/// Same, for when the screen that wants to show the toast is about to close:
/// grab `ScaffoldMessenger.of(context)` first, pop, then call this.
void showToastOn(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
