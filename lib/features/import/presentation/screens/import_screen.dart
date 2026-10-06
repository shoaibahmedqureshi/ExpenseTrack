import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../providers/import_provider.dart';
import '../widgets/column_mapping_view.dart';
import '../widgets/import_preview_view.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ImportProvider>().reset();
    });
  }

  Future<void> _pick() async {
    final import = context.read<ImportProvider>();
    final expenses = context.read<ExpenseProvider>();
    final categories = context.read<CategoryProvider>();
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      await import.loadFile(path, existing: expenses.expenses, categories: categories.categories);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the file: $e')));
      }
    }
  }

  Future<void> _import() async {
    final import = context.read<ImportProvider>();
    final expenses = context.read<ExpenseProvider>();
    final categories = context.read<CategoryProvider>().categories;
    final budgets = context.read<BudgetProvider>();
    await import.importSelected(expenses, categories);
    await budgets.load();
  }

  @override
  Widget build(BuildContext context) {
    final import = context.watch<ImportProvider>();
    final title = switch (import.stage) {
      ImportStage.preview => 'Review',
      ImportStage.needsMapping => 'Match the columns',
      ImportStage.done => 'Import complete',
      _ => 'Import statement',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (import.stage == ImportStage.preview || import.stage == ImportStage.needsMapping)
            TextButton(
              onPressed: import.reset,
              child: const Text('Start over', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: switch (import.stage) {
        ImportStage.idle => _intro(import),
        ImportStage.parsing => const _Busy('Reading your statement…'),
        ImportStage.importing => const _Busy('Importing transactions…'),
        ImportStage.needsMapping => ColumnMappingView(provider: import),
        ImportStage.preview => ImportPreviewView(provider: import, onImport: _import),
        ImportStage.done => _done(import),
      },
    );
  }

  Widget _intro(ImportProvider import) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.upload_file, size: 56, color: AppTheme.primaryColor.withOpacity(0.8)),
        const SizedBox(height: 16),
        const Text('Import a bank statement', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Choose a CSV you exported from your bank\'s app or internet banking. '
          'You\'ll review every transaction before anything is saved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (import.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(import.error!, style: const TextStyle(color: Colors.red)),
          ),
        FilledButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.folder_open),
          label: const Text('Choose CSV file'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 24),
        const _Note(Icons.lock_outline, 'Private by design',
            'Your statement is read on this device. The file is never uploaded.'),
        const _Note(Icons.table_chart_outlined, 'Works with most banks',
            'Columns for date, description and debit/credit (or a single amount) are detected automatically. If they aren\'t, you can match them yourself.'),
        const _Note(Icons.content_copy, 'No double-counting',
            'Transactions that look like ones you already recorded are unticked for you.'),
        const _Note(Icons.picture_as_pdf_outlined, 'PDF statements',
            'Not supported yet. Most banks offer a CSV or Excel export; if you only have Excel, save it as CSV first.'),
      ],
    );
  }

  Widget _done(ImportProvider import) {
    final r = import.result;
    final ok = r != null && r.failed == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, size: 64, color: ok ? AppTheme.primaryColor : Colors.orange),
          const SizedBox(height: 16),
          Text(
            r == null ? 'Done' : (ok ? 'Imported ${r.imported} transactions' : 'Imported ${r.imported}, ${r.failed} failed'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (r != null && r.failed > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('The ones that were saved are already in your transactions. Import the file again to retry; the saved ones will be skipped as duplicates.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          TextButton(onPressed: import.reset, child: const Text('Import another file')),
        ]),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)),
          const SizedBox(height: 16),
          Text(text),
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
            ]),
          ),
        ]),
      );
}
