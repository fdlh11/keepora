import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Registrasi Akun + Kirim Link Verifikasi Email
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.sendEmailVerification();

        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': name ?? 'Pengguna Keepora',
          'email': email,
          'role': 'user',
          'is_verified': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Gagal mendaftarkan akun. Silakan coba lagi.';
    }
  }

  // Login - wajib email terverifikasi
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.reload();
      User? updatedUser = _auth.currentUser;

      if (updatedUser != null && !updatedUser.emailVerified) {
        await updatedUser.sendEmailVerification();
        await _auth.signOut();
        throw 'Email Anda belum diverifikasi. Kami telah mengirimkan ulang tautan verifikasi ke email asli Anda. Silakan periksa inbox/spam email Anda.';
      }

      // Sinkronkan email & status verified terbaru ke Firestore saat login
      if (updatedUser != null && updatedUser.emailVerified) {
        await _firestore.collection('users').doc(updatedUser.uid).set({
          'email': updatedUser.email ?? email,
          'is_verified': true,
          'pendingNewEmail': FieldValue.delete(),
        }, SetOptions(merge: true));
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal masuk. Silakan coba lagi.';
    }
  }

  // Opsi 1: Ganti Email Langsung Tanpa Dialog Password
  Future<void> requestEmailChange({required String newEmail}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw 'Sesi pengguna tidak ditemukan. Silakan login ulang.';
    }

    final cleanNewEmail = newEmail.trim();
    if (user.email!.trim().toLowerCase() == cleanNewEmail.toLowerCase()) {
      throw 'Email baru tidak boleh sama dengan email saat ini.';
    }

    try {
      await user.reload();
      final freshUser = _auth.currentUser ?? user;
      await freshUser.verifyBeforeUpdateEmail(cleanNewEmail);

      await _firestore.collection('users').doc(freshUser.uid).set({
        'pendingNewEmail': cleanNewEmail,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal mengirim link verifikasi email.';
    }
  }

  // Sinkronkan email baru ke Firestore secara otomatis setelah link diklik
  Future<String?> syncUpdatedEmailIfVerified() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired') {
        rethrow;
      }
    }

    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) return null;

    final doc =
        await _firestore.collection('users').doc(refreshedUser.uid).get();
    final currentFirestoreEmail = (doc.data()?['email'] ?? '').toString();
    final authEmail = refreshedUser.email ?? '';

    if (authEmail.isNotEmpty && authEmail != currentFirestoreEmail) {
      await _firestore.collection('users').doc(refreshedUser.uid).set({
        'email': authEmail,
        'is_verified': true,
        'pendingNewEmail': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return authEmail;
    }

    return null;
  }

  Future<void> cancelPendingEmailChange() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'pendingNewEmail': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Lupa Password
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Gagal mengirim email reset password.';
    }
  }

  // Keluar Akun
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper pesan error Bahasa Indonesia baku
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email tidak terdaftar. Silakan periksa kembali.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password yang Anda masukkan salah.';
      case 'email-already-in-use':
        return 'Email baru ini sudah digunakan oleh akun lain.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'invalid-email':
        return 'Format email tidak valid atau domain email tidak dapat digunakan.';
      case 'requires-recent-login':
        return 'Sesi login Anda sudah terlalu lama. Silakan logout dan login ulang terlebih dahulu untuk mengganti email.';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan pengiriman email. Tunggu beberapa saat lalu coba lagi.';
      default:
        return 'Terjadi kesalahan pada layanan autentikasi (${e.code}).';
    }
  }
}