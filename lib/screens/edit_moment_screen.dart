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

/// 编辑记录页面
class EditMomentScreen extends StatefulWidget {
  final String recordId;

  const EditMomentScreen({super.key, required this.recordId});

  @override
  State<EditMomentScreen> createState() => _EditMomentScreenState();
}

class _EditMomentScreenState extends State<EditMomentScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<String> _mediaPaths = [];
  MediaType _mediaType = MediaType.text;
  bool _isRecording = false;
  String? _recordingPath;
  bool _isSaving = false;
  MomentRecord? _originalRecord;
  final Set<String> _sessionMediaPaths = <String>{};
  final Set<String> _removedLocalMediaPaths = <String>{};
  bool _didSave = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  void _loadRecord() {
    final provider = context.read<MomentProvider>();
    final record = provider.getMomentById(widget.recordId);
    if (record != null) {
      _originalRecord = record;
      _contentController.text = record.content;
      _mediaPaths = List.from(record.mediaPaths);
      _mediaType = record.mediaType;
      setState(() {});
    }
  }

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
    if (_sessionMediaPaths.remove(path)) {
      unawaited(deleteLocalMediaFileIfExists(path));
    } else if (isLocalMediaPath(path)) {
      _removedLocalMediaPaths.add(path);
    }
    setState(() {
      _mediaPaths.removeAt(index);
      _updateMediaType();
    });
  }

  /// 保存修改
  Future<void> _saveMoment() async {
    if (_originalRecord == null) {
      _showError('原始记录不存在，无法保存');
      return;
    }
    if (_contentController.text.isEmpty && _mediaPaths.isEmpty) {
      _showError('请输入内容或添加媒体');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<MomentProvider>();

      // 更新记录
      final updatedRecord = _originalRecord!.copyWith(
        content: _contentController.text,
        updatedAt: DateTime.now(),
        mediaType: _mediaType,
        mediaPaths: _mediaPaths,
        synced: false,
      );

      final success = await provider.updateMoment(updatedRecord);

      if (success && mounted) {
        _didSave = true;
        for (final path in _removedLocalMediaPaths) {
          unawaited(deleteLocalMediaFileIfExists(path));
        }
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
    final conflictRemoteUpdatedAt = _originalRecord?.conflictRemoteUpdatedAt;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: LiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EditorPageHeader(
                title: '编辑记录',
                subtitle: '继续雕琢这块回忆玻璃',
                action: TextButton(
                  onPressed: _isSaving ? null : _saveMoment,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_originalRecord?.syncStatus ==
                          SyncStatus.conflict) ...[
                        LiquidGlassCard(
                          tintColor: const Color(0xFFFFE0B2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.sync_problem_outlined,
                                color: Colors.orange[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  conflictRemoteUpdatedAt != null
                                      ? '这条记录当前处于同步冲突状态。系统检测到云端版本在 ${conflictRemoteUpdatedAt.toLocal()} 后发生了更新；继续编辑会保留本地版本，并在你确认后用于覆盖云端。'
                                      : '这条记录当前处于同步冲突状态。继续编辑会保留本地版本，并在你确认后用于覆盖云端。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                              onPickImage: () =>
                                  _pickImage(ImageSource.gallery),
                              onPickCameraImage: () =>
                                  _pickImage(ImageSource.camera),
                              onPickVideo: () =>
                                  _pickVideo(ImageSource.gallery),
                              onPickCameraVideo: () =>
                                  _pickVideo(ImageSource.camera),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;

  const _EditorPageHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: LiquidGlassCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        borderRadius: BorderRadius.circular(24),
        tintColor: const Color(0xFFF6FAFF),
        blurSigma: 18,
        child: Row(
          children: [
            LiquidGlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 18,
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kLiquidGlassMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            action,
          ],
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
    final isImage = isImageMediaPath(path);
    final isVideo = isVideoMediaPath(path);
    final isAudio = isAudioMediaPath(path);

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
                  ? (isLocalMediaPath(path)
                      ? Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        )
                      : Image.network(
                          resolveMediaUrl(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ))
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
      spacing: 10,
      runSpacing: 10,
      children: [
        _MediaButton(
          icon: Icons.photo_library,
          label: '相册图片',
          color: const Color(0xFF5BAE68),
          onTap: onPickImage,
        ),
        _MediaButton(
          icon: Icons.camera_alt,
          label: '拍照',
          color: const Color(0xFF4D8FF7),
          onTap: onPickCameraImage,
        ),
        _MediaButton(
          icon: Icons.videocam,
          label: '视频',
          color: const Color(0xFFF06A5F),
          onTap: onPickVideo,
        ),
        _MediaButton(
          icon: Icons.videocam_outlined,
          label: '录像',
          color: const Color(0xFFE6A14A),
          onTap: onPickCameraVideo,
        ),
        _MediaButton(
          icon: isRecording ? Icons.stop : Icons.mic,
          label: isRecording ? '停止' : '录音',
          color: const Color(0xFF8B67D6),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(20),
      tintColor: isActive ? color.withOpacity(0.16) : const Color(0xFFF7FAFF),
      onTap: onTap,
      child: SizedBox(
        width: 144,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(isActive ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: kLiquidGlassInk,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
