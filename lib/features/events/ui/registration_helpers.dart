import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/confirmation_sheet.dart';

/// Text for a failed action (register, cancel, save...). Offline uses the
/// designs' wording: booking actions need a connection.
String actionErrorMessage(Object error) {
  final e = ApiException.from(error);
  if (e.isOffline) {
    return 'You are offline. Booking actions need a connection, so please '
        'retry when you are back online.';
  }
  return e.message;
}

/// Design 19: "Cancel registration?" sheet. True = the user confirmed.
Future<bool> confirmCancelRegistration(BuildContext context) =>
    showConfirmationSheet(
      context,
      title: 'Cancel registration?',
      message:
          'Your place will be offered to the next person on the waitlist. '
          'You can register again if a spot opens.',
      confirmLabel: 'Yes, cancel my place',
      keepLabel: 'Keep my place',
    );

/// Same idea for leaving the waitlist.
Future<bool> confirmLeaveWaitlist(BuildContext context) =>
    showConfirmationSheet(
      context,
      title: 'Leave the waitlist?',
      message:
          'You will lose your place in line. You can join the waitlist again '
          'if the event is still full.',
      confirmLabel: 'Yes, leave waitlist',
      keepLabel: 'Stay on the waitlist',
    );
