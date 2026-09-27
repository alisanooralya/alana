import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

/// Tinggi banner, dipakai juga oleh placeholder memuat di halaman Beranda
/// supaya tinggi section tidak melompat begitu data tiba.
const double tinggiBannerPopuler = 200;

/// Carousel "spotlight" untuk feed peringkat: satu banner besar per judul,
/// nyaris selebar layar dengan sedikit peek di tepi kanan supaya jelas masih
/// bisa digeser.
///
/// Kartu memakai palet gelap eksplisit dan teks putih, bukan warna tema.
/// Cover di feed ini warnanya beragam, jadi kalau kartu mengikuti mode terang
/// kontras teksnya bergantung pada gambar. Palet gelap yang tetap membuat
/// bagian ini terbaca sebagai etalase dan tidak ikut berubah saat pengguna
/// berganti mode terang/gelap.
///
/// Auto-advance tiap [interval], jeda selama jari sedang menggeser, dan
/// indikator pil yang terisi mengikuti sisa waktu menuju halaman berikutnya.
class PopularCarousel extends StatefulWidget {
  const PopularCarousel({
    super.key,
    required this.mangas,
    this.judul = 'Populer Hari Ini',
    this.interval = const Duration(seconds: 5),
  });

  final List<Manga> mangas;

  /// Judul section. Data yang sama bisa dipakai untuk feed berbeda, jadi
  /// judul tidak lagi ditulis mati di dalam widget.
  final String judul;

  /// Jeda antar halaman. Diabaikan kalau isinya hanya satu item.
  final Duration interval;

  @override
  State<PopularCarousel> createState() => _PopularCarouselState();
}

class _PopularCarouselState extends State<PopularCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;

  /// Berjalan dari 0 ke 1 selama [PopularCarousel.interval]. Satu controller
  /// ini dipakai dua hal: menentukan kapan halaman berikutnya dimulai dan
  /// mengisi indikator. `Timer.periodic` tidak dipakai karena bisa menumpuk
  /// callback kalau siklus berjalan lebih lama dari satu tick.
  late final AnimationController _progres;

  int _halaman = 0;
  bool _sedangGeser = false;

  bool get _bisaGeser => widget.mangas.length > 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _progres = AnimationController(vsync: this, duration: widget.interval)
      ..addStatusListener(_saatProgresSelesai);
    if (_bisaGeser) _progres.forward();
  }

  @override
  void didUpdateWidget(PopularCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.interval != oldWidget.interval) {
      _progres.duration = widget.interval;
    }

    // Daftar bisa menyusut setelah provider di-invalidate. PageView akan
    // melempar error indeks di luar jangkauan kalau halaman sekarang lebih
    // besar daripada data baru, jadi posisi diklem di sini.
    if (_halaman >= widget.mangas.length) {
      _halaman = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _progres.value = 0;
      return;
    }

    if (widget.mangas.length != oldWidget.mangas.length && _bisaGeser) {
      _progres.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progres.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Progres menyentuh 1: geser ke halaman berikutnya lalu mulai hitung ulang.
  void _saatProgresSelesai(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || !_bisaGeser) return;

    if (_controller.hasClients) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
    _progres.forward(from: 0);
  }

  /// Jeda saat jari pengguna menyentuh banner, lanjut lagi setelah lempar.
  ///
  /// Tanpa ini, timer tetap berjalan saat orang sedang menggeser dan
  /// carousel menarik halaman keluar dari bawah jarinya.
  bool _tanganiNotifikasi(ScrollNotification notifikasi) {
    if (notifikasi is ScrollStartNotification ||
        notifikasi is ScrollUpdateNotification) {
      _sedangGeser = true;
      _progres.stop();
    } else if (notifikasi is ScrollEndNotification) {
      _sedangGeser = false;
      if (_bisaGeser && !_progres.isCompleted) _progres.forward();
    }
    // false: biar PageView tetap menangani drag-nya sendiri.
    return false;
  }

  void _buka(Manga manga) {
    if (manga.url.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('ID judul tidak tersedia.')),
        );
      return;
    }
    context.pushNamed('detail', pathParameters: {'mangaId': manga.url});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KepalaSection(judul: widget.judul),
        NotificationListener<ScrollNotification>(
          onNotification: _tanganiNotifikasi,
          child: SizedBox(
            height: tinggiBannerPopuler,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.mangas.length,
              onPageChanged: (index) {
                setState(() => _halaman = index);
                if (_bisaGeser && !_sedangGeser) _progres.forward(from: 0);
              },
              itemBuilder: (context, index) {
                final manga = widget.mangas[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: BannerPopuler(
                    manga: manga,
                    peringkat: index + 1,
                    onTap: () => _buka(manga),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        IndikatorBanner(
          jumlah: widget.mangas.length,
          aktif: _halaman,
          progres: _progres,
        ),
      ],
    );
  }
}

/// Placeholder shimmer untuk [PopularCarousel]. Tingginya dikunci ke
/// [tinggiBannerPopuler] supaya section tidak melompat tinggi begitu data
/// tiba.
class PopularCarouselPlaceholder extends StatelessWidget {
  const PopularCarouselPlaceholder({
    super.key,
    this.judul = 'Populer Hari Ini',
  });

  final String judul;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final dasar = gelap ? Colors.grey.shade800 : Colors.grey.shade300;
    final terang = gelap ? Colors.grey.shade700 : Colors.grey.shade100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KepalaSection(judul: judul),
        Shimmer.fromColors(
          baseColor: dasar,
          highlightColor: terang,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: tinggiBannerPopuler,
              decoration: BoxDecoration(
                color: dasar,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Shimmer.fromColors(
            baseColor: dasar,
            highlightColor: terang,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: i == 0
                        ? IndikatorBanner.lebarAktif
                        : IndikatorBanner.lebarIdle,
                    height: IndikatorBanner.tinggi,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: dasar,
                      borderRadius: BorderRadius.circular(
                        IndikatorBanner.tinggi / 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kepala section: strip aksen + judul, dipakai bersama oleh semua section
/// Beranda supaya posisinya konsisten antar judul.
class KepalaSection extends StatelessWidget {
  const KepalaSection({super.key, required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              judul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu banner untuk satu judul. Dipakai di carousel Populer.
class BannerPopuler extends StatelessWidget {
  const BannerPopuler({
    super.key,
    required this.manga,
    required this.peringkat,
    required this.onTap,
  });

  final Manga manga;

  /// Urutan di feed. Untuk feed ranked ini memang peringkat, untuk feed lain
  /// pemanggil bisa mengosongkan lewat nilai non-positif.
  final int peringkat;
  final VoidCallback onTap;

  /// Lebar cover. Tingginya mengikuti rasio 3:4 lalu disejajarkan di tengah
  /// banner.
  static const double lebarCover = 116;

  double get _tinggiCover => lebarCover * 4 / 3;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B2634), Color(0xFF0C1118)],
              ),
            ),
            child: Stack(
              children: [
                // Angka jumbo di latar. Memberi bobot pada urutannya tanpa
                // menambah elemen yang terbaca seperti tombol, dan sengaja
                // diabaikan semantik supaya screen reader tidak mengulang
                // angkanya dua kali.
                if (peringkat > 0)
                  Positioned(
                    right: 6,
                    bottom: -24,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Text(
                          '$peringkat',
                          style: TextStyle(
                            fontSize: 96,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _CoverBanner(
                        manga: manga,
                        lebar: lebarCover,
                        tinggi: _tinggiCover,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TeksBanner(manga: manga, peringkat: peringkat),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cover dengan tepi kanan memudar ke dasar kartu, supaya tidak terlihat
/// seperti kotak yang ditempel.
class _CoverBanner extends StatelessWidget {
  const _CoverBanner({
    required this.manga,
    required this.lebar,
    required this.tinggi,
  });

  final Manga manga;
  final double lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(
            imageUrl: manga.thumbnail,
            width: lebar,
            height: tinggi,
            borderRadius: 12,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  const Color(0xFF16202C).withValues(alpha: 0.9),
                ],
                stops: const [0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom kanan banner: peringkat, judul, chip meta, lalu angka ringkas.
class TeksBanner extends StatelessWidget {
  const TeksBanner({super.key, required this.manga, required this.peringkat});

  final Manga manga;
  final int peringkat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (peringkat > 0) ...[
          LencanaPeringkat(peringkat: peringkat),
          const SizedBox(height: 10),
        ],
        Text(
          manga.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        BarisChip(status: manga.status, negara: manga.country),
        const SizedBox(height: 8),
        BarisAngka(manga: manga),
      ],
    );
  }
}

/// Lencana peringkat. Tiga besar memakai warna medali supaya bisa dibedakan
/// sekilas tanpa harus membaca angkanya.
class LencanaPeringkat extends StatelessWidget {
  const LencanaPeringkat({super.key, required this.peringkat});

  final int peringkat;

  static const _warnaMedali = <int, List<Color>>{
    1: [Color(0xFFFFD66B), Color(0xFFE0A400)],
    2: [Color(0xFFE3E8EF), Color(0xFF9AA6B4)],
    3: [Color(0xFFE0B089), Color(0xFFA9714B)],
  };

  @override
  Widget build(BuildContext context) {
    final medali = _warnaMedali[peringkat];
    final gelap = medali != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: medali == null ? null : LinearGradient(colors: medali),
        color: gelap ? null : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: gelap
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: gelap ? const Color(0xFF4A3208) : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            '#$peringkat',
            style: TextStyle(
              color: gelap ? const Color(0xFF3A2705) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip status + negara. Dipisah jadi chip, bukan digabung dengan bullet,
/// supaya tiap nilai tetap terbaca dan tidak menyatu jadi baris panjang.
class BarisChip extends StatelessWidget {
  const BarisChip({super.key, required this.status, required this.negara});

  final String status;
  final String negara;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (status.isNotEmpty) status,
      if (negara.isNotEmpty) negara,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (final chip in chips) ChipMini(teks: chip)],
    );
  }
}

class ChipMini extends StatelessWidget {
  const ChipMini({super.key, required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Baris paling bawah: rating dan jumlah dibaca di kiri, chapter terbaru
/// didorong ke kanan. Satu baris penuh karena menumpuknya di kolom selebar
/// ini membuat teks kecil jadi tidak terbaca.
class BarisAngka extends StatelessWidget {
  const BarisAngka({super.key, required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (manga.rating > 0) ...[
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
          const SizedBox(width: 3),
          Text(
            formatRating(manga.rating),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (manga.viewCount > 0) ...[
          if (manga.rating > 0) const _Pemisah(),
          const Icon(Icons.visibility_rounded, size: 14, color: Colors.white54),
          const SizedBox(width: 3),
          Text(
            formatRingkas(manga.viewCount),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
        const Spacer(),
        Flexible(
          child: Text(
            infoChapter(manga),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pemisah extends StatelessWidget {
  const _Pemisah();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}

/// Indikator pipih. Yang aktif berupa pil yang terisi dari kiri seiring
/// [progres] berjalan, jadi posisi isi memberi tahu kapan halaman berikutnya
/// datang tanpa perlu teks.
class IndikatorBanner extends StatelessWidget {
  const IndikatorBanner({
    super.key,
    required this.jumlah,
    required this.aktif,
    required this.progres,
  });

  final int jumlah;
  final int aktif;
  final Animation<double> progres;

  static const double lebarAktif = 26;
  static const double lebarIdle = 7;
  static const double tinggi = 7;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < jumlah; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              width: i == aktif ? lebarAktif : lebarIdle,
              height: tinggi,
              decoration: BoxDecoration(
                color: i == aktif
                    ? scheme.primary.withValues(alpha: 0.22)
                    : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(tinggi / 2),
              ),
              child: i == aktif
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(tinggi / 2),
                      child: AnimatedBuilder(
                        animation: progres,
                        builder: (context, child) => Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progres.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                        child: ColoredBox(color: scheme.primary),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Rating dengan satu angka di belakang koma, tanpa ".0" yang tidak perlu.
String formatRating(num rating) {
  if (rating == rating.roundToDouble()) return rating.toInt().toString();
  return rating.toStringAsFixed(1);
}

/// Jumlah dibaca dipendekkan supaya muat di baris sempit.
///
///Dibulatkan penuh untuk ribuan (`12345` -> `12rb`) karena angka pecahan di
/// sini tidak menambah informasi apa pun, dan satu desimal saja untuk jutaan
/// (`2500000` -> `2,5jt`) di mana kenaikannya masih terlihat. Pemisah desimal
/// memakai koma karena seluruh teks antarmuka berbahasa Indonesia.
String formatRingkas(int angka) {
  if (angka < 1000) return '$angka';
  if (angka < 1000000) return '${(angka / 1000).round()}rb';

  final juta = angka / 1000000;
  if (juta < 10) return '${juta.toStringAsFixed(1).replaceAll('.', ',')}jt';
  return '${juta.toStringAsFixed(0)}jt';
}

/// Ringkasan chapter untuk banner: `Ch 12` plus waktu relatif bila ada.
String infoChapter(Manga manga) {
  if (manga.latestChapterNumber <= 0) {
    return manga.status.isEmpty ? 'Belum ada chapter' : manga.status;
  }
  final waktu = formatRelativeTime(manga.latestChapterTime);
  final dasar = 'Ch ${manga.latestChapterNumber}';
  return waktu.isEmpty ? dasar : '$dasar • $waktu';
}
