import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/otp_service.dart';
import '../utils/top_notif.dart';

class PasswordBaruScreen extends StatefulWidget {
  const PasswordBaruScreen({super.key});

  @override
  State<PasswordBaruScreen> createState() => _PasswordBaruScreenState();
}

class _PasswordBaruScreenState extends State<PasswordBaruScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final OtpService _otpService = OtpService();
  bool _obscureText = true;
  bool _isLoading = false;

  String get _email =>
      (ModalRoute.of(context)?.settings.arguments as String?) ?? '';

  Future<void> _handleSavePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      showTopNotif(
        context,
        'Password baru minimal harus terdiri dari 6 karakter.',
        isError: true,
      );
      return;
    }

    if (_email.isEmpty) {
      showTopNotif(
        context,
        'Sesi email tidak ditemukan. Silakan ulangi dari awal.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _otpService.updatePasswordWithOtp(_email, newPassword);

      if (mounted) {
        showTopNotif(
          context,
          'Password baru berhasil disimpan! Silakan masuk.',
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 80,
                      color: Colors.black87,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Masukkan Password Baru',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buat password baru yang kuat dan mudah Anda ingat untuk akun Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Password Baru',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                scrollPadding: const EdgeInsets.only(bottom: 140),
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Masukkan password baru...',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 12.0,
            bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSavePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Simpan Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}