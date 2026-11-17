import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Kompresi & Konversi Foto ke Base64 Data URI (Gratis Tanpa Firebase Storage)

  Future<String> uploadAssetImage(File imageFile) async {
    final Uint8List rawBytes = await imageFile.readAsBytes();

    // Kecilkan resolusi maksimal lebar 720px agar ukuran dokumen Firestore tetap ringan (< 300 KB)
    final ui.Codec codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: 720,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final Uint8List finalBytes =
        byteData != null ? byteData.buffer.asUint8List() : rawBytes;

    // Jika hasil PNG masih terlalu besar (> 750 KB), gunakan bytes asli (JPEG hasil kompresi image_picker)
    final Uint8List chosenBytes =
        finalBytes.lengthInBytes > 750000 ? rawBytes : finalBytes;

    if (chosenBytes.lengthInBytes > 850000) {
      throw Exception(
        'Ukuran foto terlalu besar. Gunakan foto dengan resolusi lebih kecil.',
      );
    }

    final String base64Str = base64Encode(chosenBytes);
    return 'data:image/jpeg;base64,$base64Str';
  }

  Future<void> deleteAssetImageByUrl(String photoUrl) async {
    // Tidak perlu menghapus dari Storage karena foto tersimpan di dokumen Firestore
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
  }

  // CRUD Riwayat Perawatan (Maintenance History)

  Stream<List<QueryDocumentSnapshot>> getAllMaintenanceHistoryStream() {
    if (_auth.currentUser == null) return const Stream.empty();

    return _assetsRef.snapshots().asyncMap((assetsSnap) async {
      if (assetsSnap.docs.isEmpty) return <QueryDocumentSnapshot>[];

      final futures = assetsSnap.docs.map(
        (assetDoc) => assetDoc.reference
            .collection('maintenance_history')
            .get(),
      );

      final snapshots = await Future.wait(futures);
      return snapshots.expand((snap) => snap.docs).toList();
    });
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
    String title = 'Perawatan Barang',
    String maintenanceType = 'Perawatan',
    DateTime? completedAtDate,
  }) async {
    final uid = _uid;
    final assetRef = _assetsRef.doc(assetId);
    final batch = _firestore.batch();
    final effectiveDate = completedAtDate ?? DateTime.now();

    final historyRef = assetRef.collection('maintenance_history').doc();
    batch.set(historyRef, {
      'userId': uid,
      'assetId': assetId,
      'assetName': assetName,
      'title': title,
      'maintenanceType': maintenanceType,
      'maintenanceDate': maintenanceDate,
      'cost': cost,
      'detail': detail,
      'notes': detail,
      'completedAt': Timestamp.fromDate(effectiveDate),
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
    required String title,
    required String maintenanceType,
    required String maintenanceDate,
    required DateTime completedAtDate,
    required dynamic cost,
    required String detail,
  }) async {
    final batch = _firestore.batch();
    final assetRef = _assetsRef.doc(assetId);
    final historyRef = assetRef.collection('maintenance_history').doc(historyId);

    batch.update(historyRef, {
      'title': title.trim(),
      'maintenanceType': maintenanceType,
      'maintenanceDate': maintenanceDate,
      'completedAt': Timestamp.fromDate(completedAtDate),
      'cost': cost,
      'detail': detail.trim(),
      'notes': detail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Memicu stream induk agar daftar riwayat langsung refresh otomatis
    batch.update(assetRef, {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteMaintenanceRecord({
    required String assetId,
    required String historyId,
  }) async {
    final batch = _firestore.batch();
    final assetRef = _assetsRef.doc(assetId);
    final historyRef = assetRef.collection('maintenance_history').doc(historyId);

    batch.delete(historyRef);
    batch.update(assetRef, {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
        'title': maintenanceTitle,
        'maintenanceType': 'Perawatan',
        'maintenanceDate': dateFormatted,
        'cost': cost,
        'detail': maintenanceTitle,
        'notes': maintenanceTitle,
        'completedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _schedulesRef.doc(scheduleId).delete();
  }
}