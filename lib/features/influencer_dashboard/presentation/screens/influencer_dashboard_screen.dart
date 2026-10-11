import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../current_user_id.dart';
import '../../domain/entities/revenue_report.dart';
import '../providers/influencer_provider.dart';
import 'revenue_details_screen.dart';

class InfluencerDashboardScreen extends StatefulWidget {
  /// Defaults to the signed-in user; tests pass one in.
  final String? userId;

  const InfluencerDashboardScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<InfluencerDashboardScreen> createState() =>
      _InfluencerDashboardScreenState();
}

class _InfluencerDashboardScreenState extends State<InfluencerDashboardScreen> {
  late String userId;
  int _selectedPeriod = 0; // 0: All, 1: Year, 2: Month

  @override
  void initState() {
    super.initState();
    userId = widget.userId ?? currentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    final influencerProvider =
        Provider.of<InfluencerProvider>(context, listen: false);
    DateTime? startDate;
    DateTime? endDate = DateTime.now();

    if (_selectedPeriod == 1) {
      startDate = DateTime.now().subtract(Duration(days: 365));
    } else if (_selectedPeriod == 2) {
      startDate = DateTime.now().subtract(Duration(days: 30));
    }

    influencerProvider.generateReport(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Influencer Revenue'),
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

          final report = influencerProvider.currentReport;
          if (report == null) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Period selector
                _buildPeriodSelector(),
                const SizedBox(height: 16),

                // Summary cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSummaryCard(
                        title: 'Total Revenue',
                        value:
                            'PKR ${report.totalRevenue.toStringAsFixed(2)}',
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'This Month',
                              value:
                                  'PKR ${report.monthlyRevenue.toStringAsFixed(2)}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'This Year',
                              value:
                                  'PKR ${report.yearlyRevenue.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Conversions',
                              value:
                                  '${report.totalConversions}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Avg per Conversion',
                              value:
                                  'PKR ${report.averageRevenuePerConversion.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Top Influencers
                if (report.revenueByCode.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Top Influencer Codes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: report.revenueByCode.length,
                    itemBuilder: (context, index) {
                      final codeRevenue = report.revenueByCode[index];
                      return _buildCodeListItem(context, codeRevenue);
                    },
                  ),
                ] else
                  _buildNoDataWidget(),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildPeriodButton('All Time', 0),
          const SizedBox(width: 8),
          _buildPeriodButton('This Year', 1),
          const SizedBox(width: 8),
          _buildPeriodButton('This Month', 2),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedPeriod = period;
          });
          _loadDashboardData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? Colors.blue : Colors.grey[200],
          foregroundColor: isSelected ? Colors.white : Colors.black,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeListItem(BuildContext context, CodeRevenue code) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(code.code),
        subtitle: Text('${code.conversions} conversions'),
        // Scales down instead of overflowing the ListTile's fixed height at large text sizes.
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${code.totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Avg: ${code.averageRevenue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RevenueDetailsScreen(
                influencerCode: code.code,
                userId: userId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Revenue Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Track subscriptions with influencer codes to see revenue data',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No revenue data available for the selected period',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
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
            'Error Loading Revenue',
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
