class Page {
  final int index;
  final String imageUrl;

  final double? aspectRatio;

  const Page({required this.index, required this.imageUrl, this.aspectRatio});

  Page copyWith({double? aspectRatio}) {
    return Page(
      index: index,
      imageUrl: imageUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
