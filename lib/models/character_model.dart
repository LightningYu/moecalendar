import 'dart:math';
import 'package:flutter/painting.dart';

abstract class Character {
  final String id;
  final int notificationId;
  final String name;
  final String? avatarPath;
  final int? birthYear;
  final int birthMonth;
  final int birthDay;
  final bool notify;
  final String type;
  final bool isLunar;
  final bool isSelf;

  /// 头像背景色（ARGB int），创建时随机生成并持久化，保证每次启动一致
  final int? avatarColor;

  Character({
    required this.id,
    required this.notificationId,
    required this.name,
    this.avatarPath,
    this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    this.notify = true,
    required this.type,
    this.isLunar = false,
    this.isSelf = false,
    this.avatarColor,
  });

  // 如果没有年份，默认使用当前年份
  DateTime get date {
    final year = birthYear ?? DateTime.now().year;
    return DateTime(year, birthMonth, birthDay);
  }

  Map<String, dynamic> toJson();

  factory Character.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'bangumi') {
      return BangumiCharacter.fromJson(json);
    } else {
      return ManualCharacter.fromJson(json);
    }
  }

  /// 随机生成一个柔和的 HSL 颜色的 ARGB int 值
  static int generateAvatarColor() {
    final random = Random();
    final hue = random.nextDouble() * 360;
    // 使用柔和的饱和度和亮度
    final color = HSLColor.fromAHSL(1.0, hue, 0.35, 0.75);
    return color.toColor().toARGB32();
  }
}

class ManualCharacter extends Character {
  ManualCharacter({
    required super.id,
    required super.notificationId,
    required super.name,
    super.avatarPath,
    super.birthYear,
    required super.birthMonth,
    required super.birthDay,
    super.notify,
    super.isLunar,
    super.isSelf,
    super.avatarColor,
  }) : super(type: 'manual');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'name': name,
      'avatarPath': avatarPath,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'notify': notify,
      'type': type,
      'isLunar': isLunar,
      'isSelf': isSelf,
      'avatarColor': avatarColor,
    };
  }

  factory ManualCharacter.fromJson(Map<String, dynamic> json) {
    return ManualCharacter(
      id: json['id'],
      notificationId: json['notificationId'],
      name: json['name'],
      avatarPath: json['avatarPath'],
      birthYear: json['birthYear'],
      birthMonth: json['birthMonth'],
      birthDay: json['birthDay'],
      notify: json['notify'] ?? true,
      isLunar: json['isLunar'] ?? false,
      isSelf: json['isSelf'] ?? false,
      avatarColor: json['avatarColor'],
    );
  }

  /// 复制并更新角色数据
  ManualCharacter copyWith({
    String? id,
    int? notificationId,
    String? name,
    String? avatarPath,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    bool? notify,
    bool? isLunar,
    bool? isSelf,
    int? avatarColor,
  }) {
    return ManualCharacter(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      notify: notify ?? this.notify,
      isLunar: isLunar ?? this.isLunar,
      isSelf: isSelf ?? this.isSelf,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}

class BangumiCharacter extends Character {
  final int bangumiId;
  final Map<String, dynamic> originalData;

  /// Grid 尺寸头像路径（用于列表显示）
  final String? gridAvatarPath;

  /// Large 尺寸头像路径（用于详情页显示）
  final String? largeAvatarPath;

  BangumiCharacter({
    required super.id,
    required super.notificationId,
    required super.name,
    super.avatarPath,
    super.birthYear,
    required super.birthMonth,
    required super.birthDay,
    super.notify,
    required this.bangumiId,
    required this.originalData,
    this.gridAvatarPath,
    this.largeAvatarPath,
    super.avatarColor,
  }) : super(type: 'bangumi');

  /// 获取列表显示用的头像（优先 grid）
  String? get listAvatar => gridAvatarPath ?? avatarPath ?? largeAvatarPath;

  /// 获取详情页显示用的头像（优先 large）
  String? get detailAvatar => largeAvatarPath ?? avatarPath ?? gridAvatarPath;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'name': name,
      'avatarPath': avatarPath,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'notify': notify,
      'type': type,
      'bangumiId': bangumiId,
      'originalData': originalData,
      'gridAvatarPath': gridAvatarPath,
      'largeAvatarPath': largeAvatarPath,
      'avatarColor': avatarColor,
    };
  }

  factory BangumiCharacter.fromJson(Map<String, dynamic> json) {
    return BangumiCharacter(
      id: json['id'],
      notificationId: json['notificationId'],
      name: json['name'],
      avatarPath: json['avatarPath'],
      birthYear: json['birthYear'],
      birthMonth: json['birthMonth'],
      birthDay: json['birthDay'],
      notify: json['notify'] ?? true,
      bangumiId: json['bangumiId'],
      originalData: Map<String, dynamic>.from(json['originalData'] ?? {}),
      gridAvatarPath: json['gridAvatarPath'],
      largeAvatarPath: json['largeAvatarPath'],
      avatarColor: json['avatarColor'],
    );
  }

  /// 复制并更新角色数据
  BangumiCharacter copyWith({
    String? id,
    int? notificationId,
    String? name,
    String? avatarPath,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    bool? notify,
    int? bangumiId,
    Map<String, dynamic>? originalData,
    String? gridAvatarPath,
    String? largeAvatarPath,
    int? avatarColor,
  }) {
    return BangumiCharacter(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      notify: notify ?? this.notify,
      bangumiId: bangumiId ?? this.bangumiId,
      originalData: originalData ?? this.originalData,
      gridAvatarPath: gridAvatarPath ?? this.gridAvatarPath,
      largeAvatarPath: largeAvatarPath ?? this.largeAvatarPath,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}
