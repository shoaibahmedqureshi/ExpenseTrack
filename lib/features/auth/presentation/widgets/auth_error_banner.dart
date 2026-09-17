import 'package:flutter/material.dart';

/// Shared inline banner for auth validation/failure errors — kept lighter
/// than a popup on purpose, since these are things the user can just fix
/// and retry (wrong password, weak password, etc.), unlike a success
/// message the popup in auth_success_dialog.dart is for. Used by both
/// LoginScreen and SignupScreen so the two don't drift into different
/// styles for the same kind of message.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
