import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/subscription_service.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  late SubscriptionService _subscriptionService;
  late String userId;

  @override
  void initState() {
    super.initState();
    _subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    userId = Supabase.instance.client.auth.currentUser?.id ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription & Billing'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current Plan Section
            _buildCurrentPlanSection(),
            const SizedBox(height: 24),

            // Billing History Section
            _buildBillingHistorySection(),
            const SizedBox(height: 24),

            // Payment Methods Section
            _buildPaymentMethodsSection(),
            const SizedBox(height: 24),

            // Family Plan Info (if applicable)
            _buildFamilyPlanSection(),
            const SizedBox(height: 24),

            // Upgrade/Downgrade Section
            _buildPlanOptionsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanSection() {
    final status = _subscriptionService.status;
    final planName = status.isPaid
        ? (status.isMax ? 'MAX Plan' : 'Pro Plan')
        : 'Free Plan';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Plan',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(
            planName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            status.isPaid
                ? 'Active subscription • Renews ${_getNextRenewalDate()}'
                : 'Free plan • Upgrade anytime',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (status.isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCancelDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[900],
                ),
                child: const Text('Cancel Subscription'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Billing History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            title: const Text('September 2026'),
            subtitle: const Text('PKR 999 • Paid'),
            trailing: const Text('Sep 28'),
            onTap: () {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            title: const Text('August 2026'),
            subtitle: const Text('PKR 999 • Paid'),
            trailing: const Text('Aug 28'),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Methods',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () => _showAddPaymentDialog(context),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.credit_card),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visa ending in 4242'),
                      Text(
                        'Expires 12/25',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyPlanSection() {
    final familyProvider = Provider.of<FamilyProvider>(context);

    if (familyProvider.currentFamily == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Family Plan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    familyProvider.currentFamily?.name ?? 'Family Group',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Members: ${familyProvider.familyMembers.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accounts used: ${familyProvider.familyMembers.length} / ${_subscriptionService.status.accountLimit}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOptionsSection() {
    final status = _subscriptionService.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Upgrade Your Plan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        if (!status.isPro) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                title: const Text('Outlay Pro Monthly'),
                subtitle: const Text('PKR 999/month • Unlimited accounts'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _showUpgradeDialog(context, 'proMonthly'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                title: const Text('Outlay Pro Annual'),
                subtitle: const Text('PKR 9,990/year • Save 17% • Unlimited accounts'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _showUpgradeDialog(context, 'proAnnual'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!status.isMax) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.amber[50],
              child: ListTile(
                title: const Text('Outlay Max Monthly'),
                subtitle: const Text(
                  'PKR 1,499/month • Family groups + Advanced features',
                ),
                trailing: const Icon(Icons.star),
                onTap: () => _showUpgradeDialog(context, 'maxMonthly'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.amber[50],
              child: ListTile(
                title: const Text('Outlay Max Annual'),
                subtitle: const Text(
                  'PKR 14,990/year • Save 17% • Family groups + Advanced features',
                ),
                trailing: const Icon(Icons.star),
                onTap: () => _showUpgradeDialog(context, 'maxAnnual'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your subscription will be cancelled at the end of the current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription cancelled'),
                ),
              );
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Plan?'),
        content: Text(
          'Upgrade to $plan? You\'ll be charged immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upgrading to $plan...'),
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: const Text('Payment method management coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getNextRenewalDate() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    return '${nextMonth.month}/${nextMonth.day}/${nextMonth.year}';
  }
}
