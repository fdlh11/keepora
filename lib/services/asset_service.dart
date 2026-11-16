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

  // Datfar barang milik user
  Stream<QuerySnapshot> getAssetsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _assetsRef.orderBy('createdAt', descending: true).snapshots();
  }

  // Tambah barang baru
  Future<void> addAsset(Map<String, dynamic> data) async {
    await _assetsRef.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Perbarui data barang, kondisi perangkat/rincian perawatan
  Future<void> updateAsset(String docId, Map<String, dynamic> data) async {
    await _assetsRef.doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Hapus barang
  Future<void> deleteAsset(String docId) async {
    await _assetsRef.doc(docId).delete();
  }

  /// Menambahkan riwayat perawatan baru dan memperbarui ringkasan perawatan terakhir pada barang
  Future<void> addMaintenanceRecord({
    required String assetId,
    required String assetName,
    required String maintenanceDate,
    required String cost,
    required String detail,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Pengguna belum login');
    final assetRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('assets')
        .doc(assetId);

    final batch = _firestore.batch();

    // simpan ke sub koleksi riwayat perawatab
    final historyRef = assetRef.collection('maintenance_history').doc();
    batch.set(historyRef, {
      'assetId': assetId,
      'assetName': assetName,
      'maintenanceDate': maintenanceDate,
      'cost': cost,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // perbarui perawatan terakhir
    batch.update(assetRef, {
      'lastMaintenance': maintenanceDate,
      'lastMaintenanceCost': cost,
      'maintenanceDetail': detail,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Mengambil daftar jadwal perawatan secara real-time
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

  // Menambahkan jadwal perawatan baru
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

  // Menandai jadwal perawatan selesai & memperbarui status terakhir barang
  Future<void> completeSchedule({
    required String scheduleId,
    required String assetId,
    required String maintenanceTitle,
    required String dateFormatted,
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
      });

      await assetRef.collection('maintenance_history').add({
        'title': maintenanceTitle,
        'date': dateFormatted,
        'cost': 'Rp 0',
        'notes': 'Diselesaikan dari jadwal perawatan.',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Menghapus jadwal perawatan
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
