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

/// 条目搜索结果分页响应
class BangumiSubjectSearchResponse {
  final int total;
  final int limit;
  final int offset;
  final List<BangumiSubjectDto> data;

  BangumiSubjectSearchResponse({
    required this.total,
    required this.limit,
    required this.offset,
    required this.data,
  });

  factory BangumiSubjectSearchResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List? ?? [])
        .map((e) => BangumiSubjectDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return BangumiSubjectSearchResponse(
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      data: list,
    );
  }
}
