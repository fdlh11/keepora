import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Pengguna belum login.');
    }
    return uid;
  }

  DocumentReference get _userDoc => _firestore.collection('users').doc(_uid);

  CollectionReference get _assetsRef => _userDoc.collection('assets');

  CollectionReference get _schedulesRef => _userDoc.collection('schedules');

  // Firebase Storage (Foto Barang)

  Future<String> uploadAssetImage(File imageFile) async {
    final uid = _uid;
    final fileName = 'asset_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('assets')
        .child(fileName);

    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> deleteAssetImageByUrl(String photoUrl) async {
    if (photoUrl.isEmpty) return;
    try {
      await _storage.refFromURL(photoUrl).delete();
    } catch (_) {
      // Abaikan jika file sudah terhapus atau URL tidak valid
    }
  }

  // CRUD Data Barang (Assets)

  Stream<QuerySnapshot> getAssetsStream() {
    if (_auth.currentUser == null) return const Stream.empty();
    return _assetsRef.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addAsset(Map<String, dynamic> data) async {
    await _assetsRef.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAsset(String docId, Map<String, dynamic> data) async {
    await _assetsRef.doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAsset(String docId) async {
    final assetRef = _assetsRef.doc(docId);

    // Ambil photoUrl terlebih dahulu agar foto di Storage ikut terhapus
    final assetSnap = await assetRef.get();
    final assetData = assetSnap.data() as Map<String, dynamic>? ?? {};
    final photoUrl = (assetData['photoUrl'] ?? '').toString();

    final historySnapshot =
        await assetRef.collection('maintenance_history').get();
    final schedulesSnapshot =
        await _schedulesRef.where('assetId', isEqualTo: docId).get();

    final batch = _firestore.batch();
    for (final doc in historySnapshot.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in schedulesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(assetRef);
    await batch.commit();

    if (photoUrl.isNotEmpty) {
      await deleteAssetImageByUrl(photoUrl);
    }
  }

  // CRUD Riwayat Perawatan (Maintenance History)

  Stream<QuerySnapshot> getAllMaintenanceHistoryStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collectionGroup('maintenance_history')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAssetMaintenanceHistoryStream(String assetId) {
    if (_auth.currentUser == null) return const Stream.empty();
    return _assetsRef
        .doc(assetId)
        .collection('maintenance_history')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addMaintenanceRecord({
    required String assetId,
    required String assetName,
    required String maintenanceDate,
    required String cost,
    required String detail,
  }) async {
    final uid = _uid;
    final assetRef = _assetsRef.doc(assetId);
    final batch = _firestore.batch();

    final historyRef = assetRef.collection('maintenance_history').doc();
    batch.set(historyRef, {
      'userId': uid,
      'assetId': assetId,
      'assetName': assetName,
      'maintenanceDate': maintenanceDate,
      'cost': cost,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(assetRef, {
      'lastMaintenance': maintenanceDate,
      'lastMaintenanceCost': cost,
      'maintenanceDetail': detail,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateMaintenanceRecord({
    required String assetId,
    required String historyId,
    required String maintenanceDate,
    required String cost,
    required String detail,
  }) async {
    await _assetsRef
        .doc(assetId)
        .collection('maintenance_history')
        .doc(historyId)
        .update({
      'maintenanceDate': maintenanceDate,
      'cost': cost,
      'detail': detail,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMaintenanceRecord({
    required String assetId,
    required String historyId,
  }) async {
    await _assetsRef
        .doc(assetId)
        .collection('maintenance_history')
        .doc(historyId)
        .delete();
  }

  // CRUD Jadwal Perawatan (Schedules)

  Stream<QuerySnapshot> getSchedulesStream() {
    if (_auth.currentUser == null) return const Stream.empty();
    return _schedulesRef
        .orderBy('scheduledTimestamp', descending: false)
        .snapshots();
  }

  Future<void> addSchedule(Map<String, dynamic> scheduleData) async {
    await _schedulesRef.add({
      ...scheduleData,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSchedule(
    String scheduleId,
    Map<String, dynamic> data,
  ) async {
    await _schedulesRef.doc(scheduleId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeSchedule({
    required String scheduleId,
    required String assetId,
    required String maintenanceTitle,
    required String dateFormatted,
    String assetName = '',
    String cost = 'Rp 0',
  }) async {
    final uid = _uid;
    final batch = _firestore.batch();

    batch.update(_schedulesRef.doc(scheduleId), {
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    if (assetId.isNotEmpty) {
      final assetRef = _assetsRef.doc(assetId);
      batch.update(assetRef, {
        'lastMaintenance': dateFormatted,
        'lastMaintenanceCost': cost,
        'maintenanceDetail': maintenanceTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final historyRef = assetRef.collection('maintenance_history').doc();
      batch.set(historyRef, {
        'userId': uid,
        'assetId': assetId,
        'assetName': assetName,
        'maintenanceDate': dateFormatted,
        'cost': cost,
        'detail': maintenanceTitle,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _schedulesRef.doc(scheduleId).delete();
  }
}