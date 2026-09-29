import 'package:flutter/material.dart';

class NomorHalaman extends StatelessWidget {
  const NomorHalaman({
    super.key,
    required this.halaman,
    required this.totalHalaman,
    required this.onPilih,
    this.sedangMemuat = false,
    this.jumlahTampak = 5,
  });

  final int halaman;
  final int totalHalaman;
  final ValueChanged<int> onPilih;
  final bool sedangMemuat;

  final int jumlahTampak;

  @override
  Widget build(BuildContext context) {
    if (totalHalaman <= 1) return const SizedBox.shrink();

    final nomor = _nomorTampak();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Tombol(
          ikon: Icons.chevron_left,
          aktif: halaman > 1 && !sedangMemuat,
          onTap: () => onPilih(halaman - 1),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final n in nomor) ...[
                  if (n == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('…'),
                    )
                  else
                    _Nomor(n: n, aktif: n == halaman, onTap: () => onPilih(n)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        _Tombol(
          ikon: Icons.chevron_right,
          aktif: halaman < totalHalaman && !sedangMemuat,
          onTap: () => onPilih(halaman + 1),
        ),
        if (sedangMemuat) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  List<int?> _nomorTampak() {
    if (totalHalaman <= jumlahTampak) {
      return [for (var i = 1; i <= totalHalaman; i++) i];
    }

    final setengah = jumlahTampak ~/ 2;
    var awal = halaman - setengah;
    var akhir = awal + jumlahTampak - 1;

    if (awal < 1) {
      awal = 1;
      akhir = jumlahTampak;
    }
    if (akhir > totalHalaman) {
      akhir = totalHalaman;
      awal = akhir - jumlahTampak + 1;
    }

    final hasil = <int?>[];
    if (awal > 1) {
      hasil.add(1);
      if (awal > 2) hasil.add(null);
    }
    for (var i = awal; i <= akhir; i++) {
      hasil.add(i);
    }
    if (akhir < totalHalaman) {
      if (akhir < totalHalaman - 1) hasil.add(null);
      hasil.add(totalHalaman);
    }
    return hasil;
  }
}

class _Nomor extends StatelessWidget {
  const _Nomor({required this.n, required this.aktif, required this.onTap});

  final int n;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: aktif ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  color: aktif ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({required this.ikon, required this.aktif, required this.onTap});

  final IconData ikon;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: aktif ? onTap : null,
      icon: Icon(ikon),
      visualDensity: VisualDensity.compact,
    );
  }
}
