import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'get_started.dart';
import 'dashboard.dart';
import 'ngrok_url_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

///
/// 🔐 AUTH + BACKEND GATE
/// 1️⃣ Ensures backend (ngrok) URL exists
/// 2️⃣ Handles auto-login
///
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _loading = true;
  bool _isLoggedIn = false;

  String? userId;
  String? userName;
  String? profilePic;
  String? backendUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 🔁 App bootstrap logic
  Future<void> _bootstrap() async {
    // 1️⃣ CHECK BACKEND URL FIRST
    backendUrl = await _storage.read(key: 'backend_base_url');

    if (backendUrl == null || backendUrl!.isEmpty) {
      // 🚨 No backend configured
      setState(() => _loading = false);
      return;
    }

    // 2️⃣ CHECK LOGIN SESSION
    final token = await _storage.read(key: 'auth_token');
    userId = await _storage.read(key: 'user_id');
    userName = await _storage.read(key: 'user_name');
    profilePic = await _storage.read(key: 'profile_pic');

    if (token != null &&
        token.isNotEmpty &&
        userId != null &&
        userName != null) {
      _isLoggedIn = true;
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // ⏳ Splash screen
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    // 🌍 NO BACKEND URL → ASK FOR NGROK
    if (backendUrl == null || backendUrl!.isEmpty) {
      return const NgrokUrlScreen();
    }

    // ✅ AUTO LOGIN
    if (_isLoggedIn) {
      return DashboardPage(
        userId: int.parse(userId!),
        userName: userName!,
        profilePic: profilePic,
      );
    }

    // ❌ NOT LOGGED IN
    return const GetStarted();
  }
}

//7837746398
