import 'package:flutter/material.dart';

import 'utils/api_helper.dart';
import 'utils/secure_storage.dart';

import 'get_started.dart';
import 'signup.dart';
import 'dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool loading = false;

  @override
  void dispose() {
    mobileController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();

    if (mobile.isEmpty || password.isEmpty) {
      _showError("Please enter mobile number and password");
      return;
    }

    setState(() => loading = true);

    try {
      final response = await ApiHelper.post(
        '/auth/login',
        {"mobile": mobile, "password": password},
        authRequired: false, // ✅ login does not require auth
      );

      if (!mounted) return;
      setState(() => loading = false);

      // ❌ Backend error
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showError("Invalid mobile number or password");
        return;
      }

      // ✅ Decode safely
      final decoded = ApiHelper.handleResponse(response);

      if (decoded == null || decoded['user'] == null) {
        _showError("Invalid server response");
        return;
      }

      final user = decoded['user'];

      // ⚠️ Backend does NOT return JWT → store dummy token
      await SecureStorage.saveLogin(
        token: 'logged_in', // ✅ non-empty token required
        userId: user['id'].toString(),
        userName: user['name'],
        profilePic: user['profile_pic'],
      );

      if (!mounted) return;

      // 🚀 Navigate to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            userId: user['id'],
            userName: user['name'],
            profilePic: user['profile_pic'],
          ),
        ),
      );
    } catch (e) {
      debugPrint("Login error: $e");
      if (!mounted) return;
      setState(() => loading = false);
      _showError("Unable to connect to server");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Login Failed"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget inputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? hidePassword : false,
        keyboardType: hint.contains('Mobile')
            ? TextInputType.phone
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.green),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    hidePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const GetStarted()),
                  );
                },
              ),

              const SizedBox(height: 10),

              const Text(
                'Get Started 🤗',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              const Text(
                'interdum malesuada ante in scelerisque\n'
                'Lorem ipsum dolor sit amet consectetur.',
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 30),

              inputField(
                hint: '+91 Mobile Number',
                icon: Icons.phone,
                controller: mobileController,
              ),

              inputField(
                hint: 'Password',
                icon: Icons.lock,
                controller: passwordController,
                isPassword: true,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: "Didn't have an account? ",
                      children: [
                        TextSpan(
                          text: 'REGISTER NOW',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
