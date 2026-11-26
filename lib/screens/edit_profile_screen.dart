import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../utils/top_notif.dart';

class EditProfilScreen extends StatefulWidget {
  final String initialName;
  final String initialBirthDate;
  final String initialPhotoUrl;
  final String email;

  const EditProfilScreen({
    super.key,
    required this.initialName,
    this.initialBirthDate = '',
    this.initialPhotoUrl = '',
    required this.email,
  });

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  File? _newImageFile;
  late String _currentPhotoUrl;
  Uint8List? _cachedPhotoBytes;
  late String _verifiedEmail;

  bool _isSaving = false;
  bool _isProcessingEmail = false;
  bool _isCheckingSync = false;
  bool _emailUpdated = false;

  String? _nameError;
  String? _emailError;
  String? _pendingNewEmail;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifiedEmail = widget.email.trim();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: _verifiedEmail);
    _currentPhotoUrl = widget.initialPhotoUrl;
    _decodeInitialPhotoOnce();
    _loadPendingEmail();
  }

  void _decodeInitialPhotoOnce() {
    if (_currentPhotoUrl.startsWith('data:image')) {
      try {
        final base64Part = _currentPhotoUrl.split(',').last;
        _cachedPhotoBytes = base64Decode(base64Part);
      } catch (_) {
        _cachedPhotoBytes = null;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _autoSyncTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingNewEmail != null) {
      _checkAndSyncNewEmail();
    }
  }

  void _startAutoSyncPolling() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _pendingNewEmail == null) {
        _autoSyncTimer?.cancel();
        return;
      }
      _checkAndSyncNewEmail();
    });
  }

  Future<void> _loadPendingEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final pending = doc.data()?['pendingNewEmail'];
      if (pending is String && pending.isNotEmpty && mounted) {
        setState(() {
          _pendingNewEmail = pending;
          _emailController.text = pending;
        });
        await _checkAndSyncNewEmail();
        if (_pendingNewEmail != null) {
          _startAutoSyncPolling();
        }
      }
    } catch (_) {}
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  bool get _hasUnsavedChanges {
    return _nameController.text.trim() != widget.initialName.trim() ||
        _newImageFile != null ||
        _currentPhotoUrl != widget.initialPhotoUrl;
  }

  bool _isEmailDifferent(String text) {
    final typed = text.trim().toLowerCase();
    return typed.isNotEmpty && typed != _verifiedEmail.toLowerCase();
  }

  bool _isValidEmailFormat(String email) {
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  Widget _buildErrorText(String? errorText) {
    if (errorText == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        errorText,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _sendVerificationLinkDirectly() async {
    final targetEmail = _pendingNewEmail ?? _emailController.text.trim();

    if (targetEmail.isEmpty) {
      setState(() => _emailError = 'Alamat email baru wajib diisi');
      return;
    }
    if (!_isValidEmailFormat(targetEmail)) {
      setState(() => _emailError = 'Format alamat email tidak valid');
      return;
    }
    if (targetEmail.toLowerCase() == _verifiedEmail.toLowerCase()) {
      setState(
        () => _emailError = 'Email baru harus berbeda dari email saat ini',
      );
      return;
    }

    setState(() {
      _emailError = null;
      _isProcessingEmail = true;
    });

    try {
      await _authService.requestEmailChange(newEmail: targetEmail);
      if (mounted) {
        setState(() => _pendingNewEmail = targetEmail);
        _startCooldown(60);
        _startAutoSyncPolling();
        showTopNotif(
          context,
          'Link verifikasi dikirim ke $targetEmail. Cek inbox atau folder spam email baru Anda.',
        );
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingEmail = false);
    }
  }

  Future<void> _checkAndSyncNewEmail() async {
    if (_isCheckingSync) return;
    _isCheckingSync = true;

    try {
      final updatedEmail = await _authService.syncUpdatedEmailIfVerified();
      if (!mounted) return;

      if (updatedEmail != null && updatedEmail.isNotEmpty) {
        _autoSyncTimer?.cancel();
        _cooldownTimer?.cancel();
        setState(() {
          _verifiedEmail = updatedEmail;
          _emailController.text = updatedEmail;
          _pendingNewEmail = null;
          _emailUpdated = true;
          _resendCooldown = 0;
        });
        showTopNotif(
          context,
          'Email berhasil diverifikasi dan diperbarui menjadi $updatedEmail.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' && mounted) {
        _autoSyncTimer?.cancel();
        if (_pendingNewEmail != null) {
          final uid = _auth.currentUser?.uid;
          if (uid != null) {
            await _firestore.collection('users').doc(uid).set({
              'email': _pendingNewEmail,
              'is_verified': true,
              'pendingNewEmail': FieldValue.delete(),
            }, SetOptions(merge: true));
          }
        }
        await _authService.signOut();
        if (mounted) {
          showTopNotif(
            context,
            'Email berhasil diganti! Silakan login kembali menggunakan email baru Anda.',
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (_) {
    } finally {
      _isCheckingSync = false;
    }
  }

  Future<void> _cancelPendingEmail() async {
    _autoSyncTimer?.cancel();
    _cooldownTimer?.cancel();
    await _authService.cancelPendingEmailChange();
    if (mounted) {
      setState(() {
        _pendingNewEmail = null;
        _resendCooldown = 0;
        _emailError = null;
        _emailController.text = _verifiedEmail;
      });
      showTopNotif(context, 'Perubahan email dibatalkan.');
    }
  }

  // format pilih gambar
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _newImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(
          context,
          'Gagal mengambil foto: $e',
          isError: true,
        );
      }
    }
  }

  void _showPhotoOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final iconBg = isDark
        ? const Color(0xFF004AAD).withValues(alpha: 0.25)
        : const Color(0xFFDBEAFE);
    final iconColor =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF004AAD);
    final hasPhoto = _newImageFile != null || _currentPhotoUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(
                  'Ganti Foto Profil',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt_outlined, color: iconColor),
                  ),
                  title: Text(
                    'Ambil Foto dari Kamera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library_outlined, color: iconColor),
                  ),
                  title: Text(
                    'Pilih dari Galeri',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 6),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                      ),
                    ),
                    title: Text(
                      'Hapus Foto Profil',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red.shade400,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _newImageFile = null;
                        _currentPhotoUrl = '';
                        _cachedPhotoBytes = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context, _emailUpdated);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Perubahan Belum Disimpan',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar tanpa menyimpan?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004AAD),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Lanjutkan Edit',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF004AAD),
                          side: const BorderSide(
                            color: Color(0xFF64A1F4),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Keluar',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.pop(context, _emailUpdated);
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _nameError = 'Nama lengkap wajib diisi');
      return;
    }
    setState(() => _nameError = null);

    if (_isEmailDifferent(_emailController.text) && _pendingNewEmail == null) {
      await _sendVerificationLinkDirectly();
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      showTopNotif(context, 'Sesi pengguna tidak ditemukan.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      String finalPhotoUrl = _currentPhotoUrl;
      if (_newImageFile != null) {
        final bytes = await _newImageFile!.readAsBytes();
        final base64Str = base64Encode(bytes);
        finalPhotoUrl = 'data:image/jpeg;base64,$base64Str';
      }

      await user.updateDisplayName(newName);
      await _firestore.collection('users').doc(user.uid).set(
        {
          'name': newName,
          'photoUrl': finalPhotoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        showTopNotif(context, 'Profil berhasil diperbarui.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(
          context,
          'Gagal memperbarui profil: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatarContent() {
    if (_newImageFile != null) {
      return ClipOval(
        child: Image.file(
          _newImageFile!,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    if (_cachedPhotoBytes != null) {
      return ClipOval(
        child: Image.memory(
          _cachedPhotoBytes!,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    if (_currentPhotoUrl.isNotEmpty &&
        !_currentPhotoUrl.startsWith('data:image')) {
      return ClipOval(
        child: Image.network(
          _currentPhotoUrl,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    bool readOnly = false,
    bool hasError = false,
    Widget? suffixIcon,
  }) {
    final fillColor = isDark
        ? (readOnly ? const Color(0xFF181818) : const Color(0xFF1E1E1E))
        : (readOnly ? const Color(0xFFECEEF1) : const Color(0xFFF3F4F6));
    final defaultBorder =
        isDark ? Colors.grey.shade800 : Colors.grey.shade400;
    final activeBorder = hasError ? Colors.redAccent : defaultBorder;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
      filled: true,
      fillColor: fillColor,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: activeBorder,
          width: hasError ? 1.3 : 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError
              ? Colors.redAccent
              : (readOnly ? defaultBorder : const Color(0xFF004AAD)),
          width: readOnly ? 1.0 : 1.4,
        ),
      ),
    );
  }

  Widget _buildAutoWaitingBanner(bool isDark) {
    if (_pendingNewEmail == null) return const SizedBox.shrink();

    const accentColor = Color(0xFF004AAD);
    final cardBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
        : const Color(0xFFBFDBFE);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? const Color(0xFF60A5FA) : accentColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Menunggu klik link verifikasi...',
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isProcessingEmail ? null : _cancelPendingEmail,
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan buka inbox atau folder spam $_pendingNewEmail dan klik link verifikasi. Email akan otomatis diperbarui setelah link diklik.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (_isProcessingEmail || _resendCooldown > 0)
                ? null
                : _sendVerificationLinkDirectly,
            child: Text(
              _resendCooldown > 0
                  ? 'Kirim ulang link dalam ${_resendCooldown}d'
                  : 'Kirim ulang link verifikasi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (_isProcessingEmail || _resendCooldown > 0)
                    ? Colors.grey.shade500
                    : (isDark ? const Color(0xFF60A5FA) : accentColor),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary =
        isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final linkBlue = isDark ? const Color(0xFF60A5FA) : primaryBlue;
    final isEmailLocked = _pendingNewEmail != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: _isSaving ? null : _handleBackPress,
            icon: Icon(Icons.arrow_back, color: textPrimary),
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      RepaintBoundary(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _showPhotoOptionsSheet,
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF374151)
                                  : const Color(0xFFD1D5DB),
                              shape: BoxShape.circle,
                            ),
                            child: _buildAvatarContent(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _isSaving ? null : _showPhotoOptionsSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Klik untuk mengganti Foto',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: linkBlue,
                              decoration: TextDecoration.underline,
                              decorationColor: linkBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Nama Lengkap',
                  style: GoogleFonts.montserrat(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  style: TextStyle(fontSize: 14, color: textSecondary),
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() {
                        _nameError = _nameController.text.trim().isEmpty
                            ? 'Nama lengkap wajib diisi'
                            : null;
                      });
                    }
                  },
                  decoration: _inputDecoration(
                    hint: 'Masukkan nama lengkap...',
                    isDark: isDark,
                    hasError: _nameError != null,
                  ),
                ),
                _buildErrorText(_nameError),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Email',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    if (_pendingNewEmail == null)
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Terverifikasi',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _emailController,
                  builder: (context, value, _) {
                    final showVerifyBtn =
                        _isEmailDifferent(value.text) && !isEmailLocked;
                    return TextField(
                      controller: _emailController,
                      readOnly: isEmailLocked || _isSaving,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: 14, color: textSecondary),
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                      decoration: _inputDecoration(
                        hint: 'Masukkan alamat email baru...',
                        isDark: isDark,
                        readOnly: isEmailLocked,
                        hasError: _emailError != null,
                        suffixIcon: showVerifyBtn
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TextButton(
                                  onPressed: _isProcessingEmail
                                      ? null
                                      : _sendVerificationLinkDirectly,
                                  style: TextButton.styleFrom(
                                    foregroundColor: linkBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: _isProcessingEmail
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Verifikasi',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                _buildErrorText(_emailError),
                _buildAutoWaitingBanner(isDark),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Perbarui',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}