import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../providers/moment_provider.dart';
import '../models/moment_record.dart';
import '../utils/media_source.dart';
import '../widgets/liquid_glass.dart';

/// 添加记录页面
class AddMomentScreen extends StatefulWidget {
  const AddMomentScreen({super.key});

  @override
  State<AddMomentScreen> createState() => _AddMomentScreenState();
}

class _AddMomentScreenState extends State<AddMomentScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final List<String> _mediaPaths = [];
  MediaType _mediaType = MediaType.text;
  bool _isRecording = false;
  String? _recordingPath;
  bool _isSaving = false;
  final Set<String> _sessionMediaPaths = <String>{};
  bool _didSave = false;

  @override
  void dispose() {
    if (!_didSave) {
      for (final path in _sessionMediaPaths) {
        unawaited(deleteLocalMediaFileIfExists(path));
      }
    }
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        final savedPath = await _saveMediaToAppDir(image.path);
        _sessionMediaPaths.add(savedPath);
        setState(() {
          _mediaPaths.add(savedPath);
          _updateMediaType();
        });
      }
    } catch (e) {
      _showError('选择图片失败: $e');
    }
  }

  /// 选择视频
  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );
      if (video != null) {
        final savedPath = await _saveMediaToAppDir(video.path);
        _sessionMediaPaths.add(savedPath);
        setState(() {
          _mediaPaths.add(savedPath);
          _updateMediaType();
        });
      }
    } catch (e) {
      _showError('选择视频失败: $e');
    }
  }

  /// 保存媒体文件到应用目录
  Future<String> _saveMediaToAppDir(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final destPath = '${mediaDir.path}/$fileName';

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// 更新媒体类型
  void _updateMediaType() {
    _mediaType = inferMediaTypeFromPaths(_mediaPaths);
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      // 请求麦克风权限
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showError('需要麦克风权限才能录音');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      _recordingPath =
          '${audioDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      _showError('开始录音失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordingPath != null) {
        _sessionMediaPaths.add(_recordingPath!);
        setState(() {
          _mediaPaths.add(_recordingPath!);
          _updateMediaType();
        });
      }
    } catch (e) {
      _showError('停止录音失败: $e');
    }
  }

  /// 删除媒体
  void _removeMedia(int index) {
    final path = _mediaPaths[index];
    _sessionMediaPaths.remove(path);
    unawaited(deleteLocalMediaFileIfExists(path));
    setState(() {
      _mediaPaths.removeAt(index);
      _updateMediaType();
    });
  }

  /// 保存记录
  Future<void> _saveMoment() async {
    if (_contentController.text.isEmpty && _mediaPaths.isEmpty) {
      _showError('请输入内容或添加媒体');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<MomentProvider>();
      final success = await provider.addMoment(
        content: _contentController.text,
        mediaType: _mediaType,
        mediaPaths: _mediaPaths,
      );

      if (success && mounted) {
        _didSave = true;
        context.pop();
      } else if (mounted) {
        _showError(provider.error ?? '保存失败');
      }
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('添加记录'),
            Text(
              '把今天折射成一块新的玻璃切片',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveMoment,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiquidGlassCard(
                tintColor: Color(0xFFCFE0FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '新的时光片段',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '支持文字、图片、视频和录音。卡片会像液态玻璃一样叠加出内容层次。',
                      style: TextStyle(
                        color: kLiquidGlassMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                child: TextField(
                  controller: _contentController,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    hintText: '记录今天的点滴...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_mediaPaths.isNotEmpty) ...[
                LiquidGlassCard(
                  child: _MediaPreviewGrid(
                    mediaPaths: _mediaPaths,
                    onRemove: _removeMedia,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              LiquidGlassCard(
                tintColor: const Color(0xFFFFE6C7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '添加媒体',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MediaButtons(
                      isRecording: _isRecording,
                      onPickImage: () => _pickImage(ImageSource.gallery),
                      onPickCameraImage: () => _pickImage(ImageSource.camera),
                      onPickVideo: () => _pickVideo(ImageSource.gallery),
                      onPickCameraVideo: () => _pickVideo(ImageSource.camera),
                      onStartRecording: _startRecording,
                      onStopRecording: _stopRecording,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 媒体预览网格
class _MediaPreviewGrid extends StatelessWidget {
  final List<String> mediaPaths;
  final Function(int) onRemove;

  const _MediaPreviewGrid({
    required this.mediaPaths,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mediaPaths.asMap().entries.map((entry) {
        final index = entry.key;
        final path = entry.value;
        return _MediaThumbnail(path: path, onRemove: () => onRemove(index));
      }).toList(),
    );
  }
}

/// 媒体缩略图
class _MediaThumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _MediaThumbnail({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isImage = path.endsWith('.jpg') ||
        path.endsWith('.png') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif');
    final isVideo = path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.webm');
    final isAudio = path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.wav');

    return Stack(
      children: [
        LiquidGlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 100,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isImage
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    )
                  : isVideo
                      ? const Center(child: Icon(Icons.videocam, size: 32))
                      : isAudio
                          ? const Center(
                              child: Icon(Icons.audiotrack, size: 32))
                          : const Icon(Icons.insert_drive_file),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 媒体添加按钮
class _MediaButtons extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPickImage;
  final VoidCallback onPickCameraImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickCameraVideo;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const _MediaButtons({
    required this.isRecording,
    required this.onPickImage,
    required this.onPickCameraImage,
    required this.onPickVideo,
    required this.onPickCameraVideo,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MediaButton(
          icon: Icons.photo_library,
          label: '相册图片',
          color: Colors.green,
          onTap: onPickImage,
        ),
        _MediaButton(
          icon: Icons.camera_alt,
          label: '拍照',
          color: Colors.blue,
          onTap: onPickCameraImage,
        ),
        _MediaButton(
          icon: Icons.videocam,
          label: '视频',
          color: Colors.red,
          onTap: onPickVideo,
        ),
        _MediaButton(
          icon: Icons.videocam_outlined,
          label: '录像',
          color: Colors.orange,
          onTap: onPickCameraVideo,
        ),
        _MediaButton(
          icon: isRecording ? Icons.stop : Icons.mic,
          label: isRecording ? '停止' : '录音',
          color: Colors.purple,
          onTap: isRecording ? onStopRecording : onStartRecording,
          isActive: isRecording,
        ),
      ],
    );
  }
}

/// 媒体按钮
class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      tintColor: isActive ? color.withOpacity(0.18) : Colors.white,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
