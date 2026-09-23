import 'package:alana/utils/json_utils.dart';

/// A manga genre.
class Genre {
  final String slug;
  final String name;

  const Genre({required this.slug, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(slug: asString(json['slug']), name: asString(json['name']));
  }
}
