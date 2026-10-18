import 'dart:async';
import 'package:field_survey/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color primaryBlue = Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    Timer(const Duration(seconds: 3), checkAuthAndNavigate);
  }

  Future<void> checkAuthAndNavigate() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon di tengah berwarna biru
            Icon(
              Icons.assignment_outlined, // Bisa diganti Icon lain sesuai kebutuhan
              size: 80,
              color: primaryBlue,
            ),
            SizedBox(height: 24),
            // Indikator loading melingkar berwarna biru
            CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}