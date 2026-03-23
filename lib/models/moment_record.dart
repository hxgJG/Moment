/// 媒体类型枚举
enum MediaType {
  text,   // 纯文字
  image,  // 图片
  audio,  // 音频
  video,  // 视频
  mixed,  // 混合类型
}

/// 记录数据模型
class MomentRecord {
  final String id;
  final String content;        // 文案内容
  final DateTime createdAt;    // 创建时间
  final DateTime? updatedAt;   // 更新时间
  final MediaType mediaType;   // 媒体类型
  final List<String> mediaPaths; // 媒体文件路径列表

  MomentRecord({
    required this.id,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.mediaType,
    required this.mediaPaths,
  });

  /// 从Map创建对象（数据库读取）
  factory MomentRecord.fromMap(Map<String, dynamic> map) {
    return MomentRecord(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      mediaType: MediaType.values[map['media_type'] as int],
      mediaPaths: (map['media_paths'] as String).isEmpty
          ? []
          : (map['media_paths'] as String).split(','),
    );
  }

  /// 转换为Map（数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'media_type': mediaType.index,
      'media_paths': mediaPaths.join(','),
    };
  }

  /// 复制对象
  MomentRecord copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    MediaType? mediaType,
    List<String>? mediaPaths,
    bool? synced,
  }) {
    return MomentRecord(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaType: mediaType ?? this.mediaType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
    );
  }

  /// 从JSON创建对象（API响应）
  factory MomentRecord.fromJson(Map<String, dynamic> json) {
    return MomentRecord(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      mediaType: MediaType.values[json['media_type'] as int],
      mediaPaths: (json['media_paths'] as String?)?.isNotEmpty == true
          ? (json['media_paths'] as String).split(',')
          : [],
    );
  }

  /// 转换为JSON（API请求）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'media_type': mediaType.index,
      'media_paths': mediaPaths.join(','),
    };
  }

  /// 判断是否有媒体内容
  bool get hasMedia => mediaPaths.isNotEmpty;

  /// 获取媒体类型显示名称
  String get mediaTypeName {
    switch (mediaType) {
      case MediaType.text:
        return '文字';
      case MediaType.image:
        return '图片';
      case MediaType.audio:
        return '音频';
      case MediaType.video:
        return '视频';
      case MediaType.mixed:
        return '混合';
    }
  }
}
