/// Bangumi 角色数据传输对象
class BangumiCharacterDto {
  final int id;
  final String name;
  final String? nameCn;
  final String? avatarGridUrl;
  final String? avatarLargeUrl;
  final int? birthYear;
  final int? birthMon;
  final int? birthDay;
  final String? roleName;
  final Map<String, dynamic> originalData;

  /// 标记数据是否为完整数据（来自 /v0/characters/{id} 或搜索）
  final bool isFullData;

  BangumiCharacterDto({
    required this.id,
    required this.name,
    this.nameCn,
    this.avatarGridUrl,
    this.avatarLargeUrl,
    this.birthYear,
    this.birthMon,
    this.birthDay,
    this.roleName,
    required this.originalData,
    this.isFullData = false,
  });

  String? get listAvatarUrl => avatarGridUrl ?? avatarLargeUrl;
  String? get detailAvatarUrl => avatarLargeUrl ?? avatarGridUrl;

  bool get hasBirthday => birthMon != null && birthDay != null;

  String get displayName => nameCn ?? name;

  String? get subName => nameCn != null ? name : null;

  String? get birthdayText {
    if (!hasBirthday) return null;
    return birthYear != null
        ? '$birthYear年$birthMon月$birthDay日'
        : '$birthMon月$birthDay日';
  }

  BangumiCharacterDto copyWith({
    int? id,
    String? name,
    String? nameCn,
    String? avatarGridUrl,
    String? avatarLargeUrl,
    int? birthYear,
    int? birthMon,
    int? birthDay,
    String? roleName,
    Map<String, dynamic>? originalData,
    bool? isFullData,
  }) {
    return BangumiCharacterDto(
      id: id ?? this.id,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      avatarGridUrl: avatarGridUrl ?? this.avatarGridUrl,
      avatarLargeUrl: avatarLargeUrl ?? this.avatarLargeUrl,
      birthYear: birthYear ?? this.birthYear,
      birthMon: birthMon ?? this.birthMon,
      birthDay: birthDay ?? this.birthDay,
      roleName: roleName ?? this.roleName,
      originalData: originalData ?? this.originalData,
      isFullData: isFullData ?? this.isFullData,
    );
  }

  factory BangumiCharacterDto.fromJson(Map<String, dynamic> json) {
    String? avatarGrid;
    String? avatarLarge;
    final images = json['images'];
    if (images is Map<String, dynamic>) {
      avatarGrid =
          images['grid'] as String? ??
          images['medium'] as String? ??
          images['small'] as String?;
      avatarLarge =
          images['large'] as String? ??
          images['common'] as String? ??
          images['medium'] as String? ??
          avatarGrid;
    }

    String? cnName;
    if (json['infobox'] != null && json['infobox'] is List) {
      for (var item in json['infobox']) {
        if (item is Map && item['key'] != null) {
          final key = item['key'].toString();
          if (key.contains('中文名') || key == '简体中文名' || key == '译名') {
            if (item['value'] is String) {
              cnName = item['value'];
            } else if (item['value'] is List && item['value'].isNotEmpty) {
              final valList = item['value'] as List;
              if (valList.isNotEmpty && valList.first is Map) {
                cnName = valList.first['v']?.toString();
              }
            }
            break;
          }
        }
      }
    }

    final bool hasFullData =
        json.containsKey('stat') ||
        json.containsKey('summary') ||
        json.containsKey('infobox') ||
        json.containsKey('birth_mon') ||
        json.containsKey('gender');

    return BangumiCharacterDto(
      id: json['id'],
      name: json['name'],
      nameCn: cnName,
      avatarGridUrl: avatarGrid,
      avatarLargeUrl: avatarLarge,
      birthYear: json['birth_year'],
      birthMon: json['birth_mon'],
      birthDay: json['birth_day'],
      roleName: json['relation'],
      originalData: json,
      isFullData: hasFullData,
    );
  }
}

/// Bangumi 角色搜索响应
class BangumiSearchResponse {
  final int total;
  final int limit;
  final int offset;
  final List<BangumiCharacterDto> data;

  BangumiSearchResponse({
    required this.total,
    required this.limit,
    required this.offset,
    required this.data,
  });

  factory BangumiSearchResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['data'] ?? [];
    final data = list.map((e) => BangumiCharacterDto.fromJson(e)).toList();

    return BangumiSearchResponse(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 0,
      offset: json['offset'] ?? 0,
      data: data,
    );
  }
}
