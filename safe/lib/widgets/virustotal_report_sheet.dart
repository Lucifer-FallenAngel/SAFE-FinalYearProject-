import 'package:flutter/material.dart';

class VirusTotalReportSheet extends StatelessWidget {
  final Map<String, dynamic> scan;

  const VirusTotalReportSheet({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final vendors = (scan['vendors'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final malwareTypes = (scan['malwareTypes'] as List<dynamic>? ?? [])
        .cast<String>();

    final stats = Map<String, dynamic>.from(scan['stats'] as Map? ?? {});

    final isSafe = scan['isSafe'] == true;
    final positives = scan['positives'] ?? 0;
    final totalEngines = scan['totalEngines'] ?? vendors.length;

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
            "Detected by $positives of $totalEngines security engines",
            style: const TextStyle(fontSize: 14),
          ),

          if (!isSafe && stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Malicious: ${stats['malicious'] ?? 0}, "
                "Suspicious: ${stats['suspicious'] ?? 0}",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          /// 🧬 MALWARE TYPES
          if (malwareTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: malwareTypes.map<Widget>((type) {
                  return Chip(
                    label: Text(
                      type.toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.red.shade100,
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          /// 🧪 VENDOR LIST
          const Text(
            'Detection Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: vendors.isEmpty
                ? const Center(
                    child: Text(
                      "No vendor detections available",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
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
                        title: Text(
                          v['vendor'] ?? 'Unknown Vendor',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: result != null
                            ? Text(
                                result,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w500,
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
