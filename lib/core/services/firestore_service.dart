import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/alert_entry.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import 'family_service.dart';

/// Centralised Firestore data layer for EverWith.
///
/// Collections:
/// - `users/{uid}` — user profiles
/// - `users/{elderUid}/medicines/{id}` — elder's medicine list
/// - `users/{elderUid}/alerts/{id}` — alert history
/// - `users/{elderUid}/familyContacts/{id}` — elder's family contacts
/// - `pairingCodes/{code}` — temporary pairing codes
class FirestoreService extends ChangeNotifier {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  //  User Profiles
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create or overwrite a user profile document.
  Future<void> createUserProfile(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).set(profile.toJson());
  }

  /// Fetch a user profile by UID. Returns `null` if not found.
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  /// Fetch the role of a user. Returns `null` if no profile exists.
  Future<UserRole?> getUserRole(String uid) async {
    final profile = await getUserProfile(uid);
    return profile?.role;
  }

  /// Update specific fields on a user profile.
  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Pairing Codes
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a 6-character alphanumeric pairing code for an elder.
  /// The code expires after 24 hours.
  Future<String> generatePairingCode(String elderUid) async {
    // Delete any existing codes for this elder
    final existing = await _db
        .collection('pairingCodes')
        .where('elderUid', isEqualTo: elderUid)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    final code = _randomCode(6);
    await _db.collection('pairingCodes').doc(code).set({
      'elderUid': elderUid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
    return code;
  }

  /// Redeem a pairing code — links a caregiver to an elder.
  ///
  /// Returns the elder's UID on success, or `null` if the code is invalid
  /// or expired.
  Future<String?> redeemPairingCode({
    required String code,
    required String caregiverUid,
  }) async {
    final doc = await _db.collection('pairingCodes').doc(code).get();
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      // Expired — clean up
      await doc.reference.delete();
      return null;
    }

    final elderUid = data['elderUid'] as String;

    // Link caregiver → elder
    await _db.collection('users').doc(caregiverUid).update({
      'linkedElderUid': elderUid,
    });

    // Link elder → caregiver (add to list)
    await _db.collection('users').doc(elderUid).update({
      'linkedCaregiverUids': FieldValue.arrayUnion([caregiverUid]),
    });

    // Clean up the consumed code
    await doc.reference.delete();

    return elderUid;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Medicines (Elder's data, streamed by Caregiver)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Push a full medicine list update for an elder.
  Future<void> syncMedicines(String elderUid, List<Medicine> medicines) async {
    final col = _db.collection('users').doc(elderUid).collection('medicines');

    // Batch write — delete all, then re-add
    final batch = _db.batch();
    final existing = await col.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final med in medicines) {
      batch.set(col.doc(med.id), med.toJson());
    }
    await batch.commit();
  }

  /// Real-time stream of an elder's medicines.
  Stream<List<Medicine>> streamElderMedicines(String elderUid) {
    return _db
        .collection('users')
        .doc(elderUid)
        .collection('medicines')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Medicine.fromJson(d.data())).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Alerts (logged by Elder, viewed by Caregiver)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Push a new alert entry for an elder.
  Future<void> pushAlertEntry(String elderUid, AlertEntry entry) async {
    await _db
        .collection('users')
        .doc(elderUid)
        .collection('alerts')
        .doc(entry.id)
        .set(entry.toJson());
  }

  /// Real-time stream of an elder's alert history, newest first.
  Stream<List<AlertEntry>> streamAlertHistory(String elderUid) {
    return _db
        .collection('users')
        .doc(elderUid)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AlertEntry.fromJson(d.data())).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Family Contacts (Elder's contacts, viewed by Caregiver)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync elder's family contacts to Firestore.
  Future<void> syncFamilyContacts(
      String elderUid, List<FamilyContact> contacts) async {
    final col =
        _db.collection('users').doc(elderUid).collection('familyContacts');

    final batch = _db.batch();
    final existing = await col.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final c in contacts) {
      batch.set(col.doc(c.id), c.toJson());
    }
    await batch.commit();
  }

  /// Stream elder's family contacts.
  Stream<List<FamilyContact>> streamFamilyContacts(String elderUid) {
    return _db
        .collection('users')
        .doc(elderUid)
        .collection('familyContacts')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FamilyContact.fromJson(d.data()))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static String _randomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 confusion
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
