/// 用户模型
class User {
  final String id;
  final String username;
  final String nickname;
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] is String) ? json['id'] as String : json['id'].toString(),
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar_url': avatarUrl,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
