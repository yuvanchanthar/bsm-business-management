import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../models/inventory_model.dart';
import '../models/category_model.dart';
import '../repositories/inventory_repository.dart';
import '../services/supplier_service.dart';
import '../services/token_service.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/add_inventory_item_dialog.dart';
import '../widgets/add_existing_stock_dialog.dart';
import '../widgets/edit_inventory_item_dialog.dart';
import '../core/stock_format.dart';
import 'inventory_detail_screen.dart';
import 'inventory_category_items_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});
  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = InventoryRepository();
  SupplierService? _service;

  // Items State
  List<InventoryItemModel> _allItems = [];
  List<InventoryItemModel> _filteredItems = [];
  bool _isLoadingItems = true;
  String? _itemsError;
  String _activeFilter = 'all';
  final _itemSearchCtrl = TextEditingController();

  // Categories State
  List<CategoryModel> _allCategories = [];             // raw CategoryModel for dialogs
  List<InventoryCategorySummary> _allCategorySummaries = [];
  List<InventoryCategorySummary> _filteredCategorySummaries = [];
  bool _isLoadingCategories = true;
  String? _categoriesError;
  final _categorySearchCtrl = TextEditingController();

  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Update FAB
      }
    });
    _itemSearchCtrl.addListener(_applyItemFilters);
    _categorySearchCtrl.addListener(_applyCategoryFilters);
    _initService();
  }

  Future<void> _initService() async {
    final tokenSvc = await TokenService.getInstance();
    _service = SupplierService(tokenSvc);
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    _fetchInventory();
    _fetchCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemSearchCtrl.dispose();
    _categorySearchCtrl.dispose();
    super.dispose();
  }

  // ── Items Logic ────────────────────────────────────────────────────────────

  Future<void> _fetchInventory() async {
    if (!mounted) return;
    setState(() { _isLoadingItems = true; _itemsError = null; });
    try {
      final items = await _repo.getAll();
      if (!mounted) return;
      setState(() { _allItems = items; _isLoadingItems = false; });
      _applyItemFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingItems = false;
      });
    }
  }

  void _applyItemFilters() {
    if (!mounted) return;
    final q = _itemSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchSearch = item.itemName.toLowerCase().contains(q) || (item.category?.toLowerCase().contains(q) ?? false);
        final matchFilter = switch (_activeFilter) {
          'low' => item.isLowStock,
          'out' => item.isOutOfStock,
          _ => true,
        };
        return matchSearch && matchFilter;
      }).toList();
    });
  }

  void _setItemFilter(String f) { setState(() => _activeFilter = f); _applyItemFilters(); }

  // ── Edit / Delete handlers ────────────────────────────────────────────────

  /// Opens the EditInventoryItemDialog pre-filled with [item]'s current values.
  void _showEditDialog(InventoryItemModel item) {
    showDialog(
      context: context,
      builder: (_) => EditInventoryItemDialog(
        item: item,
        categories: _allCategories,
        onSaved: _refreshAll,
      ),
    );
  }

  /// Shows a confirmation dialog then calls DELETE /inventory/:id.
  /// Surfaces backend error messages (e.g. "Cannot delete item with remaining stock").
  Future<void> _confirmDelete(InventoryItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Text('Delete Item',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('"${item.itemName}"?',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Items with remaining stock cannot be deleted.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final id = item.id;
    if (id == null) return;

    try {
      await _repo.deleteItem(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${item.itemName}" deleted.',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          e.toString().replaceAll('Exception: ', ''),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Categories Logic ───────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    if (!mounted || _service == null) return;
    setState(() { _isLoadingCategories = true; _categoriesError = null; });
    try {
      // Fetch raw CategoryModel for dialogs (unchanged)
      final categories = await _service!.getCategories();
      // Fetch enriched summaries for the category cards
      final summaries = await _repo.getInventoryByCategory();
      if (!mounted) return;
      setState(() {
        _allCategories = categories;
        _allCategorySummaries = summaries;
        _isLoadingCategories = false;
      });
      _applyCategoryFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingCategories = false;
      });
    }
  }

  void _applyCategoryFilters() {
    if (!mounted) return;
    final q = _categorySearchCtrl.text.toLowerCase();
    setState(() {
      _filteredCategorySummaries = _allCategorySummaries.where((cat) {
        return cat.name.toLowerCase().contains(q) || cat.description.toLowerCase().contains(q);
      }).toList();
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  void _showActionSheet() {
    final isItems = _tabController.index == 1;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
              if (!isItems)
                _ActionTile(
                  icon: Icons.category,
                  color: _teal,
                  title: 'Add Category',
                  subtitle: 'Create a new product category',
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AddCategoryDialog(onSaved: _refreshAll),
                    );
                  },
                )
              else ... [
                _ActionTile(
                  icon: Icons.inventory_2_outlined,
                  color: _teal,
                  title: 'Add New Item',
                  subtitle: 'Create a new inventory item (stock starts at 0)',
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AddInventoryItemDialog(
                        categories: _allCategories,
                        onSaved: _refreshAll,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                _ActionTile(
                  icon: Icons.add_chart_outlined,
                  color: Colors.orange,
                  title: 'Add Existing Stock',
                  subtitle: 'Increase stock for an existing item',
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AddExistingStockDialog(
                        allItems: _allItems,
                        onSaved: _refreshAll,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context)
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined, color: _teal, size: 20)
          ),
          const SizedBox(width: 10),
          Text('Inventory', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _teal)),
        ]),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _teal,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: _teal,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryManager(),
          _buildItemManager(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Add Category' : 'Add / Stock',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: _showActionSheet,
      ),
    );
  }

  // ── Category Manager Tab ───────────────────────────────────────────────────

  Widget _buildCategoryManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _categorySearchCtrl,
                decoration: InputDecoration(hintText: 'Search categories...', border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              )),
              if (_categorySearchCtrl.text.isNotEmpty)
                GestureDetector(onTap: _categorySearchCtrl.clear, child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary)),
            ]),
          ),
        ),
        Expanded(
          child: _isLoadingCategories
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : _categoriesError != null
              ? _buildError(_categoriesError!, _fetchCategories)
              : _filteredCategorySummaries.isEmpty
                ? _buildEmptyState('No categories found', Icons.category_outlined)
                : RefreshIndicator(
                    onRefresh: _refreshAll,
                    color: _teal,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _filteredCategorySummaries.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final cat = _filteredCategorySummaries[i];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryCategoryItemsScreen(
                                  categoryName: cat.name,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))]),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: _teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.category, color: _teal, size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${cat.itemCount} Item${cat.itemCount == 1 ? '' : 's'}  •  ${fmtStock(cat.totalStock)} ${cat.unit}',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      if (cat.lowStockCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Low Stock: ${cat.lowStockCount}',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: _teal, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  // ── Item Manager Tab ───────────────────────────────────────────────────────

  Widget _buildItemManager() {
    final lowCount = _allItems.where((i) => i.isLowStock).length;
    final outCount = _allItems.where((i) => i.isOutOfStock).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: _itemSearchCtrl,
                    decoration: InputDecoration(hintText: 'Search items...', border: InputBorder.none,
                      hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                  )),
                  if (_itemSearchCtrl.text.isNotEmpty)
                    GestureDetector(onTap: _itemSearchCtrl.clear, child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _itemChip('All', _allItems.length, 'all', _teal),
                const SizedBox(width: 8),
                _itemChip('Low Stock', lowCount, 'low', Colors.orange),
                const SizedBox(width: 8),
                _itemChip('Out of Stock', outCount, 'out', Colors.red),
              ])),
              const SizedBox(height: 16),
            ]
          )
        ),
        Expanded(
          child: _isLoadingItems
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : _itemsError != null
              ? _buildError(_itemsError!, _fetchInventory)
              : _filteredItems.isEmpty
                ? _buildEmptyState('No items found', Icons.inventory_2_outlined)
                : RefreshIndicator(
                    onRefresh: _refreshAll,
                    color: _teal,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final item = _filteredItems[i];
                        return _InventoryCard(
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
                            _refreshAll();
                          },
                          onEdit: () => _showEditDialog(item),
                          onDelete: () => _confirmDelete(item),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _itemChip(String label, int count, String filter, Color color) {
    final active = _activeFilter == filter;
    return GestureDetector(
      onTap: () => _setItemFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : AppColors.border, width: 1.5),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
              color: active ? Colors.white : AppColors.textSecondary)),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
                color: active ? Colors.white : color))),
        ]),
      ),
    );
  }

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'),
        style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white)),
    ])));
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: _teal.withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
    ]));
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItemModel item;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _InventoryCard({
    required this.item,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  Color get _c => item.isOutOfStock ? Colors.red : item.isLowStock ? Colors.orange : const Color(0xFF00897B);
  String get _lbl => item.isOutOfStock ? 'OUT OF STOCK' : item.isLowStock ? 'LOW STOCK' : 'NORMAL';

  @override
  Widget build(BuildContext context) {
    final pct = item.threshold > 0 ? (item.currentStock / (item.threshold * 3)).clamp(0.0, 1.0) : 1.0;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: (item.isLowStock || item.isOutOfStock) ? Border.all(color: _c.withValues(alpha: 0.35), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Icon(Icons.inventory_2_outlined, color: _c, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.itemName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (item.category != null && item.category!.isNotEmpty)
                Text(item.category!, style: GoogleFonts.inter(fontSize: 11, color: _c, fontWeight: FontWeight.w600)),
              Text('Threshold: ${fmtStock(item.threshold)} ${item.unit}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_lbl, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _c))),
            // ── Popup action menu ──────────────────────────────────────────
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF00897B)),
                    const SizedBox(width: 10),
                    Text('Edit', style: GoogleFonts.inter(fontSize: 14)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text('Delete', style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Stock', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              Text('${fmtStock(item.currentStock)} ${item.unit}',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _c)),
            ]),
            if (item.isLowStock || item.isOutOfStock)
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text('Order from supplier', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                ])),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6,
              backgroundColor: _c.withValues(alpha: 0.12), color: _c)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)),
            Text('Min: ${fmtStock(item.threshold)}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

// ── Bottom sheet action tile ───────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Icon(Icons.chevron_right, color: color, size: 22),
        ]),
      ),
    );
  }
}
