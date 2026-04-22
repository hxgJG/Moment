import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../providers/moment_provider.dart';
import '../models/moment_record.dart';
import '../utils/media_source.dart';
import '../widgets/liquid_glass.dart';

/// 时光Tab - 显示所有记录列表
class MomentsTab extends StatefulWidget {
  const MomentsTab({super.key});

  @override
  State<MomentsTab> createState() => _MomentsTabState();
}

class _MomentsTabState extends State<MomentsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  _MomentListFilter _filter = _MomentListFilter.all;
  int _visibleCount = MomentProvider.pageSize;
  int _currentFilteredCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_visibleCount >= _currentFilteredCount) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (mounted) {
      setState(() {
        _visibleCount = math.min(
          _visibleCount + MomentProvider.pageSize,
          _currentFilteredCount,
        );
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MomentProvider>();
    final filteredMoments = _applyFilter(provider.moments);
    _currentFilteredCount = filteredMoments.length;
    final visibleCount = math.min(_visibleCount, filteredMoments.length);
    final visibleMoments = filteredMoments.take(visibleCount).toList();
    final hasMoreVisible = visibleCount < filteredMoments.length;
    final pendingUploadCount = provider.moments
        .where((m) => m.syncStatus == SyncStatus.pendingUpload)
        .length;
    final localOnlyCount = provider.moments
        .where((m) => m.syncStatus == SyncStatus.localOnly)
        .length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: () {
          if (provider.isLoading) {
            return const Center(
              child: LiquidGlassCard(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (provider.error != null && provider.moments.isEmpty) {
            return Center(
              child: LiquidGlassCard(
                tintColor: const Color(0xFFFFD7D7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 52,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => provider.fetchFromServer(),
                      child: const Text('重新拉取'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.moments.isEmpty) {
            return const Center(
              child: LiquidGlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 62,
                      color: kLiquidGlassAccent,
                    ),
                    SizedBox(height: 14),
                    Text(
                      '还没有记录',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '点击底部中央按钮，把第一段回忆放进来。',
                      style: TextStyle(
                        fontSize: 14,
                        color: kLiquidGlassMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchFromServer(),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              children: [
                if (provider.conflictCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ConflictQuickAction(
                        count: provider.conflictCount,
                        active: _filter == _MomentListFilter.conflict,
                        onPressed: () {
                          setState(() {
                            _filter = _filter == _MomentListFilter.conflict
                                ? _MomentListFilter.all
                                : _MomentListFilter.conflict;
                            _visibleCount = MomentProvider.pageSize;
                          });
                        },
                      ),
                    ),
                  ),
                _MomentsHero(
                  totalCount: provider.moments.length,
                  conflictCount: provider.conflictCount,
                  pendingUploadCount: pendingUploadCount,
                ),
                const SizedBox(height: 16),
                _FilterBar(
                  selected: _filter,
                  totalCount: provider.moments.length,
                  conflictCount: provider.conflictCount,
                  pendingUploadCount: pendingUploadCount,
                  localOnlyCount: localOnlyCount,
                  onChanged: (next) {
                    setState(() {
                      _filter = next;
                      _visibleCount = MomentProvider.pageSize;
                    });
                  },
                ),
                if (_filter != _MomentListFilter.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FilterHint(
                      filter: _filter,
                      count: filteredMoments.length,
                    ),
                  ),
                if (filteredMoments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: _FilteredEmptyState(),
                  )
                else ...[
                  ...visibleMoments
                      .map((record) => _MomentCard(record: record)),
                  if (hasMoreVisible) _buildLoadMoreIndicator(),
                ],
              ],
            ),
          );
        }(),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: _loadMore,
                child: Text('继续展开 (${_currentFilteredCount - _visibleCount})'),
              ),
      ),
    );
  }

  List<MomentRecord> _applyFilter(List<MomentRecord> source) {
    final filtered = switch (_filter) {
      _MomentListFilter.all => List<MomentRecord>.from(source),
      _MomentListFilter.conflict =>
        source.where((m) => m.syncStatus == SyncStatus.conflict).toList(),
      _MomentListFilter.pendingUpload =>
        source.where((m) => m.syncStatus == SyncStatus.pendingUpload).toList(),
      _MomentListFilter.localOnly =>
        source.where((m) => m.syncStatus == SyncStatus.localOnly).toList(),
    };

    filtered.sort((a, b) {
      final priority = _statusPriority(a.syncStatus).compareTo(
        _statusPriority(b.syncStatus),
      );
      if (priority != 0) {
        return priority;
      }
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  int _statusPriority(SyncStatus status) {
    switch (status) {
      case SyncStatus.conflict:
        return 0;
      case SyncStatus.pendingUpload:
        return 1;
      case SyncStatus.localOnly:
        return 2;
      case SyncStatus.synced:
        return 3;
    }
  }
}

class _MomentsHero extends StatelessWidget {
  final int totalCount;
  final int conflictCount;
  final int pendingUploadCount;

  const _MomentsHero({
    required this.totalCount,
    required this.conflictCount,
    required this.pendingUploadCount,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tintColor: const Color(0xFFC9DBFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今天的回忆正在流动',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '透明的层次会把文字、图片和同步状态轻轻叠在一起，像一块漂浮的玻璃面板。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: kLiquidGlassMuted,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroStat(label: '总记录', value: '$totalCount'),
              _HeroStat(label: '待上传', value: '$pendingUploadCount'),
              _HeroStat(label: '冲突', value: '$conflictCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPill(
      tintColor: const Color(0xFFDAE6FF),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: kLiquidGlassMuted,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MomentListFilter {
  all,
  conflict,
  pendingUpload,
  localOnly,
}

class _FilterBar extends StatelessWidget {
  final _MomentListFilter selected;
  final int totalCount;
  final int conflictCount;
  final int pendingUploadCount;
  final int localOnlyCount;
  final ValueChanged<_MomentListFilter> onChanged;

  const _FilterBar({
    required this.selected,
    required this.totalCount,
    required this.conflictCount,
    required this.pendingUploadCount,
    required this.localOnlyCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChipItem(
              label: '全部',
              count: totalCount,
              selected: selected == _MomentListFilter.all,
              onTap: () => onChanged(_MomentListFilter.all),
            ),
            _FilterChipItem(
              label: '冲突',
              count: conflictCount,
              selected: selected == _MomentListFilter.conflict,
              onTap: () => onChanged(_MomentListFilter.conflict),
              activeColor: Colors.red,
            ),
            _FilterChipItem(
              label: '待上传',
              count: pendingUploadCount,
              selected: selected == _MomentListFilter.pendingUpload,
              onTap: () => onChanged(_MomentListFilter.pendingUpload),
              activeColor: Colors.orange,
            ),
            _FilterChipItem(
              label: '仅本地',
              count: localOnlyCount,
              selected: selected == _MomentListFilter.localOnly,
              onTap: () => onChanged(_MomentListFilter.localOnly),
              activeColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChipItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return LiquidGlassPill(
      tintColor: selected ? color.withOpacity(0.18) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? color : kLiquidGlassInk,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.16)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? color : kLiquidGlassMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictQuickAction extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onPressed;

  const _ConflictQuickAction({
    required this.count,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LiquidGlassIconButton(
            icon: active
                ? Icons.filter_alt_off_outlined
                : Icons.sync_problem_outlined,
            onPressed: onPressed,
            color: active ? Colors.red.shade700 : kLiquidGlassInk,
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 48,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 12),
          const Text(
            '当前筛选条件下没有记录',
            style: TextStyle(
              fontSize: 16,
              color: kLiquidGlassMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterHint extends StatelessWidget {
  final _MomentListFilter filter;
  final int count;

  const _FilterHint({
    required this.filter,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _MomentListFilter.all => '全部记录',
      _MomentListFilter.conflict => '同步冲突',
      _MomentListFilter.pendingUpload => '待上传更新',
      _MomentListFilter.localOnly => '仅本地记录',
    };

    return LiquidGlassPill(
      child: Text(
        '当前仅显示 $label，共 $count 条',
        style: const TextStyle(
          fontSize: 12,
          color: kLiquidGlassMuted,
        ),
      ),
    );
  }
}

/// 记录卡片组件
class _MomentCard extends StatelessWidget {
  final MomentRecord record;

  const _MomentCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');
    final compactDateFormat = DateFormat('MM-dd HH:mm');
    final accent = _mediaAccent(record.mediaType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        tintColor: accent.withOpacity(0.16),
        onTap: () => context.push('/detail/${record.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 媒体类型标签和时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MediaTypeTag(mediaType: record.mediaType),
                    _SyncStateTag(syncStatus: record.syncStatus),
                  ],
                ),
                Text(
                  dateFormat.format(record.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: kLiquidGlassMuted,
                  ),
                ),
              ],
            ),
            if (record.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                record.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
            if (record.syncStatus == SyncStatus.conflict) ...[
              const SizedBox(height: 12),
              _ConflictSummary(
                record: record,
                formatter: compactDateFormat,
              ),
            ],
            if (record.hasMedia) ...[
              const SizedBox(height: 12),
              _MediaPreview(
                mediaPaths: record.mediaPaths,
                mediaType: record.mediaType,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _mediaAccent(MediaType type) {
    switch (type) {
      case MediaType.text:
        return const Color(0xFF9EC7FF);
      case MediaType.image:
        return const Color(0xFFA4E3C1);
      case MediaType.audio:
        return const Color(0xFFFFD4A6);
      case MediaType.video:
        return const Color(0xFFFFB8B8);
      case MediaType.mixed:
        return const Color(0xFFD2C2FF);
    }
  }
}

class _ConflictSummary extends StatelessWidget {
  final MomentRecord record;
  final DateFormat formatter;

  const _ConflictSummary({
    required this.record,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final localUpdatedAt = record.updatedAt ?? record.createdAt;
    final rows = <String>[
      '本地修改 ${formatter.format(localUpdatedAt)}',
      if (record.conflictRemoteUpdatedAt != null)
        '云端更新 ${formatter.format(record.conflictRemoteUpdatedAt!)}',
      if (record.lastSyncedAt != null)
        '上次同步 ${formatter.format(record.lastSyncedAt!)}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sync_problem_outlined,
            size: 18,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rows.join(' · '),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStateTag extends StatelessWidget {
  final SyncStatus syncStatus;

  const _SyncStateTag({required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color background;
    final String label;

    switch (syncStatus) {
      case SyncStatus.synced:
        color = Colors.teal;
        background = Colors.teal.withOpacity(0.1);
        label = '已同步';
        break;
      case SyncStatus.pendingUpload:
        color = Colors.orange.shade800;
        background = Colors.orange.withOpacity(0.16);
        label = '待同步更新';
        break;
      case SyncStatus.localOnly:
        color = Colors.amber.shade800;
        background = Colors.amber.withOpacity(0.18);
        label = '仅本地';
        break;
      case SyncStatus.conflict:
        color = Colors.red.shade700;
        background = Colors.red.withOpacity(0.12);
        label = '同步冲突';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 媒体类型标签
class _MediaTypeTag extends StatelessWidget {
  final MediaType mediaType;

  const _MediaTypeTag({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (mediaType) {
      case MediaType.text:
        icon = Icons.text_fields;
        color = Colors.blue;
        break;
      case MediaType.image:
        icon = Icons.image;
        color = Colors.green;
        break;
      case MediaType.audio:
        icon = Icons.mic;
        color = Colors.orange;
        break;
      case MediaType.video:
        icon = Icons.videocam;
        color = Colors.red;
        break;
      case MediaType.mixed:
        icon = Icons.layers;
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _getMediaTypeName(mediaType),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getMediaTypeName(MediaType type) {
    switch (type) {
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

/// 媒体预览
class _MediaPreview extends StatelessWidget {
  final List<String> mediaPaths;
  final MediaType mediaType;

  const _MediaPreview({
    required this.mediaPaths,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaType == MediaType.text) return const SizedBox.shrink();

    final displayPaths = mediaPaths.take(3).toList();

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          ...displayPaths.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                  right: index < displayPaths.length - 1 ? 8 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildPreviewItem(path),
              ),
            );
          }),
          if (mediaPaths.length > 3)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '+${mediaPaths.length - 3}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String path) {
    // 根据文件扩展名判断类型
    final isImage = isImageMediaPath(path);
    final isVideo = isVideoMediaPath(path);

    if (mediaType == MediaType.audio) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.orange[50],
        child: const Icon(
          Icons.audiotrack,
          color: Colors.orange,
          size: 32,
        ),
      );
    }

    if (isVideo || mediaType == MediaType.video) {
      return _VideoThumbnail(path: path);
    }

    if (isImage || mediaType == MediaType.image) {
      if (isLocalMediaPath(path)) {
        return Image.file(
          File(path),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Icon(
                Icons.broken_image,
                color: Colors.grey,
              ),
            );
          },
        );
      }
      return Image.network(
        resolveMediaUrl(path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
            ),
          );
        },
      );
    }

    // 混合类型或其他
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(
        Icons.insert_drive_file,
        color: Colors.grey,
      ),
    );
  }
}

/// 视频缩略图组件
class _VideoThumbnail extends StatefulWidget {
  final String path;

  const _VideoThumbnail({required this.path});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (!isLocalMediaPath(widget.path)) {
      return;
    }
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 160,
        quality: 75,
      );
      if (mounted && thumbnail != null) {
        setState(() {
          _thumbnailData = thumbnail;
        });
      }
    } catch (e) {
      // 缩略图生成失败，保持空白
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[800],
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_thumbnailData != null)
            Image.memory(
              _thumbnailData!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }
}
