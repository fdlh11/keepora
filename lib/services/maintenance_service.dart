import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MaintenanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sesi pengguna tidak ditemukan. Silakan masuk kembali.');
    }
    return user.uid;
  }

  DocumentReference _assetDoc(String assetId) =>
      _firestore.collection('users').doc(_uid).collection('assets').doc(assetId);

  CollectionReference _maintenanceCol(String assetId) =>
      _assetDoc(assetId).collection('maintenances');

  // ===========================================================================
  // 1A. CREATE: Buat Jadwal Perawatan Mendatang (Untuk Halaman Jadwal)
  // ===========================================================================
  Future<String> createSchedule({
    required String assetId,
    required String assetName,
    required String title,
    required DateTime scheduledDate,
    required String formattedDate,
    String notes = '',
    int estimatedCost = 0,
  }) async {
    final docRef = await _maintenanceCol(assetId).add({
      'userId': _uid,
      'assetId': assetId,
      'assetName': assetName,
      'title': title.trim(),
      'notes': notes.trim(),
      'cost': estimatedCost,
      'formattedDate': formattedDate,
      'dateTimestamp': Timestamp.fromDate(scheduledDate),
      'status': 'scheduled', // 'scheduled' | 'completed'
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ===========================================================================
  // 1B. CREATE: Catat Perawatan Selesai Langsung (Dari Detail Barang / Riwayat)
  // ===========================================================================
  Future<String> createCompletedMaintenance({
    required String assetId,
    required String assetName,
    required String title,
    required DateTime completedDate,
    required String formattedDate,
    required int cost,
    required String formattedCost,
    String notes = '',
  }) async {
    final WriteBatch batch = _firestore.batch();
    final newMaintenanceRef = _maintenanceCol(assetId).doc();

    batch.set(newMaintenanceRef, {
      'userId': _uid,
      'assetId': assetId,
      'assetName': assetName,
      'title': title.trim(),
      'notes': notes.trim(),
      'cost': cost,
      'formattedCost': formattedCost,
      'formattedDate': formattedDate,
      'dateTimestamp': Timestamp.fromDate(completedDate),
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Otomatis perbarui ringkasan perawatan terakhir pada dokumen barang induk
    batch.update(_assetDoc(assetId), {
      'lastMaintenance': formattedDate,
      'lastMaintenanceCost': formattedCost,
      'maintenanceDetail': notes.trim().isNotEmpty ? notes.trim() : title.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return newMaintenanceRef.id;
  }

  // ===========================================================================
  // 2A. READ: Stream Semua Jadwal Aktif (Diurutkan Tanggal Terdekat)
  // ===========================================================================
  Stream<List> streamScheduledMaintenances() {
    return _firestore
        .collectionGroup('maintenances')
        .where('userId', isEqualTo: _uid)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('dateTimestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // ===========================================================================
  // 2B. READ: Stream Semua Riwayat Perawatan Selesai (Untuk Halaman Riwayat)
  // ===========================================================================
  Stream<List> streamCompletedMaintenances() {
    return _firestore
        .collectionGroup('maintenances')
        .where('userId', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('dateTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // ===========================================================================
  // 2C. READ: Stream Riwayat & Jadwal Khusus 1 Barang Tertentu
  // ===========================================================================
  Stream<List> streamMaintenancesByAsset(String assetId) {
    return _maintenanceCol(assetId)
        .orderBy('dateTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // ===========================================================================
  // 3A. UPDATE: Tandai Jadwal Menjadi Selesai -> Masuk ke Riwayat & Update Barang
  // ===========================================================================
  Future<void> completeScheduledMaintenance({
    required String assetId,
    required String maintenanceId,
    required String title,
    required DateTime completedDate,
    required String formattedDate,
    required int finalCost,
    required String formattedCost,
    String notes = '',
  }) async {
    final WriteBatch batch = _firestore.batch();
    final maintenanceRef = _maintenanceCol(assetId).doc(maintenanceId);

    batch.update(maintenanceRef, {
      'status': 'completed',
      'cost': finalCost,
      'formattedCost': formattedCost,
      'formattedDate': formattedDate,
      'dateTimestamp': Timestamp.fromDate(completedDate),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'completedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_assetDoc(assetId), {
      'lastMaintenance': formattedDate,
      'lastMaintenanceCost': formattedCost,
      'maintenanceDetail': notes.trim().isNotEmpty ? notes.trim() : title.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ===========================================================================
  // 3B. UPDATE: Edit Data Jadwal atau Riwayat Perawatan
  // ===========================================================================
  Future<void> updateMaintenance({
    required String assetId,
    required String maintenanceId,
    String? title,
    String? notes,
    DateTime? date,
    String? formattedDate,
    int? cost,
    String? formattedCost,
  }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title.trim();
    if (notes != null) updates['notes'] = notes.trim();
    if (date != null) updates['dateTimestamp'] = Timestamp.fromDate(date);
    if (formattedDate != null) updates['formattedDate'] = formattedDate;
    if (cost != null) updates['cost'] = cost;
    if (formattedCost != null) updates['formattedCost'] = formattedCost;

    await _maintenanceCol(assetId).doc(maintenanceId).update(updates);
  }

  // ===========================================================================
  // 4. DELETE: Hapus Item Jadwal atau Riwayat Perawatan
  // ===========================================================================
  Future<void> deleteMaintenance({
    required String assetId,
    required String maintenanceId,
  }) async {
    await _maintenanceCol(assetId).doc(maintenanceId).delete();
  }
}