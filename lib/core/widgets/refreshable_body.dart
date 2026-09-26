import 'package:flutter/material.dart';

/// Membungkus isi yang tidak bisa di-scroll supaya tetap bisa di-refresh.
///
/// [RefreshIndicator] hanya bekerja kalau ada keturunan scrollable yang
/// melaporkan overscroll. Saat hasil sedang loading, kosong, atau gagal, kedua
/// halaman tersebut menampilkan EmptyView/ErrorView/LoadingView yang sengaja
/// tidak bisa di-scroll, sehingga user menarik layar dan tidak terjadi
/// apa-apa: tidak ada spinner, tidak ada umpan balik, tidak ada refresh.
///
/// Bungkusannya memakai [AlwaysScrollableScrollPhysics] dan tinggi minimum
/// sebesar ruang yang tersedia, jadi tarikan selalu punya ruang untuk
/// bergeser. Dipakai hanya untuk cabang non-scrollabel; saat daftar sudah
/// tampil, ListView-nya sendiri yang menangani overscroll.
class RefreshableBody extends StatelessWidget {
  const RefreshableBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
