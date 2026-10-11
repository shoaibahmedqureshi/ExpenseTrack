import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/currency_totals.dart';
import '../current_user_id.dart';
import '../../domain/entities/influencer_revenue.dart';
import '../providers/influencer_provider.dart';

class RevenueDetailsScreen extends StatefulWidget {
  final String influencerCode;

  /// Defaults to the signed-in user; tests pass one in.
  final String? userId;

  const RevenueDetailsScreen({
    Key? key,
    required this.influencerCode,
    this.userId,
  }) : super(key: key);

  @override
  State<RevenueDetailsScreen> createState() => _RevenueDetailsScreenState();
}

class _RevenueDetailsScreenState extends State<RevenueDetailsScreen> {
  late String userId;

  @override
  void initState() {
    super.initState();
    userId = widget.userId ?? currentUserId();
    // Not synchronously: the provider notifies listeners, which must not happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCodeRevenues();
    });
  }

  void _loadCodeRevenues() {
    final influencerProvider =
        Provider.of<InfluencerProvider>(context, listen: false);
    influencerProvider.loadCodeRevenues(userId, widget.influencerCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.influencerCode} Revenue'),
        elevation: 0,
      ),
      body: Consumer<InfluencerProvider>(
        builder: (context, influencerProvider, _) {
          if (influencerProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (influencerProvider.error != null) {
            return _buildErrorWidget(influencerProvider.error!);
          }

          final revenues = influencerProvider.revenues;
          if (revenues.isEmpty) {
            return _buildEmptyState();
          }

          // Calculate metrics
          final totals = sumByCurrency(revenues);
          final averages = averageByCurrency(totals, countByCurrency(revenues));
          final planCounts = <String, int>{};
          for (var revenue in revenues) {
            planCounts[revenue.subscriptionPlan] =
                (planCounts[revenue.subscriptionPlan] ?? 0) + 1;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Summary section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
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
                              'Total Revenue',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            for (final line in formatTotals(totals))
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  line,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge,
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Conversions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    Text(
                                      '${revenues.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Avg per Conversion',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    for (final line in formatTotals(averages))
                                      Text(
                                        line,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Subscription plans breakdown
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conversions by Plan',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            ...planCounts.entries.map((e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(e.key)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${e.value}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Transactions list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: revenues.length,
                  itemBuilder: (context, index) {
                    final revenue = revenues[index];
                    return _buildTransactionTile(context, revenue);
                  },
                ),

                const SizedBox(height: 16),

                // Export button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showExportDialog(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export Data'),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, InfluencerRevenue revenue) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(revenue.subscriptionPlan),
        subtitle: Text(
          revenue.transactionDate.toString().split(' ')[0],
        ),
        trailing: Text(
          formatMoney(revenue.revenueAmount, normalizeCurrency(revenue.currency)),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Export revenue data as CSV?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final influencerProvider =
                  Provider.of<InfluencerProvider>(context, listen: false);

              // For now, just show a snackbar
              // In full implementation, would generate and share CSV
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Data Available',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No revenue data found for this code',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
