import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import '../providers/moment_provider.dart';
import '../models/moment_record.dart';

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

    _videoController = VideoPlayerController.file(File(path));
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
            body: const Center(child: Text('记录不存在')),
          );
        }

        final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm:ss');

        return Scaffold(
          appBar: AppBar(
            title: const Text('记录详情'),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(record.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 媒体类型
                _MediaTypeChip(mediaType: record.mediaType),
                const SizedBox(height: 16),

                // 文字内容
                if (record.content.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
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

                // 媒体内容
                if (record.hasMedia)
                  _MediaContent(
                    record: record,
                    audioPlayer: _audioPlayer,
                    videoController: _videoController,
                    isVideoInitialized: _isVideoInitialized,
                    initVideoPlayer: _initVideoPlayer,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, MomentProvider provider, MomentRecord record) {
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

    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color),
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
        if (path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.jpeg') || path.endsWith('.gif')) {
          return _ImageViewer(path: path);
        } else if (path.endsWith('.mp3') || path.endsWith('.m4a') || path.endsWith('.aac')) {
          return _AudioPlayer(path: path, audioPlayer: audioPlayer);
        } else if (path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi')) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
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
                    await widget.audioPlayer.play(DeviceFileSource(widget.path));
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
  bool _showController = false;

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
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _showController = !_showController);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: widget.controller!.value.aspectRatio,
            child: VideoPlayer(widget.controller!),
          ),
          if (_showController)
            Container(
              color: Colors.black38,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    if (widget.controller!.value.isPlaying) {
                      widget.controller!.pause();
                    } else {
                      widget.controller!.play();
                    }
                  });
                },
                icon: Icon(
                  widget.controller!.value.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
