import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _assetsRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Pengguna belum login.');
    }
    return _firestore.collection('users').doc(uid).collection('assets');
  }

  // ===========================================================================
  // CRUD DATA BARANG (ASSETS)
  // ===========================================================================

  // Daftar barang milik user (Read)
  Stream<QuerySnapshot> getAssetsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _assetsRef.orderBy('createdAt', descending: true).snapshots();
  }

  // Tambah barang baru (Create)
  Future<void> addAsset(Map<String, dynamic> data) async {
    await _assetsRef.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Perbarui data barang, kondisi perangkat/rincian perawatan (Update)
  Future<void> updateAsset(String docId, Map<String, dynamic> data) async {
    await _assetsRef.doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Hapus barang beserta sub-koleksi riwayat perawatannya (Delete)
  Future<void> deleteAsset(String docId) async {
    final assetRef = _assetsRef.doc(docId);
    final historySnapshot =
        await assetRef.collection('maintenance_history').get();

    final batch = _firestore.batch();
    for (final doc in historySnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(assetRef);
    await batch.commit();
  }

  // ===========================================================================
  // CRUD RIWAYAT PERAWATAN (MAINTENANCE HISTORY)
  // ===========================================================================

  // Read: Ambil semua riwayat perawatan user untuk halaman Riwayat
  Stream<QuerySnapshot> getAllMaintenanceHistoryStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collectionGroup('maintenance_history')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Create: Menambahkan riwayat perawatan baru & update ringkasan barang
  Future<void> addMaintenanceRecord({
    required String assetId,
    required String assetName,
    required String maintenanceDate,
    required String cost,
    required String detail,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Pengguna belum login');
    final assetRef = _assetsRef.doc(assetId);

    final batch = _firestore.batch();

    // Simpan ke sub-koleksi riwayat perawatan
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

    // Perbarui perawatan terakhir pada dokumen barang
    batch.update(assetRef, {
      'lastMaintenance': maintenanceDate,
      'lastMaintenanceCost': cost,
      'maintenanceDetail': detail,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Update: Edit catatan riwayat perawatan yang sudah ada
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

  // Delete: Hapus satu catatan riwayat perawatan
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

  // ===========================================================================
  // CRUD JADWAL PERAWATAN (SCHEDULES)
  // ===========================================================================

  // Read: Mengambil daftar jadwal perawatan secara real-time
  Stream<QuerySnapshot> getSchedulesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .orderBy('scheduledTimestamp', descending: false)
        .snapshots();
  }

  // Create: Menambahkan jadwal perawatan baru
  Future<void> addSchedule(Map<String, dynamic> scheduleData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna belum masuk.');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .add({
          ...scheduleData,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // Update: Edit jadwal perawatan
  Future<void> updateSchedule(
    String scheduleId,
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna belum masuk.');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .doc(scheduleId)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Update: Menandai jadwal perawatan selesai & mencatat ke riwayat barang
  Future<void> completeSchedule({
    required String scheduleId,
    required String assetId,
    required String maintenanceTitle,
    required String dateFormatted,
    String assetName = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna belum masuk.');

    final userRef = _firestore.collection('users').doc(user.uid);

    // 1. Tandai jadwal sebagai selesai
    await userRef.collection('schedules').doc(scheduleId).update({
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // 2. Jika terhubung dengan barang di daftar aset, perbarui catatan terakhirnya
    if (assetId.isNotEmpty) {
      final assetRef = userRef.collection('assets').doc(assetId);
      await assetRef.update({
        'lastMaintenance': dateFormatted,
        'maintenanceDetail': maintenanceTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await assetRef.collection('maintenance_history').add({
        'userId': user.uid,
        'assetId': assetId,
        'assetName': assetName,
        'maintenanceDate': dateFormatted,
        'cost': 'Rp 0',
        'detail': maintenanceTitle,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Delete: Menghapus jadwal perawatan
  Future<void> deleteSchedule(String scheduleId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna belum masuk.');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }
}