import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          return _IsiAbout(packageInfo: snapshot.data);
        },
      ),
    );
  }
}

class _IsiAbout extends StatelessWidget {
  const _IsiAbout({required this.packageInfo});

  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appName = packageInfo?.appName ?? 'Alana';
    final version = packageInfo?.version ?? '-';
    final buildNumber = packageInfo?.buildNumber ?? '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Versi $version • Build $buildNumber',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text(
          'Alana adalah aplikasi pembaca manhwa untuk membantu kamu '
          'menemukan judul, menyimpan favorit, dan melanjutkan bacaan '
          'dengan nyaman.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        const Divider(),
        Text('Tautan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        _Tautan(
          icon: Icons.cloud_outlined,
          judul: 'Sumber data',
          deskripsi: 'API metadata dan chapter manhwa',
          url: 'https://api.shngm.io',
        ),
        _Tautan(
          icon: Icons.mail_outline,
          judul: 'Kontak developer',
          deskripsi: 'Ganti dengan email resmi developer',
          url: 'mailto:developer@example.com',
        ),
        _Tautan(
          icon: Icons.privacy_tip_outlined,
          judul: 'Kebijakan privasi',
          deskripsi: 'Ganti dengan URL kebijakan privasi aplikasi',
          url: 'https://example.com/privacy',
        ),
        _Tautan(
          icon: Icons.delete_outline,
          judul: 'Hapus akun',
          deskripsi: 'Ganti dengan URL GitHub Pages resmi',
          url: 'https://example.com/account-deletion',
        ),
        const Divider(),
        OutlinedButton.icon(
          onPressed: () {
            showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: '$version+$buildNumber',
              applicationLegalese: 'Lisensi paket dan aplikasi',
            );
          },
          icon: const Icon(Icons.article_outlined),
          label: const Text('Lisensi Open Source'),
        ),
        const SizedBox(height: 20),
        Text('Paket utama', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const _TautanPaket(
          nama: 'package_info_plus',
          url: 'https://pub.dev/packages/package_info_plus',
        ),
        const _TautanPaket(
          nama: 'url_launcher',
          url: 'https://pub.dev/packages/url_launcher',
        ),
        const _TautanPaket(
          nama: 'flutter_riverpod',
          url: 'https://pub.dev/packages/flutter_riverpod',
        ),
      ],
    );
  }
}

class _Tautan extends StatelessWidget {
  const _Tautan({
    required this.icon,
    required this.judul,
    required this.deskripsi,
    required this.url,
  });

  final IconData icon;
  final String judul;
  final String deskripsi;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(judul),
      subtitle: Text(deskripsi),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _bukaTautan(context, url),
    );
  }
}

class _TautanPaket extends StatelessWidget {
  const _TautanPaket({required this.nama, required this.url});

  final String nama;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.code),
      title: Text(nama),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _bukaTautan(context, url),
    );
  }
}

Future<void> _bukaTautan(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || berhasil) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Tautan tidak dapat dibuka.')));
}
