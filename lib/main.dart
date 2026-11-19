import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/navbar_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lupa_password_screen.dart';
import 'screens/verif_otp_screen.dart';
import 'screens/password_baru_screen.dart';

const String _themePrefKey = 'keepora_theme_mode';

// Pengontrol tema global aplikasi (Default mengikuti tema sistem HP)
final ValueNotifier<ThemeMode> appThemeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

// Membaca tema tersimpan sebelum aplikasi dirender
Future<void> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString(_themePrefKey);
  if (savedTheme == 'dark') {
    appThemeNotifier.value = ThemeMode.dark;
  } else if (savedTheme == 'light') {
    appThemeNotifier.value = ThemeMode.light;
  } else {
    appThemeNotifier.value = ThemeMode.system;
  }
}

// Mengubah tema sekaligus menyimpannya ke memori lokal HP
Future<void> setAppTheme(bool isDark) async {
  appThemeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themePrefKey, isDark ? 'dark' : 'light');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await loadSavedTheme();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.robotoTextTheme().copyWith(
      displayLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            textTheme: baseTextTheme,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0056C6),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            textTheme: baseTextTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF121212),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0056C6),
              brightness: Brightness.dark,
            ),
          ),
          debugShowCheckedModeBanner: false,
          title: 'Keepora',
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/splash': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/LupaPassword': (context) => const LupaPasswordScreen(),
            '/verifOTP': (context) => const VerifOtpScreen(),
            '/passwordBaru': (context) => const PasswordBaruScreen(),
            '/home': (context) => const NavbarScreen(),
          },
        );
      },
    );
  }
}

// Widget Penjaga Sesi Login Otomatis
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          User user = snapshot.data!;
          if (user.emailVerified) {
            return const NavbarScreen();
          }
        }

        return const SplashScreen();
      },
    );
  }
}