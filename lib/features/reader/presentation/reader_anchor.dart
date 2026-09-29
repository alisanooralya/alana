import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

typedef AnchorBaca = ({int scrollIndex, double scrollLeading});

const double _batasLeadingBawah = -1000.0;
const double _batasLeadingAtas = 1.0;

double bersihkanLeading(double nilai) {
  if (nilai.isNaN || nilai.isInfinite) return 0;
  if (nilai < _batasLeadingBawah) return _batasLeadingBawah;
  if (nilai > _batasLeadingAtas) return _batasLeadingAtas;
  return nilai;
}

AnchorBaca? anchorDariPosisi(Iterable<ItemPosition> posisi) {
  final terlihat =
      posisi.where((p) => p.itemTrailingEdge > 0).toList(growable: false)
        ..sort((a, b) => a.index.compareTo(b.index));
  if (terlihat.isEmpty) return null;
  return anchorDariItem(terlihat.first);
}

AnchorBaca anchorDariItem(ItemPosition item) {
  return (
    scrollIndex: item.index,
    scrollLeading: bersihkanLeading(item.itemLeadingEdge),
  );
}

double koreksiLeading({
  required double scrollLeading,
  required double deltaTinggi,
  required double tinggiViewport,
}) {
  if (deltaTinggi.abs() < 0.5) return scrollLeading;
  if (tinggiViewport <= 0) return scrollLeading;
  return bersihkanLeading(scrollLeading - deltaTinggi / tinggiViewport);
}
