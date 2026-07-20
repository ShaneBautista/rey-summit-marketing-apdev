import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  customer,
  employee,
}

class AppUserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String? address; // customer
  final String? employeeId; // employee
  final String? branchId; // employee — which branch they're assigned to
  final DateTime? createdAt; // when this account was registered

  const AppUserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.address,
    this.employeeId,
    this.branchId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
    };

    // Only write the fields that actually apply to this role — and only
    // if there's a real value. Sign-up doesn't currently collect a
    // customer's address (it's captured later, at checkout, in the order
    // confirmation sheet) or an employee's branch assignment (an admin
    // sets that separately) — so skip writing an empty placeholder for
    // either rather than cluttering the Firestore doc with `""`.
    if (role == UserRole.customer) {
      if (address != null && address!.trim().isNotEmpty) map['address'] = address!.trim();
    } else {
      map['employeeId'] = employeeId ?? '';
      if (branchId != null && branchId!.trim().isNotEmpty) map['branchId'] = branchId!.trim();
    }

    return map;
  }

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserModel(
      uid: uid,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.name == (map['role'] as String? ?? UserRole.customer.name),
        orElse: () => UserRole.customer,
      ),
      address: map['address'] as String?,
      employeeId: map['employeeId'] as String?,
      branchId: map['branchId'] as String?,
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
