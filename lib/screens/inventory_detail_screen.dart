import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';
import '../widgets/add_existing_stock_dialog.dart';

class InventoryDetailScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  const InventoryDetailScreen({super.key, required this.itemId, required this.itemName});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  // Use repository — never call SupplierService directly.
  final _repo = InventoryRepository();

  InventoryDetailModel? _detail;
  bool _isLoading = true;
  String? _error;
  // Separate loading flag so the main UI stays visible during threshold update.
  bool _isUpdatingThreshold = false;

  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final detail = await _repo.getDetail(widget.itemId);
      if (!mounted) return;
      setState(() { _detail = detail; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Threshold update ───────────────────────────────────────────────────────
  // Pattern:
  //  1. Create controller BEFORE showing dialog.
  //  2. Show AlertDialog — dialog builder captures only dialogContext, never
  //     the outer widget context.
  //  3. await showDialog returns the parsed value (or null on cancel).
  //  4. controller.dispose() is called right after await — the dialog is
  //     already gone, so no widget is still listening to the controller.
  //  5. Guard with !mounted before any setState / API call.

  Future<void> _changeThreshold() async {
    final item = _detail?.item;
    if (item == null || _isUpdatingThreshold) return;

    // Controller lives entirely inside _ThresholdDialog's StatefulWidget lifecycle.
    // Flutter disposes it via State.dispose() — never races with keyboard teardown.
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _ThresholdDialog(
        initialValue: item.threshold.toStringAsFixed(0),
      ),
    );

    if (result == null || result < 0 || !mounted) return;

    setState(() => _isUpdatingThreshold = true);

    try {
      await _repo.updateThreshold(widget.itemId, result);

      if (!mounted) return;

      await _fetch();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Threshold updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to update threshold: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingThreshold = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = _detail?.item;
    final history = _detail?.history ?? [];
    final isLow = item != null && item.isLowStock;
    final isOut = item != null && item.isOutOfStock;
    final statusColor = isOut ? Colors.red : isLow ? Colors.orange : _teal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.itemName,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _teal, fontSize: 18)),
        actions: [
          if (_isUpdatingThreshold)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              onPressed: _fetch,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _fetch,
                      icon: const Icon(Icons.refresh), label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white)),
                  ])))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  color: _teal,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Stock header card ───────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [statusColor, statusColor.withValues(alpha: 0.75)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Current Stock',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(isOut ? 'OUT OF STOCK' : isLow ? 'LOW STOCK' : 'NORMAL',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                          ]),
                          const SizedBox(height: 8),
                          Text('${item!.currentStock.toStringAsFixed(0)} ${item.unit}',
                            style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 16),
                          Row(children: [
                            _StatPill(label: 'Threshold', value: '${item.threshold.toStringAsFixed(0)} ${item.unit}'),
                            const SizedBox(width: 12),
                            if (item.lastUpdated != null)
                              _StatPill(label: 'Updated', value: _fmtDate(item.lastUpdated!)),
                          ]),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // ── Low stock warning ──────────────────────────────
                      if (isLow || isOut)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('⚠ Stock Low',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('Order from supplier to replenish stock.',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700)),
                            ])),
                          ]),
                        ),

                      // ── Action Buttons ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AddExistingStockDialog(
                                      preSelectedItem: item,
                                      allItems: [item],
                                      onSaved: _fetch,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add_chart_outlined, size: 18),
                                label: Text('Add Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: _isUpdatingThreshold
                                  ? OutlinedButton.icon(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: _teal),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                      icon: const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
                                      label: Text('Saving...', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _teal)),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _changeThreshold,
                                      style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: _teal),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                      icon: const Icon(Icons.tune, color: _teal, size: 18),
                                      label: Text('Threshold', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _teal)),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Stock history ───────────────────────────────────
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Stock History',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('${history.length} entries',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 12),

                      if (history.isEmpty)
                        Center(child: Padding(padding: const EdgeInsets.all(32),
                          child: Column(children: [
                            Icon(Icons.history, size: 48, color: _teal.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('No stock history yet.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                          ])))
                      else
                        ...history.map((e) => _HistoryTile(entry: e)),

                      const SizedBox(height: 40),
                    ]),
                  )),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Threshold dialog ───────────────────────────────────────────────────────────
// Owns the TextEditingController in initState/dispose so Flutter's widget
// teardown sequence (not manual code) controls when it is disposed.
// This eliminates the '_dependents.isEmpty' assertion entirely.

class _ThresholdDialog extends StatefulWidget {
  final String initialValue;
  const _ThresholdDialog({required this.initialValue});

  @override
  State<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<_ThresholdDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Threshold'),
      content: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'New threshold value',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(_ctrl.text.trim());
            Navigator.pop(context, value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
    ]),
  );
}

class _HistoryTile extends StatelessWidget {
  final StockHistoryEntry entry;
  const _HistoryTile({required this.entry});

  bool get _isIncrease => entry.type == 'increase' || entry.type == 'purchase';
  Color get _color => _isIncrease ? Colors.green : Colors.red;
  IconData get _icon => _isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
  String get _sign => _isIncrease ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(_icon, color: _color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.note.isNotEmpty ? entry.note : _isIncrease ? 'Stock received' : 'Stock dispatched',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(entry.source.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
            const SizedBox(width: 6),
            Text('${entry.date.day}/${entry.date.month}/${entry.date.year}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ])),
        Text('$_sign${entry.quantity.toStringAsFixed(0)}',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _color)),
      ]),
    );
  }
}
