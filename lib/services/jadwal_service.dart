import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JadwalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login.');
    }
    return user.uid;
  }

  CollectionReference get _schedulesRef =>
      _firestore.collection('users').doc(_uid).collection('schedules');

  CollectionReference get _assetsRef =>
      _firestore.collection('users').doc(_uid).collection('assets');

  // Stream daftar jadwal aktif
  Stream<QuerySnapshot> streamJadwalAktif() {
    return _schedulesRef
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  // Stream daftar barang milik pengguna untuk dropdown
  Stream<QuerySnapshot> streamDaftarBarang() {
    return _assetsRef.orderBy('name', descending: false).snapshots();
  }

  // Tambah jadwal baru
  Future<void> tambahJadwal({
    required String title,
    required String assetId,
    required String assetName,
    required DateTime scheduledAt,
    required String maintenanceType,
    String notes = '',
  }) async {
    await _schedulesRef.add({
      'title': title.trim(),
      'assetId': assetId,
      'assetName': assetName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'maintenanceType': maintenanceType,
      'notes': notes.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Perbarui detail jadwal
  Future<void> updateJadwal({
    required String scheduleId,
    required String title,
    required String assetId,
    required String assetName,
    required DateTime scheduledAt,
    required String maintenanceType,
    String notes = '',
  }) async {
    await _schedulesRef.doc(scheduleId).update({
      'title': title.trim(),
      'assetId': assetId,
      'assetName': assetName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'maintenanceType': maintenanceType,
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Hapus jadwal
  Future<void> hapusJadwal(String scheduleId) async {
    await _schedulesRef.doc(scheduleId).delete();
  }

  // Tandai jadwal selesai dan pindahkan ke riwayat perawatan aset
  Future<void> tandaiSelesai({
    required String scheduleId,
    required Map<String, dynamic> scheduleData,
    required double cost,
    String completionNotes = '',
  }) async {
    final batch = _firestore.batch();
    final scheduleDoc = _schedulesRef.doc(scheduleId);

    batch.update(scheduleDoc, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final String assetId = (scheduleData['assetId'] ?? '').toString();
    final String finalNotes = completionNotes.trim().isNotEmpty
        ? completionNotes.trim()
        : (scheduleData['notes'] ?? '').toString();

    if (assetId.isNotEmpty) {
      final maintenanceDoc =
          _assetsRef.doc(assetId).collection('maintenance').doc();

      batch.set(maintenanceDoc, {
        'scheduleId': scheduleId,
        'title': scheduleData['title'] ?? '',
        'assetId': assetId,
        'assetName': scheduleData['assetName'] ?? '',
        'maintenanceType': scheduleData['maintenanceType'] ?? 'Perawatan',
        'cost': cost,
        'notes': finalNotes,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}