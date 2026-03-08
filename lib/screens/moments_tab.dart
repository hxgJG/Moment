import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/moment_provider.dart';
import '../models/moment_record.dart';
import 'moment_detail_screen.dart';

/// 时光Tab - 显示所有记录列表
class MomentsTab extends StatelessWidget {
  const MomentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '拾光记',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<MomentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.initialize(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (provider.moments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_album_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有记录',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加第一条记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.initialize(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.moments.length,
              itemBuilder: (context, index) {
                final record = provider.moments[index];
                return _MomentCard(record: record);
              },
            ),
          );
        },
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MomentDetailScreen(recordId: record.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 媒体类型标签和时间
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MediaTypeTag(mediaType: record.mediaType),
                  Text(
                    dateFormat.format(record.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
              // 媒体预览
              if (record.hasMedia) ...[
                const SizedBox(height: 12),
                _MediaPreview(mediaPaths: record.mediaPaths, mediaType: record.mediaType),
              ],
            ],
          ),
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
          ...displayPaths.map((path) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPreviewItem(path),
            ),
          )),
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

    return Image.asset(
      path,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          path,
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
      },
    );
  }
}
