import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'successful.dart';

class UploadPicPage extends StatefulWidget {
  const UploadPicPage({super.key});

  @override
  State<UploadPicPage> createState() => _UploadPicPageState();
}

class _UploadPicPageState extends State<UploadPicPage> {
  final ImagePicker _picker = ImagePicker();
  File? selectedImage;
  bool isUploading = false;

  // ⚠️ CHANGE THIS TO YOUR SERVER IP
  final String baseUrl = 'http://10.0.2.2:5000';

  // ⚠️ REPLACE WITH ACTUAL LOGGED-IN USER ID
  final int userId = 1;

  /* ============================
     PICK IMAGE
  ============================ */
  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
    });

    await uploadProfilePic();
  }

  /* ============================
     UPLOAD PROFILE PIC
  ============================ */
  Future<void> uploadProfilePic() async {
    if (selectedImage == null) return;

    setState(() => isUploading = true);

    try {
      final uri = Uri.parse('$baseUrl/api/users/upload-profile-pic');

      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_pic', // MUST MATCH multer field
          selectedImage!.path,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SuccessfulPage(isSuccess: true),
          ),
        );
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture upload failed')),
      );
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  /* ============================
     BOTTOM SHEET
  ============================ */
  void showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose From',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _optionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      pickImage(ImageSource.camera);
                    },
                  ),
                  _optionButton(
                    icon: Icons.photo,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _optionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.green)),
        ],
      ),
    );
  }

  /* ============================
     UI
  ============================ */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 40),
                Image.asset('images/upload_pic/upload_pic.png', height: 220),
                const SizedBox(height: 30),
                const Text(
                  'Upload a Profile Photo to\nComplete Registration',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isUploading ? null : showPickerOptions,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Upload',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),

            // LOADING OVERLAY
            if (isUploading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
