import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved family contact (subset of device contact data we need).
class FamilyContact {
  const FamilyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarBase64,
    this.isCaregiver = false,
  });

  final String id;
  final String name;
  final String phone;
  final String? avatarBase64; // base64-encoded thumbnail, nullable
  final bool isCaregiver;

  FamilyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? avatarBase64,
    bool? isCaregiver,
  }) =>
      FamilyContact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        avatarBase64: avatarBase64 ?? this.avatarBase64,
        isCaregiver: isCaregiver ?? this.isCaregiver,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'avatarBase64': avatarBase64,
        'isCaregiver': isCaregiver,
      };

  factory FamilyContact.fromJson(Map<String, dynamic> j) => FamilyContact(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        avatarBase64: j['avatarBase64'] as String?,
        isCaregiver: j['isCaregiver'] as bool? ?? false,
      );

  static String listToJson(List<FamilyContact> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<FamilyContact> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => FamilyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FamilyService
// ─────────────────────────────────────────────────────────────────────────────
class FamilyService extends ChangeNotifier {
  FamilyService._();
  static final instance = FamilyService._();

  static const _prefKey = 'family_contacts';

  List<FamilyContact> _contacts = [];

  List<FamilyContact> get contacts => List.unmodifiable(_contacts);

  FamilyContact? get caregiver =>
      _contacts.where((c) => c.isCaregiver).firstOrNull;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      _contacts = FamilyContact.listFromJson(raw);
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, FamilyContact.listToJson(_contacts));
  }

  Future<void> add(FamilyContact contact) async {
    // Ensure only one caregiver
    if (contact.isCaregiver) {
      _contacts = _contacts
          .map((c) => c.isCaregiver ? c.copyWith(isCaregiver: false) : c)
          .toList();
    }
    _contacts.add(contact);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> setCaregiver(String id) async {
    _contacts = _contacts.map((c) {
      return c.copyWith(isCaregiver: c.id == id);
    }).toList();
    notifyListeners();
    await _save();
  }
}
