import 'package:flutter/material.dart';

import '../models/branch_model.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/branch_service.dart';
import '../services/order_service.dart';
import '../theme/colors.dart';
import '../utils/validators.dart';
import '../widgets/animated_button.dart';

/// Shows whatever's currently in the cart, lets the customer pick a branch,
/// review an order confirmation (address, items, total, payment method),
/// and place the order — which writes a document to the same Firestore
/// `orders` collection the admin app reads. See order_service.dart for how
/// that connection works end-to-end.
class CartPage extends StatefulWidget {
  final List<CartItem> items;
  final ValueChanged<int> onRemove;
  final void Function(int index, int newQuantity) onQuantityChanged;
  final VoidCallback onOrderPlaced;

  const CartPage({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onOrderPlaced,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final BranchService _branchService = BranchService();
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final branches = await _branchService.fetchBranches();
    if (!mounted) return;
    setState(() {
      _branches = branches;
      _selectedBranch = branches.isNotEmpty ? branches.first : null;
    });
  }

  double get _total => widget.items.fold(0, (sum, c) => sum + c.lineTotal);

  Future<void> _openOrderConfirmation() async {
    if (widget.items.isEmpty || _selectedBranch == null) return;

    final profile = await _authService.fetchCurrentUserProfile();
    if (!mounted) return;

    final initialName =
        profile == null ? '' : '${profile.firstName} ${profile.lastName}'.trim();

    final result = await showModalBottomSheet<_ConfirmationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderConfirmationSheet(
        items: widget.items,
        branchName: _selectedBranch!.name,
        total: _total,
        initialName: initialName,
        initialAddress: profile?.address ?? '',
      ),
    );

    if (result == null || !mounted) return;
    await _placeOrder(name: result.name, address: result.address, paymentMethod: result.paymentMethod);
  }

  Future<void> _placeOrder({
    required String name,
    required String address,
    required String paymentMethod,
  }) async {
    if (widget.items.isEmpty || _selectedBranch == null) return;
    setState(() => _isPlacingOrder = true);
    try {
      await _orderService.placeOrder(
        items: widget.items,
        branchId: _selectedBranch!.id,
        branchName: _selectedBranch!.name,
        recipientName: name,
        deliveryAddress: address,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;
      widget.onOrderPlaced();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed! Track it under Order History.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('Cart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDarkGreen)),
        ),
        Expanded(
          child: widget.items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 56, color: kFieldGrey),
                      SizedBox(height: 12),
                      Text('Your cart is empty', style: TextStyle(color: kFieldGrey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    if (_branches.isNotEmpty) ...[
                      const Text('Fulfilled by', style: TextStyle(fontSize: 13, color: kFieldGrey)),
                      const SizedBox(height: 6),
                      _BranchDropdown(
                        branches: _branches,
                        selected: _selectedBranch,
                        onChanged: (b) => setState(() => _selectedBranch = b),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...List.generate(widget.items.length, (i) {
                      final cartItem = widget.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey('${cartItem.product.sku}_$i'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => widget.onRemove(i),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration:
                                BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          child: _CartRow(
                            cartItem: cartItem,
                            onRemove: () => widget.onRemove(i),
                            onQuantityChanged: (qty) => widget.onQuantityChanged(i, qty),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        if (widget.items.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 15, color: kFieldGrey)),
                    Text('₱${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDarkGreen)),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedButton(
                  onTap: _isPlacingOrder ? () {} : _openOrderConfirmation,
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDarkGreen),
                    alignment: Alignment.center,
                    child: _isPlacingOrder
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Place Order',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  final List<BranchModel> branches;
  final BranchModel? selected;
  final ValueChanged<BranchModel?> onChanged;

  const _BranchDropdown({required this.branches, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BranchModel>(
          isExpanded: true,
          value: selected,
          icon: const Icon(Icons.keyboard_arrow_down, color: kFieldGrey),
          items: branches
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.name, style: const TextStyle(color: kDarkGreen, fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  const _CartRow({required this.cartItem, required this.onRemove, required this.onQuantityChanged});

  @override
  Widget build(BuildContext context) {
    final product = cartItem.product;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(color: product.bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(product.icon, color: kDarkGreen, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kDarkGreen)),
                const SizedBox(height: 2),
                Text('₱${product.price.toStringAsFixed(0)} each',
                    style: const TextStyle(fontSize: 12, color: kFieldGrey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuantityStepper(
            quantity: cartItem.quantity,
            onChanged: onQuantityChanged,
          ),
          const SizedBox(width: 4),
          IconButton(
            splashRadius: 20,
            icon: const Icon(Icons.close, size: 18, color: kFieldGrey),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// The +/- quantity control shown on each cart row. Tapping "-" at
/// quantity 1 removes the line entirely (delegated back up via
/// onChanged(0), which HomeDashboardPage._updateQuantity treats as remove).
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kLightMint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(icon: Icons.remove, onTap: () => onChanged(quantity - 1)),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: kDarkGreen, fontSize: 14),
            ),
          ),
          _stepButton(icon: Icons.add, onTap: () => onChanged(quantity + 1)),
        ],
      ),
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: kDarkGreen),
      ),
    );
  }
}

/// What the confirmation sheet hands back once the customer taps
/// "Confirm Order".
class _ConfirmationResult {
  final String name;
  final String address;
  final String paymentMethod;
  const _ConfirmationResult({required this.name, required this.address, required this.paymentMethod});
}

const List<String> _paymentMethods = [
  'Cash on Delivery',
  'GCash',
  'Maya',
  'Debit / Credit Card',
];

/// The order confirmation sheet — delivery address, itemized order summary,
/// payment method, and total — shown right before an order is actually
/// written to Firestore. This is the last chance to double-check everything.
class _OrderConfirmationSheet extends StatefulWidget {
  final List<CartItem> items;
  final String branchName;
  final double total;
  final String initialName;
  final String initialAddress;

  const _OrderConfirmationSheet({
    required this.items,
    required this.branchName,
    required this.total,
    required this.initialName,
    required this.initialAddress,
  });

  @override
  State<_OrderConfirmationSheet> createState() => _OrderConfirmationSheetState();
}

class _OrderConfirmationSheetState extends State<_OrderConfirmationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _addressController =
      TextEditingController(text: widget.initialAddress);
  String _paymentMethod = _paymentMethods.first;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: kLightMint,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(4)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Text('Confirm Order',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDarkGreen)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 16, color: kFieldGrey),
                        const SizedBox(width: 6),
                        Text('Fulfilled by ${widget.branchName}',
                            style: const TextStyle(fontSize: 13, color: kFieldGrey)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ---- Recipient name ----
                    const Text('Recipient Name',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDarkGreen)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderGrey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: kFieldGrey, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 14, color: kDarkGreen),
                              validator: (v) => Validators.required(v, label: 'Recipient name'),
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                hintText: 'Who should we hand this to?',
                                hintStyle: TextStyle(color: kFieldGrey, fontSize: 14),
                                border: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                errorStyle: TextStyle(fontSize: 11, color: Colors.redAccent, height: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Delivery address ----
                    const Text('Delivery Address',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDarkGreen)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderGrey),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Icon(Icons.location_on_outlined, color: kFieldGrey, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _addressController,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 14, color: kDarkGreen),
                              validator: (v) => Validators.required(v, label: 'Delivery address'),
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: const InputDecoration(
                                hintText: 'Enter your delivery address',
                                hintStyle: TextStyle(color: kFieldGrey, fontSize: 14),
                                border: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                errorStyle: TextStyle(fontSize: 11, color: Colors.redAccent, height: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Order summary ----
                    const Text('Order Summary',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDarkGreen)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderGrey),
                      ),
                      child: Column(
                        children: [
                          for (final c in widget.items) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Text('${c.quantity}x',
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.bold, color: kFieldGrey)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(c.product.name,
                                        style: const TextStyle(fontSize: 14, color: kDarkGreen)),
                                  ),
                                  Text('₱${c.lineTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: kDarkGreen)),
                                ],
                              ),
                            ),
                            if (c != widget.items.last) const Divider(height: 1, color: kBorderGrey),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Payment method ----
                    const Text('Payment Method',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kDarkGreen)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorderGrey),
                      ),
                      child: Column(
                        children: [
                          for (final method in _paymentMethods) ...[
                            RadioListTile<String>(
                              value: method,
                              groupValue: _paymentMethod,
                              onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
                              activeColor: kDarkGreen,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(method, style: const TextStyle(fontSize: 14, color: kDarkGreen)),
                            ),
                            if (method != _paymentMethods.last) const Divider(height: 1, color: kBorderGrey),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 15, color: kFieldGrey)),
                      Text('₱${widget.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDarkGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedButton(
                    onTap: () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.pop(
                        context,
                        _ConfirmationResult(
                          name: _nameController.text.trim(),
                          address: _addressController.text.trim(),
                          paymentMethod: _paymentMethod,
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDarkGreen),
                      alignment: Alignment.center,
                      child: const Text('Confirm Order',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Back to Cart', style: TextStyle(color: kFieldGrey, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
