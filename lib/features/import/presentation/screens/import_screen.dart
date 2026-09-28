import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../providers/import_provider.dart';
import 'import_preview_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Bank Statement', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<ImportProvider>(
        builder: (context, importProvider, _) {
          if (importProvider.bankStatement != null && _selectedFilePath != null) {
            return ImportPreviewScreen(
              bankStatement: importProvider.bankStatement!,
              onBack: () => _resetForm(importProvider),
              onConfirm: () => _confirmImport(context, importProvider),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Your Bank Statement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Supported banks:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                        'HBL (Habib Bank Limited)',
                        'Meezan Bank',
                        'MCB (Muslim Commercial Bank)',
                        'Standard Chartered',
                      ].map((bank) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: AppTheme.incomeColor),
                            const SizedBox(width: 8),
                            Text(bank, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                      const Text(
                        'Format: CSV files exported from your bank\'s online portal. The system will auto-detect the format and check for duplicates.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // File Selection
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.upload_file,
                          size: 50,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (importProvider.isProcessing)
                        const Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                            ),
                            SizedBox(height: 16),
                            Text('Processing CSV...'),
                          ],
                        )
                      else ...[
                        Text(
                          _selectedFilePath != null
                              ? _selectedFilePath!.split('/').last
                              : 'No file selected',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
                            onPressed: () => _pickFile(context, importProvider),
                            icon: const Icon(Icons.file_open),
                            label: const Text('Select CSV or PDF'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Display
                if (importProvider.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error, color: AppTheme.expenseColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Import Error',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.expenseColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          importProvider.error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.expenseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickFile(BuildContext context, ImportProvider importProvider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        _selectedFilePath = result.files.first.path;
        final fileExtension = _selectedFilePath!.split('.').last.toLowerCase();

        if (context.mounted) {
          if (fileExtension == 'pdf') {
            // Parse PDF
            await importProvider.parsePdfFile(_selectedFilePath!);
          } else {
            // Parse CSV
            final csvContent = await _readFile(_selectedFilePath!);
            await importProvider.parseCsvFile(csvContent);
          }

          // Check for duplicates
          if (context.mounted && importProvider.bankStatement != null) {
            final existingExpenses = context.read<ExpenseProvider>().expenses;
            await importProvider.checkForDuplicates(existingExpenses);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<String> _readFile(String filePath) async {
    final file = await Future.value(filePath);
    return await Future.value(
      _readFileContent(file),
    );
  }

  String _readFileContent(String filePath) {
    // This is a placeholder - in actual implementation, use dart:io
    throw UnimplementedError('File reading to be implemented');
  }

  void _resetForm(ImportProvider importProvider) {
    setState(() => _selectedFilePath = null);
    importProvider.reset();
  }

  void _confirmImport(BuildContext context, ImportProvider importProvider) {
    // Navigate to confirmation screen or directly import
    importProvider.markImportCompleted();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bank statement imported successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
