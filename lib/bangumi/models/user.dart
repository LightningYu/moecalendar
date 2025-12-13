/// Bangumi 用户模型
class BangumiUser {
  final int id;
  final String username;
  final String nickname;
  final BangumiUserAvatar avatar;
  final String sign;
  final String url;

  BangumiUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.url,
  });

  factory BangumiUser.fromJson(Map<String, dynamic> json) {
    return BangumiUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: BangumiUserAvatar.fromJson(json['avatar'] ?? {}),
      sign: json['sign'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar.toJson(),
      'sign': sign,
      'url': url,
    };
  }
}

class BangumiUserAvatar {
  final String large;
  final String medium;
  final String small;

  BangumiUserAvatar({
    required this.large,
    required this.medium,
    required this.small,
  });

  factory BangumiUserAvatar.fromJson(Map<String, dynamic> json) {
    return BangumiUserAvatar(
      large: json['large'] ?? '',
      medium: json['medium'] ?? '',
      small: json['small'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'large': large, 'medium': medium, 'small': small};
  }
}
