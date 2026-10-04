import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _tautanPengembang = 'alisaadev@gmail.com';
const String _tautanPrivasi = 'https://alisanooralya.github.io/alana/privacy/';
const String _tautanHapusAkun =
    'https://alisanooralya.github.io/alana/delete-account/';

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
    final appName = packageInfo?.appName ?? 'Alana';
    final version = packageInfo?.version ?? '-';
    final buildNumber = packageInfo?.buildNumber ?? '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/splash_logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
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
          'Alana — aplikasi baca manhwa yang simpel, nyaman, dan praktis. '
          'Temukan cerita favoritmu dan baca kapan saja.',
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
          url: 'https://11.shinigami.asia/',
        ),
        if (_tautanPengembang.isNotEmpty)
          _Tautan(
            icon: Icons.mail_outline,
            judul: 'Kontak developer',
            deskripsi: _tautanPengembang,
            url: 'mailto:$_tautanPengembang',
          ),
        if (_tautanPrivasi.isNotEmpty)
          _Tautan(
            icon: Icons.privacy_tip_outlined,
            judul: 'Kebijakan privasi',
            deskripsi: 'Kebijakan privasi aplikasi Alana',
            url: _tautanPrivasi,
          ),
        if (_tautanHapusAkun.isNotEmpty)
          _Tautan(
            icon: Icons.delete_outline,
            judul: 'Hapus akun',
            deskripsi: 'Cara menghapus akun di aplikasi ini',
            url: _tautanHapusAkun,
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

Future<void> _bukaTautan(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || berhasil) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Tautan tidak dapat dibuka.')));
}
