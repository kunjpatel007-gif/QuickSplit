import 'package:uuid/uuid.dart';

class User {
  final int? id;
  final String syncId;
  final String name;
  final String? upiId;
  final String? phoneNumber;
  final DateTime createdAt;

  const User({
    this.id,
    this.syncId = '',
    required this.name,
    this.upiId,
    this.phoneNumber,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      syncId: (map['sync_id'] as String?) ?? '',
      name: map['name'] as String,
      upiId: map['upi_id'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId.isEmpty ? const Uuid().v4() : syncId,
      'name': name,
      'upi_id': upiId,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? syncId,
    String? name,
    String? upiId,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
