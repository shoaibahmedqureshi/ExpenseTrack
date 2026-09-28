import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Mock account data for Phase 1a
class MockAccount {
  final String name;
  final String type;
  final double balance;
  final IconData icon;
  final Color accentColor;

  MockAccount({
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.accentColor,
  });
}

class AccountCard extends StatelessWidget {
  final MockAccount account;

  const AccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Account icon + sync indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: account.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  account.icon,
                  size: 12,
                  color: account.accentColor,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.incomeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Account name
          Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          // Account type (secondary)
          Text(
            account.type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // Balance
          Text(
            CurrencyFormatter.format(account.balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: 'Courier',
            ),
          ),
          // Updated time
          Text(
            '2m ago',
            style: const TextStyle(
              fontSize: 7,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
