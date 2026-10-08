import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';

/// Halaman login: input NRP dan Password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nrpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nrpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    // Hilangkan keyboard dulu agar error terlihat jelas.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final error = context.read<AuthProvider>().login(
          _nrpController.text,
          _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _errorMessage = error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -90,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -90,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: EdgeInsets.all(isWide ? 40 : 28),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.08),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // ----- Logo & judul -----
                      Center(
                        child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Smart Presensi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Presensi kampus, praktis dalam satu langkah',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // ----- Input NRP -----
                      TextFormField(
                        controller: _nrpController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'NRP',
                          hintText: 'Masukkan NRP Anda',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'NRP tidak boleh kosong';
                          }
                          if (value.trim().length < 6) {
                            return 'NRP minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ----- Input Password -----
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Masukkan password Anda',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password tidak boleh kosong';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),

                      // ----- Pesan error dari provider (mis. gagal login API) -----
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFB42318)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // ----- Tombol Login -----
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.gradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: auth.isLoggedIn ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Masuk',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
