import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 名字首字母头像（通用 fallback）
class NameAvatar extends StatelessWidget {
  final String name;
  final double size;
  final int? colorValue;

  const NameAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.colorValue,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first : '?';
    final color = colorValue != null
        ? Color(colorValue!)
        : HSLColor.fromAHSL(
            1,
            (name.hashCode % 360).toDouble(),
            0.35,
            0.75,
          ).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 网络图片头像（带缓存 + fallback）
class NetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final int? colorValue;

  const NetworkAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.colorValue,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return NameAvatar(name: name, size: size, colorValue: colorValue);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            NameAvatar(name: name, size: size, colorValue: colorValue),
        errorWidget: (_, __, ___) =>
            NameAvatar(name: name, size: size, colorValue: colorValue),
      ),
    );
  }
}
