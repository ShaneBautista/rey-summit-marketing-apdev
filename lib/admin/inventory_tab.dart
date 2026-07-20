import 'package:flutter/material.dart';

import '../models/branch_model.dart';
import '../models/inventory_item_model.dart';
import '../services/branch_service.dart';
import '../services/inventory_service.dart';
import 'admin_colors.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryService _inventoryService = InventoryService();
  final BranchService _branchService = BranchService();
  late Stream<List<InventoryItem>> _inventoryStream;

  String _search = '';
  String _branchFilter = 'All Branches';
  String _statusFilter = 'All Status';

  @override
  void initState() {
    super.initState();
    _inventoryStream = _inventoryService.streamInventory();
  }

  Future<void> _restock(InventoryItem item) async {
    final controller = TextEditingController();
    final addQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${item.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity to add', hintText: 'e.g. 50'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Add stock'),
          ),
        ],
      ),
    );

    if (addQty == null || addQty <= 0) return;

    try {
      // streamInventory() always seeds real Firestore documents before
      // emitting, so item.id here is a genuine doc id — no fallback
      // special-casing needed.
      await _inventoryService.restockItem(docId: item.id, addQty: addQty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $addQty to ${item.name}.')),
      );
      // No manual refresh call needed — the stream picks up the write
      // automatically.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restock: $e')),
      );
    }
  }

  Future<void> _reduceStock(InventoryItem item) async {
    final controller = TextEditingController();
    final removeQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reduce stock — ${item.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity to remove',
            hintText: 'e.g. 10',
            helperText: 'Currently ${item.qty} in stock',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Remove stock'),
          ),
        ],
      ),
    );

    if (removeQty == null || removeQty <= 0) return;

    try {
      await _inventoryService.reduceStock(docId: item.id, removeQty: removeQty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $removeQty from ${item.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reduce stock: $e')),
      );
    }
  }

  Future<void> _addProduct() async {
    final branches = await _branchService.fetchBranches();
    if (!mounted) return;

    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    BranchModel? selectedBranch = branches.isNotEmpty ? branches.first : null;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Product name', hintText: 'e.g. Ice Tube – Small'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU', hintText: 'e.g. ITS-001'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Starting quantity', hintText: 'e.g. 100'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (₱)', hintText: 'e.g. 45'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<BranchModel>(
                  value: selectedBranch,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: branches
                      .map((b) => DropdownMenuItem(value: b, child: Text(b.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBranch = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add product'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;

    final name = nameController.text.trim();
    final sku = skuController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (name.isEmpty || sku.isEmpty || selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, SKU, and branch are required.')),
      );
      return;
    }

    try {
      await _inventoryService.addInventoryItem(InventoryItem(
        id: '', // ignored by addInventoryItem — the doc id is derived from sku + branchId
        sku: sku,
        name: name,
        qty: qty,
        price: price,
        branchId: selectedBranch!.id,
        branchName: selectedBranch!.name,
        restocked: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to ${selectedBranch!.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add product: $e')),
      );
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This removes "${item.name}" (${item.sku}) from ${item.branchName}\'s inventory. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: kAdminRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _inventoryService.deleteInventoryItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} deleted from ${item.branchName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    return items.where((item) {
      final matchesSearch = _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase()) ||
          item.sku.toLowerCase().contains(_search.toLowerCase());
      final matchesBranch = _branchFilter == 'All Branches' || item.branchName == _branchFilter;
      final matchesStatus = _statusFilter == 'All Status' || item.status.label == _statusFilter;
      return matchesSearch && matchesBranch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: _inventoryStream,
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final filtered = _applyFilters(allItems);
        final lowCount = allItems.where((i) => i.status == StockStatus.lowStock).length;
        final outCount = allItems.where((i) => i.status == StockStatus.outOfStock).length;
        final branches = {'All Branches', ...allItems.map((i) => i.branchName)}.toList();

        return RefreshIndicator(
          color: kAdminBlue,
          onRefresh: () async {
            setState(() => _inventoryStream = _inventoryService.streamInventory());
            await _inventoryStream.first;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Text('Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Product'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAdminBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _inventoryStream = _inventoryService.streamInventory()),
                    icon: const Icon(Icons.refresh, color: kAdminBlue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (lowCount > 0)
                _AlertBanner(
                  icon: Icons.warning_amber_rounded,
                  color: kAdminAmber,
                  text: '$lowCount item${lowCount == 1 ? '' : 's'} running low on stock',
                ),
              if (outCount > 0) ...[
                const SizedBox(height: 8),
                _AlertBanner(
                  icon: Icons.error_outline,
                  color: kAdminRed,
                  text: '$outCount item${outCount == 1 ? '' : 's'} out of stock',
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search product or SKU...',
                  hintStyle: const TextStyle(color: kAdminCardGrey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kAdminCardGrey, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      value: _branchFilter,
                      options: branches,
                      onChanged: (v) => setState(() => _branchFilter = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterDropdown(
                      value: _statusFilter,
                      options: const ['All Status', 'In Stock', 'Low Stock', 'Out of Stock'],
                      onChanged: (v) => setState(() => _statusFilter = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Inventory Items (${filtered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 14)),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No items match your filters.', style: TextStyle(color: kAdminCardGrey))),
                )
              else
                ...filtered.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InventoryCard(
                        item: item,
                        onRestock: () => _restock(item),
                        onReduceStock: () => _reduceStock(item),
                        onDelete: () => _deleteItem(item),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AlertBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAdminBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: kAdminCardGrey, size: 18),
          style: const TextStyle(color: kAdminDarkBlue, fontSize: 13),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onRestock;
  final VoidCallback onReduceStock;
  final VoidCallback onDelete;
  const _InventoryCard({
    required this.item,
    required this.onRestock,
    required this.onReduceStock,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (item.status) {
      case StockStatus.inStock:
        return kAdminGreen;
      case StockStatus.lowStock:
        return kAdminAmber;
      case StockStatus.outOfStock:
        return kAdminRed;
    }
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: kAdminShadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(color: kAdminBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.view_in_ar_outlined, color: kAdminBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 14)),
                    Text(item.sku, style: const TextStyle(color: kAdminCardGrey, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(item.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricChip(value: '${item.qty}', label: 'Qty'),
              const SizedBox(width: 8),
              _MetricChip(value: '₱${item.price.toStringAsFixed(0)}', label: 'Price'),
              const SizedBox(width: 8),
              _MetricChip(value: _formatDate(item.restocked), label: 'Restocked'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 13, color: kAdminCardGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(item.branchName, style: const TextStyle(fontSize: 12, color: kAdminCardGrey)),
              ),
              TextButton.icon(
                onPressed: item.qty <= 0 ? null : onReduceStock,
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('Reduce'),
                style: TextButton.styleFrom(
                  foregroundColor: kAdminRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              TextButton.icon(
                onPressed: onRestock,
                icon: const Icon(Icons.add_box_outlined, size: 16),
                label: const Text('Restock'),
                style: TextButton.styleFrom(
                  foregroundColor: kAdminBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 19),
                color: kAdminRed,
                tooltip: 'Delete product',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String value;
  final String label;
  const _MetricChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: kAdminBg, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 10, color: kAdminCardGrey)),
          ],
        ),
      ),
    );
  }
}
