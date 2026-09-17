import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Popup used for every auth flow's "it worked" message (signup
/// confirmation, password reset sent, etc.) — a one-time, important
/// message the user should consciously acknowledge, unlike a validation
/// error they can just fix and retry, which stays an inline banner.
Future<void> showAuthSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.mark_email_read_outlined,
          color: Colors.green, size: 32),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
