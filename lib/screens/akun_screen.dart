import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/asset_service.dart';
import '../services/auth_service.dart';
import '../utils/top_notif.dart';
import 'login_screen.dart';

class AkunScreen extends StatefulWidget {
  const AkunScreen({super.key});

  @override
  State<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends State<AkunScreen> {
  final AuthService _authService = AuthService();
  final AssetService _assetService = AssetService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _confirmLogout() async {
    final isDark = appThemeNotifier.value == ThemeMode.dark;
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Keluar Akun',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Keepora?',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004AAD),
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showEditProfileDialog(String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final isDark = appThemeNotifier.value == ThemeMode.dark;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nama Lengkap',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama lengkap...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) return;

                      setDialogState(() => isSaving = true);
                      try {
                        final user = _auth.currentUser;
                        if (user != null) {
                          await user.updateDisplayName(newName);
                          await _firestore.collection('users').doc(user.uid).set(
                            {
                              'name': newName,
                              'updatedAt': FieldValue.serverTimestamp(),
                            },
                            SetOptions(merge: true),
                          );
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          setState(() {});
                          showTopNotif(
                            this.context,
                            'Profil berhasil diperbarui.',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          showTopNotif(
                            this.context,
                            'Gagal memperbarui profil: $e',
                            isError: true,
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004AAD),
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final isDark = appThemeNotifier.value == ThemeMode.dark;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Ubah Password',
            style: GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password Baru (min. 6 karakter)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final pass = newPassController.text.trim();
                      final confirm = confirmPassController.text.trim();
                      if (pass.length < 6) {
                        showTopNotif(
                          this.context,
                          'Password minimal 6 karakter.',
                          isError: true,
                        );
                        return;
                      }
                      if (pass != confirm) {
                        showTopNotif(
                          this.context,
                          'Konfirmasi password tidak cocok.',
                          isError: true,
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await _auth.currentUser?.updatePassword(pass);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          showTopNotif(
                            this.context,
                            'Password berhasil diperbarui.',
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        if (mounted) {
                          showTopNotif(
                            this.context,
                            e.code == 'requires-recent-login'
                                ? 'Silakan login ulang terlebih dahulu untuk mengubah password.'
                                : 'Gagal mengubah password: ${e.message}',
                            isError: true,
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004AAD),
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Perbarui'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMaintenanceData() async {
    try {
      final docs = await _assetService.getAllMaintenanceHistoryStream().first;
      if (docs.isEmpty) {
        if (mounted) {
          showTopNotif(
            context,
            'Belum ada data riwayat untuk diekspor.',
            isError: true,
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('LAPORAN RIWAYAT PERAWATAN KEEPORA');
      buffer.writeln('Total Catatan: ${docs.length}');
      buffer.writeln('----------------------------------------');
      for (int i = 0; i < docs.length; i++) {
        final data = docs[i].data() as Map<String, dynamic>? ?? {};
        final title =
            (data['title'] ?? data['detail'] ?? 'Perawatan').toString();
        final assetName = (data['assetName'] ?? '-').toString();
        final type = (data['maintenanceType'] ?? 'Perawatan').toString();
        final cost = (data['cost'] ?? '0').toString();
        buffer.writeln('${i + 1}. $title ($assetName) | $type | Biaya: Rp $cost');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        showTopNotif(
          context,
          'Laporan ${docs.length} riwayat perawatan berhasil disalin ke clipboard.',
        );
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(
          context,
          'Gagal mengekspor data: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final user = _auth.currentUser;
    final fallbackName =
        (user?.displayName != null && user!.displayName!.isNotEmpty)
            ? user.displayName!
            : (user?.email?.split('@').first ?? 'Pengguna Keepora');
    final email = user?.email ?? '-';

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
        final cardBgColor =
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6);
        final borderColor =
            isDark ? Colors.grey.shade800 : Colors.grey.shade400;
        final titleColor = isDark ? Colors.white : Colors.black87;
        final itemTextColor = isDark ? Colors.white70 : Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              'Pengaturan Akun',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: user != null
                ? _firestore.collection('users').doc(user.uid).snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              final userData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final displayName =
                  (userData['name'] ?? fallbackName).toString();

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1D5DB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () =>
                                      _showEditProfileDialog(displayName),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Edit Profile',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withValues(alpha: 0.95),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.edit_square,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Laporan & Tampilan',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: Icons.file_download_outlined,
                      label: 'Ekspor Laporan PDF',
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textColor: itemTextColor,
                      onTap: _exportMaintenanceData,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: itemTextColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: isDark
                          ? Icons.dark_mode_outlined
                          : Icons.wb_sunny_outlined,
                      label: 'Tampilan',
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textColor: itemTextColor,
                      onTap: () {
                        appThemeNotifier.value =
                            isDark ? ThemeMode.light : ThemeMode.dark;
                      },
                      trailing: SizedBox(
                        height: 28,
                        child: Switch(
                          value: isDark,
                          activeColor: Colors.white,
                          activeTrackColor: primaryBlue,
                          onChanged: (value) {
                            appThemeNotifier.value =
                                value ? ThemeMode.dark : ThemeMode.light;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Akun & Keamanan',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: Icons.settings_outlined,
                      label: 'Ubah Password',
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textColor: itemTextColor,
                      onTap: _showChangePasswordDialog,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: itemTextColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 36),

                    InkWell(
                      onTap: _confirmLogout,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFEF4444),
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: GoogleFonts.montserrat(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required Color cardBgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
    required Widget trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}