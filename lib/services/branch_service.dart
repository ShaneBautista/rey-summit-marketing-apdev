import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/branch_model.dart';

/// Reads/writes the `branches` Firestore collection. Used by:
///  - the customer Cart page (to pick which branch fulfills an order)
///  - the admin Branch Management screen (to list/add/edit branches)
class BranchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _branches => _firestore.collection('branches');

  Future<List<BranchModel>> fetchBranches() async {
    final snap = await _branches.get();
    if (snap.docs.isEmpty) {
      // No branches seeded in Firestore yet — fall back to sample data so
      // the UI has something to show. Once you add real documents to the
      // `branches` collection, this fallback stops being used.
      return _seedBranches;
    }
    return snap.docs.map((d) => BranchModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> addBranch(BranchModel branch) => _branches.add(branch.toMap());

  Future<void> updateBranch(BranchModel branch) => _branches.doc(branch.id).update(branch.toMap());

  /// Same idea as InventoryService.seedSampleInventory() — [_seedBranches]
  /// is only ever a client-side fallback until this is called once to
  /// actually write those documents into Firestore. No-ops if the
  /// `branches` collection already has real data.
  Future<bool> seedSampleBranches() async {
    final existing = await _branches.limit(1).get();
    if (existing.docs.isNotEmpty) return false;
    final batch = _firestore.batch();
    for (final branch in _seedBranches) {
      // Use the seed's own id ('alangilan', 'sta_teresita', 'san_luis',
      // 'mabini') as the doc ID rather than an auto-generated one —
      // InventoryService's sample items reference these exact branchId
      // strings, so the two seeds need to agree on IDs for stock lookups
      // to actually match.
      batch.set(_branches.doc(branch.id), branch.toMap());
    }
    await batch.commit();
    return true;
  }

  static final List<BranchModel> _seedBranches = [
    const BranchModel(
      id: 'alangilan',
      name: 'IceTube – Alangilan',
      address: 'Alangilan, Batangas City',
      phone: '+63 912 345 6789',
      hours: '6:00 AM – 10:00 PM',
      isOpen: true,
    ),
    const BranchModel(
      id: 'sta_teresita',
      name: 'IceTube – Sta. Teresita',
      address: 'Sta. Teresita, Batangas City',
      phone: '+63 917 234 5678',
      hours: '6:00 AM – 9:00 PM',
      isOpen: true,
    ),
    const BranchModel(
      id: 'san_luis',
      name: 'IceTube – San Luis',
      address: 'San Luis, Batangas City',
      phone: '+63 918 765 4321',
      hours: '6:00 AM – 9:00 PM',
      isOpen: true,
    ),
    const BranchModel(
      id: 'mabini',
      name: 'IceTube – Mabini',
      address: 'Mabini, Batangas City',
      phone: '+63 919 876 5432',
      hours: '6:00 AM – 9:00 PM',
      isOpen: true,
    ),
  ];
}
