/// Bangumi 条目数据传输对象
class BangumiSubjectDto {
  final int id;
  final String name;
  final String nameCn;
  final String? image;

  BangumiSubjectDto({
    required this.id,
    required this.name,
    required this.nameCn,
    this.image,
  });

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory BangumiSubjectDto.fromJson(Map<String, dynamic> json) {
    String? img;
    if (json['images'] != null) {
      img =
          json['images']['common'] ??
          json['images']['large'] ??
          json['images']['medium'] ??
          json['images']['small'] ??
          json['images']['grid'];
    }

    return BangumiSubjectDto(
      id: json['id'],
      name: json['name'],
      nameCn: json['name_cn'] ?? '',
      image: img,
    );
  }
}
