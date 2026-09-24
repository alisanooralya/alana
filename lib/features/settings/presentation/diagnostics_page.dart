import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alana/core/diagnostics/error_log.dart';

/// Halaman Diagnostik: status penyimpanan + log error perangkat.
///
/// Log bisa disalin dan ditempel ke pengembang tanpa PC, kabel,
/// atau WiFi — cukup dari HP ini.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Future<String> _file = ErrorLog.bacaFile();

  void _muatUlang() {
    setState(() => _file = ErrorLog.bacaFile());
  }

  Future<void> _salinSemua(String tambahan) async {
    final memori = ErrorLog.entries
        .map(
          (e) => '[${e.waktu.toIso8601String()}] ${e.ringkasan}\n${e.detail}',
        )
        .join('\n---\n');
    final semua = [
      if (memori.isNotEmpty) '=== SESI INI ===\n$memori',
      if (tambahan.isNotEmpty) '=== TERSIMPAN ===\n$tambahan',
    ].join('\n\n');
    await Clipboard.setData(
      ClipboardData(text: semua.isEmpty ? 'Belum ada error tercatat.' : semua),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Log disalin ke clipboard.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostik'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _muatUlang,
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: ErrorLog.versi,
        builder: (context, _, __) {
          final entries = ErrorLog.entries;
          return FutureBuilder<String>(
            future: _file,
            builder: (context, snapshot) {
              final tersimpan = snapshot.data ?? '';
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Error sesi ini (${entries.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Text('Belum ada error tercatat sesi ini.')
                  else
                    for (final entry in entries.reversed)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.waktu.toString().split('.').first,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(entry.ringkasan),
                              if (entry.detail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  entry.detail.length > 800
                                      ? '${entry.detail.substring(0, 800)}…'
                                      : entry.detail,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text(
                    'Log tersimpan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tersimpan.isEmpty
                        ? 'Belum ada log tersimpan.'
                        : tersimpan.length > 2000
                        ? '…${tersimpan.substring(tersimpan.length - 2000)}'
                        : tersimpan,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _salinSemua(tersimpan),
                          icon: const Icon(Icons.copy),
                          label: const Text('Salin semua'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ErrorLog.bersihkan();
                            _muatUlang();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Hapus log'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
