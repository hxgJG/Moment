import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import '../providers/moment_provider.dart';
import '../models/moment_record.dart';
import '../utils/media_source.dart';
import '../widgets/liquid_glass.dart';

/// 记录详情页
class MomentDetailScreen extends StatefulWidget {
  final String recordId;

  const MomentDetailScreen({super.key, required this.recordId});

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer(String path) async {
    if (_videoController != null) return;

    if (isLocalMediaPath(path)) {
      _videoController = VideoPlayerController.file(File(path));
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(resolveMediaUrl(path)),
      );
    }
    await _videoController!.initialize();
    setState(() {
      _isVideoInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MomentProvider>(
      builder: (context, provider, child) {
        final record = provider.getMomentById(widget.recordId);

        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('详情')),
            body: const LiquidGlassBackground(
              child: Center(
                child: LiquidGlassCard(child: Text('记录不存在')),
              ),
            ),
          );
        }

        final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm:ss');

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('记录详情'),
                Text(
                  '查看这段回忆的完整折射',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/edit/${record.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showDeleteDialog(context, provider, record),
              ),
            ],
          ),
          body: LiquidGlassBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiquidGlassCard(
                    tintColor: const Color(0xFFCFE0FF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(record.createdAt),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MediaTypeChip(mediaType: record.mediaType),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (record.syncStatus == SyncStatus.conflict) ...[
                    _ConflictNotice(
                      record: record,
                      provider: provider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (record.content.isNotEmpty) ...[
                    LiquidGlassCard(
                      child: Text(
                        record.content,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (record.hasMedia)
                    LiquidGlassCard(
                      tintColor: const Color(0xFFFFE6C7),
                      child: _MediaContent(
                        record: record,
                        audioPlayer: _audioPlayer,
                        videoController: _videoController,
                        isVideoInitialized: _isVideoInitialized,
                        initVideoPlayer: _initVideoPlayer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(
      BuildContext context, MomentProvider provider, MomentRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              context.pop();
              await provider.deleteMoment(record.id);
              if (context.mounted) {
                context.pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ConflictNotice extends StatelessWidget {
  final MomentRecord record;
  final MomentProvider provider;

  const _ConflictNotice({
    required this.record,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final localUpdatedAt = record.updatedAt ?? record.createdAt;
    final lastSyncedAt = record.lastSyncedAt;
    final remoteUpdatedAt = record.conflictRemoteUpdatedAt;

    return LiquidGlassCard(
      tintColor: const Color(0xFFFFD7D7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_problem_outlined, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                '这条记录存在同步冲突',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '当前设备上的本地修改和服务端版本都发生了变化。你可以选择保留本地版本继续上传，或直接使用最新云端版本覆盖本地。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '本地最近修改：${formatter.format(localUpdatedAt)}',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.red[700],
            ),
          ),
          if (lastSyncedAt != null)
            Text(
              '最近成功同步：${formatter.format(lastSyncedAt)}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.red[700],
              ),
            ),
          if (remoteUpdatedAt != null)
            Text(
              '检测到云端更新：${formatter.format(remoteUpdatedAt)}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.red[700],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: provider.isSyncing
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('保留本地版本'),
                            content: const Text(
                              '确定将这条冲突记录改为待上传吗？下一次同步会以当前设备上的本地版本覆盖服务端版本。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        final success = await provider
                            .promoteConflictMomentForUpload(record.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? '已改为待上传，下一次同步会保留本地版本' : '处理失败',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.upload_outlined),
                label: const Text('保留本地版本'),
              ),
              OutlinedButton.icon(
                onPressed: provider.isSyncing
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('使用云端版本'),
                            content: const Text(
                              '确定使用服务端最新版本覆盖当前这条本地冲突记录吗？这条记录的本地未上传改动将被丢弃。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        final success =
                            await provider.resolveConflictMomentWithRemote(
                          record.id,
                        );
                        if (!context.mounted) return;
                        final message = success
                            ? '已使用云端版本覆盖当前记录'
                            : (provider.lastFetchError ?? '处理失败');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      },
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('使用云端版本'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 媒体类型标签
class _MediaTypeChip extends StatelessWidget {
  final MediaType mediaType;

  const _MediaTypeChip({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (mediaType) {
      case MediaType.text:
        icon = Icons.text_fields;
        color = Colors.blue;
        label = '文字';
        break;
      case MediaType.image:
        icon = Icons.image;
        color = Colors.green;
        label = '图片';
        break;
      case MediaType.audio:
        icon = Icons.mic;
        color = Colors.orange;
        label = '音频';
        break;
      case MediaType.video:
        icon = Icons.videocam;
        color = Colors.red;
        label = '视频';
        break;
      case MediaType.mixed:
        icon = Icons.layers;
        color = Colors.purple;
        label = '混合';
        break;
    }

    return LiquidGlassPill(
      tintColor: color.withOpacity(0.14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 媒体内容展示
class _MediaContent extends StatelessWidget {
  final MomentRecord record;
  final AudioPlayer audioPlayer;
  final VideoPlayerController? videoController;
  final bool isVideoInitialized;
  final Function(String) initVideoPlayer;

  const _MediaContent({
    required this.record,
    required this.audioPlayer,
    required this.videoController,
    required this.isVideoInitialized,
    required this.initVideoPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '媒体内容',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...record.mediaPaths.asMap().entries.map((entry) {
          final index = entry.key;
          final path = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMediaItem(context, path, index),
          );
        }),
      ],
    );
  }

  Widget _buildMediaItem(BuildContext context, String path, int index) {
    switch (record.mediaType) {
      case MediaType.image:
        return _ImageViewer(path: path);
      case MediaType.audio:
        return _AudioPlayer(path: path, audioPlayer: audioPlayer);
      case MediaType.video:
        return _VideoPlayer(
          path: path,
          controller: videoController,
          isInitialized: isVideoInitialized,
          initPlayer: () => initVideoPlayer(path),
        );
      case MediaType.mixed:
        // 混合类型需要根据文件扩展名判断
        if (isImageMediaPath(path)) {
          return _ImageViewer(path: path);
        } else if (isAudioMediaPath(path)) {
          return _AudioPlayer(path: path, audioPlayer: audioPlayer);
        } else if (isVideoMediaPath(path)) {
          return _VideoPlayer(
            path: path,
            controller: videoController,
            isInitialized: isVideoInitialized,
            initPlayer: () => initVideoPlayer(path),
          );
        }
        return const SizedBox.shrink();
      case MediaType.text:
        return const SizedBox.shrink();
    }
  }
}

/// 图片查看器
class _ImageViewer extends StatelessWidget {
  final String path;

  const _ImageViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: isLocalMediaPath(path)
          ? Image.file(
              File(path),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child:
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                );
              },
            )
          : Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child:
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}

/// 音频播放器
class _AudioPlayer extends StatefulWidget {
  final String path;
  final AudioPlayer audioPlayer;

  const _AudioPlayer({required this.path, required this.audioPlayer});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  void _setupPlayer() {
    widget.audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    widget.audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tintColor: const Color(0xFFFFE6C7),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () async {
                  if (_isPlaying) {
                    await widget.audioPlayer.pause();
                  } else {
                    if (isLocalMediaPath(widget.path)) {
                      await widget.audioPlayer
                          .play(DeviceFileSource(widget.path));
                    } else {
                      await widget.audioPlayer.play(
                        UrlSource(resolveMediaUrl(widget.path)),
                      );
                    }
                  }
                  if (mounted) {
                    setState(() => _isPlaying = !_isPlaying);
                  }
                },
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          Slider(
            value: _position.inSeconds.toDouble(),
            max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
            onChanged: (value) async {
              await widget.audioPlayer.seek(Duration(seconds: value.toInt()));
            },
            activeColor: Colors.orange,
            inactiveColor: Colors.orange[200],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// 视频播放器
class _VideoPlayer extends StatefulWidget {
  final String path;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final VoidCallback initPlayer;

  const _VideoPlayer({
    required this.path,
    required this.controller,
    required this.isInitialized,
    required this.initPlayer,
  });

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  @override
  void initState() {
    super.initState();
    widget.initPlayer();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInitialized || widget.controller == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (widget.controller!.value.isPlaying) {
              widget.controller!.pause();
            } else {
              widget.controller!.play();
            }
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: widget.controller!.value.aspectRatio,
              child: VideoPlayer(widget.controller!),
            ),
            // 未播放时显示中心播放按钮
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.controller!,
              builder: (context, value, child) {
                if (value.isPlaying) {
                  return const SizedBox.shrink();
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 56,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
