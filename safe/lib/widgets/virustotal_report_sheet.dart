import 'package:flutter/material.dart';

class VirusTotalReportSheet extends StatelessWidget {
  final Map<String, dynamic> scan;

  const VirusTotalReportSheet({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final vendors = (scan['vendors'] ?? []) as List<dynamic>;
    final isSafe = scan['isSafe'] == true;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔴 HEADER
          Row(
            children: [
              Icon(
                isSafe ? Icons.verified : Icons.warning_amber_rounded,
                color: isSafe ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isSafe ? 'Safe Content' : 'Suspicious Content',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (scan['cached'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CACHED',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          /// 📊 SUMMARY
          Text(
            "Detected by ${scan['positives']} of ${scan['total']} vendors",
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 16),

          /// 🧪 VENDOR LIST
          const Text(
            'Detection Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              itemCount: vendors.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final v = vendors[index];
                final category = v['category'];
                final result = v['result'];

                Color color;
                IconData icon;

                switch (category) {
                  case 'malicious':
                    color = Colors.red;
                    icon = Icons.dangerous;
                    break;
                  case 'suspicious':
                    color = Colors.orange;
                    icon = Icons.warning;
                    break;
                  default:
                    color = Colors.green;
                    icon = Icons.check_circle;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(v['vendor']),
                  subtitle: result != null
                      ? Text(
                          result,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const Text('No threat detected'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
