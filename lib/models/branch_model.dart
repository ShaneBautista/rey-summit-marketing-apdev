/// A physical branch location. Mirrors what Branch Management needs to
/// display and what Inventory needs to filter by.
class BranchModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String hours;
  final bool isOpen;

  const BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.hours,
    required this.isOpen,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'phone': phone,
        'hours': hours,
        'isOpen': isOpen,
      };

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) {
    return BranchModel(
      id: id,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      hours: map['hours'] as String? ?? '',
      isOpen: map['isOpen'] as bool? ?? true,
    );
  }
}
