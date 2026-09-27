import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

/// Dipakai placeholder memuat juga, supaya tinggi section tidak melompat.
const double tinggiBannerPopuler = 200;

/// Carousel "spotlight" untuk feed peringkat: satu banner besar per judul,
/// hampir selebar layar dengan sedikit peek di tepi kanan.
///
/// Palet gelap dan teks putih, bukan warna tema: cover di feed ini warnanya
/// beragam, jadi kontras teks di mode terang bergantung pada gambar.
///
/// Auto-advance tiap [interval], jeda saat digeser, dan indikator pil yang
/// terisi mengikuti sisa waktu ke halaman berikutnya.
///
/// Tak berujung: daftar diulang banyak kali dan posisi awal di tengah, jadi
/// bisa digeser ke dua arah tanpa pernah mentok ujung. Indikator dan lencana
/// tetap memakai urutan asli, bukan indeks virtual.
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
  /// Pengaman saja; pengguna tidak akan pernah sampai ke ujung 100 putaran.
  static const int _pengulangan = 100;

  /// Seberapa dekat ke ujung sebelum posisi dikembalikan ke tengah. Di atas satu
  /// supaya lompatan tidak terjadi di tengah animasi.
  static const int _zonaAman = 2;

  late final PageController _controller;

  /// 0 ke 1 selama [PopularCarousel.interval], menentukan halaman berikutnya dan
  /// mengisi indikator sekaligus. Bukan `Timer.periodic` yang callbacknya bisa
  /// menumpuk.
  late final AnimationController _progres;

  /// Indeks asli dalam [PopularCarousel.mangas].
  late int _halaman;

  /// Indeks di dalam [PageView], bisa jauh lebih besar karena diulang.
  late int _virtual;

  bool _sedangGeser = false;

  int get _jumlahAsli => widget.mangas.length;

  int get _totalVirtual => _jumlahAsli * _pengulangan;

  bool get _bisaGeser => _jumlahAsli > 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _halaman = 0;
    _virtual = _jumlahAsli * (_pengulangan ~/ 2);
    _progres = AnimationController(vsync: this, duration: widget.interval)
      ..addStatusListener(_saatProgresSelesai);
    if (_bisaGeser) _progres.forward();

    // PageController selalu mulai di halaman 0, sedangkan [PopularCarousel]
    // baru di halaman tengah. Tanpa lompatan itu carousel mulai di ujung
    // daftar sehingga menggesek ke kiri tidak melakukan apa-apa. Lompatan
    // harus menunggu frame pertama karena PageView baru punya posisi scroll
    // setelah ia di-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpToPage(_virtual);
    });
  }

  @override
  void didUpdateWidget(PopularCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.interval != oldWidget.interval) {
      _progres.duration = widget.interval;
    }

    if (widget.mangas.length != oldWidget.mangas.length) {
      // Daftar bisa menyusut setelah provider di-invalidate. Judul yang tampil
      // ikut diklem, kalau tidak lencana peringkat bisa luput dari warna medali.
      if (_halaman >= _jumlahAsli) _halaman = 0;
      _virtual = _jumlahAsli * (_pengulangan ~/ 2);
      if (_controller.hasClients) _controller.jumpToPage(_virtual);
      _progres.value = 0;
      return;
    }

    if (_bisaGeser) _progres.forward(from: 0);
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

  /// Jeda saat digeser. Tanpa ini carousel menarik halaman dari bawah jari.
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

  /// Mengembalikan posisi ke tengah saat mendekati ujung.
  ///
  /// [_tengahUntuk] menjaga urutan asli tetap sama, jadi layar tidak
  /// bergeser. Melompat satu siklus penuh (`index + _totalVirtual`) akan
  /// mendarat di batas sisi sebaliknya dan memanggil `onPageChanged` tanpa
  /// henti.
  void _saatHalamanBerubah(int index) {
    final asli = index % _jumlahAsli;
    var posisi = index;

    final diUjung = index < _zonaAman || index > _totalVirtual - _zonaAman - 1;
    if (diUjung && _controller.hasClients) {
      posisi = _tengahUntuk(asli);
      // Tanpa animasi: kartu yang muncul setelah lompatan sama persis dengan
      // yang sebelumnya, jadi matanya tidak sempat menangkap Perpindahan.
      _controller.jumpToPage(posisi);
    }

    setState(() {
      _halaman = asli;
      _virtual = posisi;
    });

    if (_bisaGeser && !_sedangGeser) _progres.forward(from: 0);
  }

  /// Indeks tengah yang urutan aslinya tetap [asli].
  int _tengahUntuk(int asli) {
    final tengah = _jumlahAsli * (_pengulangan ~/ 2);
    return tengah - (tengah % _jumlahAsli) + asli;
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
              itemCount: _totalVirtual,
              onPageChanged: _saatHalamanBerubah,
              itemBuilder: (context, index) {
                final asli = index % _jumlahAsli;
                final manga = widget.mangas[asli];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: BannerPopuler(
                    manga: manga,
                    // Milik kartu ini, bukan halaman aktif: PageView
                    // membangun tetangga untuk pratinjau, jadi kalau ikut
                    // [_halaman] tiga lencana yang terlihat akan sama.
                    peringkat: asli + 1,
                    onTap: () => _buka(manga),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        IndikatorBanner(
          jumlah: _jumlahAsli,
          aktif: _halaman,
          progres: _progres,
        ),
      ],
    );
  }
}

/// Placeholder shimmer setinggi [tinggiBannerPopuler].
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

/// Kepala section, dipakai bersama semua section Beranda agar konsisten.
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

/// Kartu banner satu judul.
class BannerPopuler extends StatelessWidget {
  const BannerPopuler({
    super.key,
    required this.manga,
    required this.peringkat,
    required this.onTap,
  });

  final Manga manga;

  /// Nilai non-positif menyembunyikan lencana.
  final int peringkat;
  final VoidCallback onTap;

  /// Lebar cover; tinggi mengikuti rasio 3:4.
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
                // Diabaikan semantik supaya screen reader tidak mengulang
                // angkannya dua kali.
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

/// Tepi kanan memudar ke dasar kartu supaya tidak terlihat seperti tempelan.
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
        const SizedBox(height: 7),
        BarisAngka(manga: manga),
        const SizedBox(height: 4),
        BarisChapter(manga: manga),
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

/// Chip status + negara, dipisah supaya tiap nilai tetap terbaca.
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

/// Chapter pernah ikut di baris ini dan selalu terpotong karena berebut ruang
/// dengan rating; sekarang pindah ke [BarisChapter].
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
      ],
    );
  }
}

/// Tanpa `maxLines` dan tanpa ellipsis karena waktu relatif tidak boleh
/// terpotong; [FittedBox] mengecilkan huruf kalau tidak muat.
class BarisChapter extends StatelessWidget {
  const BarisChapter({super.key, required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        infoChapter(manga),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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

/// Yang aktif berupa pil yang terisi seiring [progres], jadi posisi isinya
/// memberi tahu kapan halaman berikutnya datang.
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

/// `12345` -> `12rb`, `2500000` -> `2,5jt`. Ribuan dibulatkan penuh karena
/// pecahannya tidak menambah informasi; koma karena teks antarmuka Indonesia.
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
