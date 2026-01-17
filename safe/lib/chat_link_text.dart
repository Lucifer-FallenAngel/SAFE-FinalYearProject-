import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatLinkText extends StatelessWidget {
  final String text;
  final bool isMe;

  const ChatLinkText({super.key, required this.text, required this.isMe});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Linkify(
      text: text,
      onOpen: (link) => _openLink(link.url),
      style: TextStyle(fontSize: 15, color: isMe ? Colors.black : Colors.black),
      linkStyle: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
