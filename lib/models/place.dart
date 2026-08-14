/// 추천 장소 1건 (백엔드 /places/recommend 응답).
class Place {
  final String? fsqId;
  final String name;
  final String? address;
  final String? category;
  final double latitude;
  final double longitude;
  final int? distance; // 미터
  final String? tel;
  final String? description; // detail=true일 때만(구글 editorialSummary)
  final double? rating; // detail=true일 때만

  const Place({
    this.fsqId,
    required this.name,
    this.address,
    this.category,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.tel,
    this.description,
    this.rating,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    fsqId: json['fsqId'] as String?,
    name: (json['name'] as String?) ?? '이름 없음',
    address: json['address'] as String?,
    category: json['category'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    distance: (json['distance'] as num?)?.toInt(),
    tel: json['tel'] as String?,
    description: json['description'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
  );

  String? get distanceLabel {
    final d = distance;
    if (d == null) return null;
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)}km' : '${d}m';
  }
}
