/// 媒体类型枚举
enum MediaType {
  text, // 纯文字
  image, // 图片
  audio, // 音频
  video, // 视频
  mixed, // 混合类型
}

enum SyncStatus {
  localOnly, // 仅本地存在
  synced, // 已与服务端同步
  pendingUpload, // 服务端记录的本地待上传修改
  conflict, // 本地与云端都发生了修改，需手动确认
}

/// 记录数据模型
class MomentRecord {
  final String id;
  final String? serverId; // 服务端记录 ID；本地未上传时为空
  final String content; // 文案内容
  final DateTime createdAt; // 创建时间
  final DateTime? updatedAt; // 更新时间
  final MediaType mediaType; // 媒体类型
  final List<String> mediaPaths; // 媒体文件路径列表
  final bool synced; // 是否已同步到云端
  final SyncStatus syncStatus; // 同步状态
  final DateTime? lastSyncedAt; // 最近一次同步时间
  final DateTime? conflictRemoteUpdatedAt; // 发现冲突时远端记录更新时间

  MomentRecord({
    required this.id,
    this.serverId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.mediaType,
    required this.mediaPaths,
    this.synced = false,
    SyncStatus? syncStatus,
    this.lastSyncedAt,
    this.conflictRemoteUpdatedAt,
  }) : syncStatus = syncStatus ?? _deriveSyncStatus(serverId, synced);

  static SyncStatus _deriveSyncStatus(String? serverId, bool synced) {
    if (synced) {
      return SyncStatus.synced;
    }
    if (serverId != null && serverId.isNotEmpty) {
      return SyncStatus.pendingUpload;
    }
    return SyncStatus.localOnly;
  }

  static SyncStatus _syncStatusFromStoredValue(
    dynamic value, {
    required String? serverId,
    required bool synced,
  }) {
    final index = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (index != null && index >= 0 && index < SyncStatus.values.length) {
      return SyncStatus.values[index];
    }
    return _deriveSyncStatus(serverId, synced);
  }

  /// 从Map创建对象（数据库读取）
  factory MomentRecord.fromMap(Map<String, dynamic> map) {
    final synced = (map['synced'] as int? ?? 0) == 1;
    final serverId = map['server_id']?.toString();
    return MomentRecord(
      id: map['id'] as String,
      serverId: (serverId == null || serverId.isEmpty) ? null : serverId,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      mediaType: MediaType.values[map['media_type'] as int],
      mediaPaths: (map['media_paths'] as String).isEmpty
          ? []
          : (map['media_paths'] as String).split(','),
      synced: synced,
      syncStatus: _syncStatusFromStoredValue(
        map['sync_status'],
        serverId: serverId,
        synced: synced,
      ),
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
      conflictRemoteUpdatedAt: map['conflict_remote_updated_at'] != null
          ? DateTime.parse(map['conflict_remote_updated_at'] as String)
          : null,
    );
  }

  /// 转换为Map（数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'media_type': mediaType.index,
      'media_paths': mediaPaths.join(','),
      'synced': synced ? 1 : 0,
      'sync_status': syncStatus.index,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'conflict_remote_updated_at': conflictRemoteUpdatedAt?.toIso8601String(),
    };
  }

  /// 复制对象
  MomentRecord copyWith({
    String? id,
    String? serverId,
    bool clearServerId = false,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    MediaType? mediaType,
    List<String>? mediaPaths,
    bool? synced,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    DateTime? conflictRemoteUpdatedAt,
    bool clearConflictRemoteUpdatedAt = false,
  }) {
    return MomentRecord(
      id: id ?? this.id,
      serverId: clearServerId ? null : (serverId ?? this.serverId),
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaType: mediaType ?? this.mediaType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      synced: synced ?? this.synced,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      conflictRemoteUpdatedAt: clearConflictRemoteUpdatedAt
          ? null
          : (conflictRemoteUpdatedAt ?? this.conflictRemoteUpdatedAt),
    );
  }

  /// 从JSON创建对象（API响应，兼容服务端与旧格式）
  factory MomentRecord.fromJson(Map<String, dynamic> json) {
    return MomentRecord.fromApiMap(json);
  }

  /// 解析服务端 / 管理端返回的单条时光（id 为数字、media_type 为字符串、media_paths 为数组）
  factory MomentRecord.fromApiMap(Map<String, dynamic> json) {
    final serverId = json['id']?.toString();
    return MomentRecord(
      id: serverId ?? '',
      serverId: serverId,
      content: json['content'] as String? ?? '',
      createdAt: _parseApiDateTime(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? _parseApiDateTime(json['updated_at'])
          : null,
      mediaType: parseMediaTypeField(json['media_type']),
      mediaPaths: parseMediaPathsField(json['media_paths']),
      synced: true,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
      conflictRemoteUpdatedAt: null,
    );
  }

  static DateTime _parseApiDateTime(dynamic v) {
    final s = v.toString();
    if (s.contains(' ') && !s.contains('T')) {
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    }
    return DateTime.parse(s);
  }

  static MediaType parseMediaTypeField(dynamic v) {
    if (v is int) {
      if (v >= 0 && v < MediaType.values.length) {
        return MediaType.values[v];
      }
      return MediaType.text;
    }
    switch (v?.toString()) {
      case 'image':
        return MediaType.image;
      case 'audio':
        return MediaType.audio;
      case 'video':
        return MediaType.video;
      case 'mixed':
        return MediaType.mixed;
      case 'text':
      default:
        return MediaType.text;
    }
  }

  static List<String> parseMediaPathsField(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    if (v is String) {
      if (v.isEmpty) return [];
      return v.split(',');
    }
    return [];
  }

  /// 创建时光时提交给后端的 JSON（与 CreateMomentRequest 一致）
  Map<String, dynamic> toCreateApiJson() {
    return {
      'content': content,
      'media_type': _apiMediaTypeString(),
      'media_paths': mediaPaths,
    };
  }

  String _apiMediaTypeString() {
    switch (mediaType) {
      case MediaType.text:
        return 'text';
      case MediaType.image:
        return 'image';
      case MediaType.audio:
        return 'audio';
      case MediaType.video:
        return 'video';
      case MediaType.mixed:
        return 'mixed';
    }
  }

  /// 转换为JSON（本地或其它用途，非创建接口）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'media_type': mediaType.index,
      'media_paths': mediaPaths.join(','),
      'synced': synced,
      'sync_status': syncStatus.index,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'conflict_remote_updated_at': conflictRemoteUpdatedAt?.toIso8601String(),
    };
  }

  /// 判断是否有媒体内容
  bool get hasMedia => mediaPaths.isNotEmpty;

  bool get hasServerCopy => serverId != null && serverId!.isNotEmpty;

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
