import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/services/statement_parser.dart';
import '../providers/import_provider.dart';

/// Shown only when the columns couldn't be recognised: the user points at them.
class ColumnMappingView extends StatefulWidget {
  const ColumnMappingView({super.key, required this.provider});
  final ImportProvider provider;

  @override
  State<ColumnMappingView> createState() => _ColumnMappingViewState();
}

class _ColumnMappingViewState extends State<ColumnMappingView> {
  late int _headerRow = widget.provider.guessedHeaderRow;
  bool _split = false; // separate debit / credit columns
  int? _date, _desc, _amount, _debit, _credit, _type, _balance;
  String? _error;

  List<List<String>> get _rows => widget.provider.mappingRows;
  int get _cols => _rows.fold(0, (m, r) => r.length > m ? r.length : m);

  String _label(int c) {
    final h = _headerRow < _rows.length && c < _rows[_headerRow].length ? _rows[_headerRow][c].trim() : '';
    return h.isEmpty ? 'Column ${c + 1}' : 'Column ${c + 1}: $h';
  }

  Widget _picker(String label, int? value, ValueChanged<int?> onChanged, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: required ? '$label *' : label, border: const OutlineInputBorder(), isDense: true),
        items: [
          if (!required) const DropdownMenuItem<int?>(value: null, child: Text('— none —')),
          for (var c = 0; c < _cols; c++) DropdownMenuItem<int?>(value: c, child: Text(_label(c), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  void _continue() {
    if (_date == null) return setState(() => _error = 'Choose the date column');
    if (_split ? (_debit == null && _credit == null) : _amount == null) {
      return setState(() => _error = _split ? 'Choose the debit and/or credit column' : 'Choose the amount column');
    }
    widget.provider.applyMapping(ColumnMapping(
      headerRow: _headerRow,
      date: _date!,
      description: _desc,
      amount: _split ? null : _amount,
      debit: _split ? _debit : null,
      credit: _split ? _credit : null,
      type: _split ? null : _type,
      balance: _balance,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _rows.take(8).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('We couldn\'t recognise this file\'s columns. Tell us which is which and we\'ll remember nothing: this is only used for this import.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          headingRowHeight: 36,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 36,
          columns: [for (var c = 0; c < _cols; c++) DataColumn(label: Text('${c + 1}', style: const TextStyle(fontWeight: FontWeight.w800)))],
          rows: [
            for (var r = 0; r < preview.length; r++)
              DataRow(
                color: WidgetStatePropertyAll(r == _headerRow ? AppTheme.primaryColor.withOpacity(0.12) : null),
                cells: [
                  for (var c = 0; c < _cols; c++)
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(c < preview[r].length ? preview[r][c] : '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    )),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        value: _headerRow < preview.length ? _headerRow : 0,
        decoration: const InputDecoration(labelText: 'Which row holds the column titles?', border: OutlineInputBorder(), isDense: true),
        items: [for (var r = 0; r < preview.length; r++) DropdownMenuItem(value: r, child: Text('Row ${r + 1}${r == _headerRow ? ' (highlighted)' : ''}'))],
        onChanged: (v) => setState(() => _headerRow = v ?? 0),
      ),
      const SizedBox(height: 12),
      _picker('Date', _date, (v) => setState(() => _date = v), required: true),
      _picker('Description', _desc, (v) => setState(() => _desc = v)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Debit and credit are separate columns'),
        value: _split,
        onChanged: (v) => setState(() => _split = v),
      ),
      if (_split) ...[
        _picker('Debit (money out)', _debit, (v) => setState(() => _debit = v)),
        _picker('Credit (money in)', _credit, (v) => setState(() => _credit = v)),
      ] else ...[
        _picker('Amount', _amount, (v) => setState(() => _amount = v), required: true),
        _picker('Debit/Credit indicator (optional)', _type, (v) => setState(() => _type = v)),
      ],
      _picker('Balance (optional, helps detect direction)', _balance, (v) => setState(() => _balance = v)),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
      FilledButton(onPressed: _continue, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Continue')),
    ]);
  }
}
