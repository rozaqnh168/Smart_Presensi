import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'theme/colors.dart';

void main() {
  runApp(const SmartPresensiApp());
}

class SmartPresensiApp extends StatelessWidget {
  const SmartPresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Smart Presensi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: AppColors.cardWhite,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textDark,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8F9FD),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Mengarahkan ke LoginPage atau DashboardPage sesuai status login.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoggedIn ? const DashboardPage() : const LoginPage(),
    );
  }
}
