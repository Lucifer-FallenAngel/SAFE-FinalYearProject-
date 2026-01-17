import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'utils/secure_storage.dart';
import 'first.dart';

class NgrokUrlScreen extends StatefulWidget {
  const NgrokUrlScreen({super.key});

  @override
  State<NgrokUrlScreen> createState() => _NgrokUrlScreenState();
}

class _NgrokUrlScreenState extends State<NgrokUrlScreen> {
  final TextEditingController controller = TextEditingController();
  bool loading = false;

  Future<void> _saveAndTest() async {
    final input = controller.text.trim();

    if (!input.startsWith('http')) {
      _showError("Enter a valid URL (https://...)");
      return;
    }

    // 🔧 Normalize URL (remove trailing slash)
    final url = input.endsWith('/')
        ? input.substring(0, input.length - 1)
        : input;

    setState(() => loading = true);

    try {
      // 🔍 Health check
      final res = await http
          .get(Uri.parse("$url/api/auth/ping"))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        // ✅ SAVE BACKEND URL (THIS WAS MISSING)
        await SecureStorage.saveBackendUrl(url);

        if (!mounted) return;

        // 🚀 Continue to app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FirstScreen()),
        );
      } else {
        _showError("Server responded but is not healthy");
      }
    } on TimeoutException {
      _showError("Connection timeout. Check ngrok URL.");
    } catch (_) {
      _showError("Failed to connect to server");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invalid Server"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Server URL"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your backend (ngrok) URL",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: "https://xxxx.ngrok-free.app",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _saveAndTest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
