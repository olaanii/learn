import 'equb.dart';

class TrendingEqub {
  final Equb equb;
  final String category;

  const TrendingEqub({required this.equb, required this.category});

  factory TrendingEqub.fromJson(Map<String, dynamic> json) {
    return TrendingEqub(
      equb: Equb.fromJson(json['equb'] is Map<String, dynamic> ? json['equb'] : json),
      category: json['category']?.toString() ?? 'topRated',
    );
  }

  Map<String, dynamic> toJson() => {
    'equb': equb.toJson(),
    'category': category,
  };
}
