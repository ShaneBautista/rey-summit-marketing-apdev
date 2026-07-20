import 'package:flutter/material.dart';

import '../models/branch_model.dart';
import '../models/inventory_item_model.dart';
import '../services/branch_service.dart';
import '../services/inventory_service.dart';
import 'admin_colors.dart';
import 'inventory_tab.dart';

class BranchesTab extends StatefulWidget {
  const BranchesTab({super.key});

  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<BranchesTab> {
  final BranchService _branchService = BranchService();
  final InventoryService _inventoryService = InventoryService();
  late Future<List<BranchModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _branchService.fetchBranches();
  }

  Future<void> _refresh() async {
    setState(() => _future = _branchService.fetchBranches());
    await _future;
  }

  Future<void> _openForm({BranchModel? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(existing: existing),
    );
    if (result == true) _refresh();
  }

  /// Adds a product straight to [branch] — the Branch Management version
  /// of Inventory's "Add Product". Unlike the Inventory tab's dialog,
  /// there's no branch dropdown here: the branch is already fixed by
  /// which card the admin tapped "Add Product" on.
  Future<void> _addProductToBranch(BranchModel branch) async {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Product — ${branch.name}'),
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
    );

    if (created != true) return;

    final name = nameController.text.trim();
    final sku = skuController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (name.isEmpty || sku.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and SKU are required.')),
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
        branchId: branch.id,
        branchName: branch.name,
        restocked: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to ${branch.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kAdminBlue,
      onRefresh: _refresh,
      child: FutureBuilder<List<BranchModel>>(
        future: _future,
        builder: (context, snapshot) {
          final branches = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Text('Branch Management',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAdminBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No branches yet.', style: TextStyle(color: kAdminCardGrey))),
                )
              else
                ...List.generate(
                  branches.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BranchCard(
                      index: i + 1,
                      branch: branches[i],
                      onEdit: () => _openForm(existing: branches[i]),
                      onAddProduct: () => _addProductToBranch(branches[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final int index;
  final BranchModel branch;
  final VoidCallback onEdit;
  final VoidCallback onAddProduct;
  const _BranchCard({
    required this.index,
    required this.branch,
    required this.onEdit,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: kAdminShadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: const BoxDecoration(color: kAdminBlue, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(branch.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kAdminDarkBlue, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (branch.isOpen ? kAdminGreen : kAdminRed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  branch.isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: branch.isOpen ? kAdminGreen : kAdminRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.location_on_outlined, text: branch.address),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.phone_outlined, text: branch.phone),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.access_time, text: branch.hours),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAdminDarkBlue,
                    side: const BorderSide(color: kAdminBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: kAdminBg,
                          appBar: AppBar(
                            backgroundColor: Colors.white,
                            foregroundColor: kAdminDarkBlue,
                            elevation: 0,
                            title: Text(branch.name, style: const TextStyle(fontSize: 15)),
                          ),
                          body: const InventoryTab(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAdminBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Inventory'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddProduct,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kAdminGreen,
                side: const BorderSide(color: kAdminGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kAdminCardGrey),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: kAdminCardGrey))),
      ],
    );
  }
}

/// Add/Edit Branch form — a real Form with TextFormField validation,
/// shown as a bottom sheet. [existing] null means "Add"; non-null means
/// "Edit" and the fields are pre-filled from it.
class _BranchFormSheet extends StatefulWidget {
  final BranchModel? existing;
  const _BranchFormSheet({this.existing});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _branchService = BranchService();

  InputDecoration _decoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: kAdminCardGrey, size: 20),
      filled: true,
      fillColor: kAdminBg,
      labelStyle: const TextStyle(color: kAdminCardGrey, fontSize: 13),
      hintStyle: const TextStyle(color: kAdminCardGrey, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAdminBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAdminRed, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _addressController = TextEditingController(text: widget.existing?.address);
  late final _phoneController = TextEditingController(text: widget.existing?.phone);
  late final _hoursController = TextEditingController(text: widget.existing?.hours);
  late bool _isOpen = widget.existing?.isOpen ?? true;

  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    // Loose check — just enough to catch obviously-wrong input without
    // being overly strict about country-code formatting.
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7) return 'Enter a valid phone number';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final branch = BranchModel(
        id: widget.existing?.id ?? '',
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        hours: _hoursController.text.trim(),
        isOpen: _isOpen,
      );

      if (_isEditing) {
        await _branchService.updateBranch(branch);
      } else {
        await _branchService.addBranch(branch);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save branch: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the sheet above the keyboard as the user types.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: kAdminBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(
                  _isEditing ? 'Edit Branch' : 'Add Branch',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAdminDarkBlue),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    label: 'Branch Name',
                    hint: 'e.g. IceTube – East Branch',
                    icon: Icons.storefront_outlined,
                  ),
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    label: 'Address',
                    hint: 'e.g. 12 Rizal St., East District',
                    icon: Icons.location_on_outlined,
                  ),
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    label: 'Phone',
                    hint: 'e.g. +63 912 345 6789',
                    icon: Icons.phone_outlined,
                  ),
                  validator: _phoneValidator,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _hoursController,
                  decoration: _decoration(
                    label: 'Hours',
                    hint: 'e.g. 6:00 AM – 10:00 PM',
                    icon: Icons.access_time,
                  ),
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Currently open',
                      style: TextStyle(color: kAdminDarkBlue, fontWeight: FontWeight.w600, fontSize: 14)),
                  value: _isOpen,
                  activeThumbColor: kAdminBlue,
                  onChanged: (v) => setState(() => _isOpen = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAdminBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Add Branch',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
