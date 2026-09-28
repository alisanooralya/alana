import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

const double _tinggiBanner = 200;

class PopularCarousel extends StatefulWidget {
  const PopularCarousel({
    super.key,
    required this.mangas,
    this.judul = 'Populer Hari Ini',
    this.interval = const Duration(seconds: 5),
  });

  final List<Manga> mangas;
  final String judul;
  final Duration interval;

  @override
  State<PopularCarousel> createState() => _PopularCarouselState();
}

class _PopularCarouselState extends State<PopularCarousel>
    with SingleTickerProviderStateMixin {
  static const int _pengulangan = 100;
  static const int _zonaAman = 2;

  late final PageController _controller;
  late final AnimationController _progres;

  late int _halaman;
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

  bool _tanganiNotifikasi(ScrollNotification notifikasi) {
    if (notifikasi is ScrollStartNotification ||
        notifikasi is ScrollUpdateNotification) {
      _sedangGeser = true;
      _progres.stop();
    } else if (notifikasi is ScrollEndNotification) {
      _sedangGeser = false;
      if (_bisaGeser && !_progres.isCompleted) _progres.forward();
    }
    return false;
  }

  void _saatHalamanBerubah(int index) {
    final asli = index % _jumlahAsli;
    var posisi = index;

    final diUjung = index < _zonaAman || index > _totalVirtual - _zonaAman - 1;
    if (diUjung && _controller.hasClients) {
      posisi = _tengahUntuk(asli);
      _controller.jumpToPage(posisi);
    }

    setState(() {
      _halaman = asli;
      _virtual = posisi;
    });

    if (_bisaGeser && !_sedangGeser) _progres.forward(from: 0);
  }

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
            height: _tinggiBanner,
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

class BannerPopuler extends StatelessWidget {
  const BannerPopuler({
    super.key,
    required this.manga,
    required this.peringkat,
    required this.onTap,
  });

  final Manga manga;

  final int peringkat;
  final VoidCallback onTap;

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

String formatRating(num rating) {
  if (rating == rating.roundToDouble()) return rating.toInt().toString();
  return rating.toStringAsFixed(1);
}

String formatRingkas(int angka) {
  if (angka < 1000) return '$angka';
  if (angka < 1000000) return '${(angka / 1000).round()}rb';

  final juta = angka / 1000000;
  if (juta < 10) return '${juta.toStringAsFixed(1).replaceAll('.', ',')}jt';
  return '${juta.toStringAsFixed(0)}jt';
}

String infoChapter(Manga manga) {
  if (manga.latestChapterNumber <= 0) {
    return manga.status.isEmpty ? 'Belum ada chapter' : manga.status;
  }
  final waktu = formatRelativeTime(manga.latestChapterTime);
  final dasar = 'Ch ${manga.latestChapterNumber}';
  return waktu.isEmpty ? dasar : '$dasar • $waktu';
}
