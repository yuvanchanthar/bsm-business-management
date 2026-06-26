import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_detail_screen.dart';

class InventoryCategoryItemsScreen extends StatefulWidget {
  final String categoryName;

  const InventoryCategoryItemsScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<InventoryCategoryItemsScreen> createState() =>
      _InventoryCategoryItemsScreenState();
}

class _InventoryCategoryItemsScreenState
    extends State<InventoryCategoryItemsScreen> {
  static const _teal = Color(0xFF00897B);

  final _repo = InventoryRepository();
  final _searchCtrl = TextEditingController();

  InventoryCategoryDetail? _detail;
  List<InventoryItemModel> _filteredItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data fetching ───────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _repo.getCategoryDetail(widget.categoryName);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Local filter (no API calls while typing) ────────────────────────────────

  void _applyFilter() {
    if (!mounted || _detail == null) return;
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredItems = _detail!.items.where((item) {
        return item.itemName.toLowerCase().contains(q);
      }).toList();
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.category, color: _teal, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.categoryName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _teal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _fetch,
      color: _teal,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Summary card ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.category, color: _teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            detail.categoryName,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (detail.summary.lowStockCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LOW STOCK',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStatCol(
                          label: 'ITEMS',
                          value: '${detail.summary.totalItems}',
                          color: _teal,
                        ),
                        _SummaryStatCol(
                          label: 'TOTAL STOCK',
                          value:
                              '${detail.summary.totalStock.toStringAsFixed(0)} ${detail.summary.unit}',
                          color: Colors.blueGrey,
                        ),
                        _SummaryStatCol(
                          label: 'LOW STOCK',
                          value: '${detail.summary.lowStockCount}',
                          color: detail.summary.lowStockCount > 0
                              ? Colors.orange.shade700
                              : Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search items in ${widget.categoryName}...',
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: _searchCtrl.clear,
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                    ),
                ]),
              ),
            ),
          ),

          // ── Item list or empty state ─────────────────────────────────────────
          _filteredItems.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64,
                            color: _teal.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No inventory items available',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        if (i.isOdd) return const SizedBox(height: 12);
                        final item = _filteredItems[i ~/ 2];
                        return _CategoryInventoryCard(
                          item: item,
                          onTap: () async {
                            if (item.id == null) return;
                            await Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => InventoryDetailScreen(
                                  itemId: item.id!,
                                  itemName: item.itemName,
                                ),
                              ),
                            );
                            _fetch();
                          },
                        );
                      },
                      childCount: _filteredItems.length * 2 - 1,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Summary stat column ───────────────────────────────────────────────────────

class _SummaryStatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStatCol({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Category item card ────────────────────────────────────────────────────────
// Duplicated (not reused) from _InventoryCard to keep changes isolated.

class _CategoryInventoryCard extends StatelessWidget {
  final InventoryItemModel item;
  final VoidCallback onTap;

  const _CategoryInventoryCard({
    required this.item,
    required this.onTap,
  });

  static const _teal = Color(0xFF00897B);

  Color get _c => item.isOutOfStock
      ? Colors.red
      : item.isLowStock
          ? Colors.orange
          : _teal;

  String get _lbl => item.isOutOfStock
      ? 'OUT OF STOCK'
      : item.isLowStock
          ? 'LOW STOCK'
          : 'NORMAL';

  @override
  Widget build(BuildContext context) {
    final pct = item.threshold > 0
        ? (item.currentStock / (item.threshold * 3)).clamp(0.0, 1.0)
        : 1.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: (item.isLowStock || item.isOutOfStock)
              ? Border.all(color: _c.withValues(alpha: 0.35), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.inventory_2_outlined, color: _c, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Threshold: ${item.threshold.toStringAsFixed(0)} ${item.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lbl,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _c,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Stock',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _c,
                      ),
                    ),
                  ],
                ),
                if (item.isLowStock || item.isOutOfStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Order from supplier',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _c.withValues(alpha: 0.12),
                color: _c,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textHint)),
                Text(
                  'Min: ${item.threshold.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
