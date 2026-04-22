import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/moment_provider.dart';
import '../widgets/liquid_glass.dart';

/// 我的Tab - 统计和设置
class MyTab extends StatelessWidget {
  const MyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('我的'),
            Text(
              '账户、统计与同步控制台',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Consumer2<AuthProvider, MomentProvider>(
        builder: (context, authProvider, momentProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserCard(user: authProvider.user),
                const SizedBox(height: 16),
                _StatisticsCard(stats: momentProvider.statistics),
                const SizedBox(height: 16),
                if (authProvider.isLoggedIn) ...[
                  _SyncStatusCard(momentProvider: momentProvider),
                  const SizedBox(height: 16),
                  _SyncActionGroup(momentProvider: momentProvider),
                  const SizedBox(height: 16),
                ],
                _SettingsSection(
                  onLogout: () => _handleLogout(context, authProvider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

class _UserCard extends StatelessWidget {
  final User? user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const LiquidGlassCard(
        child: Text('未登录'),
      );
    }

    final initial = user!.username.isNotEmpty
        ? user!.username.characters.first.toUpperCase()
        : 'U';

    return LiquidGlassCard(
      tintColor: const Color(0xFFC8DAFF),
      child: Row(
        children: [
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(30),
            tintColor: const Color(0xFFDDE8FF),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kLiquidGlassAccent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${user!.username}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '你的时光空间',
                  style: TextStyle(
                    fontSize: 13,
                    color: kLiquidGlassMuted,
                  ),
                ),
                const SizedBox(height: 12),
                LiquidGlassPill(
                  tintColor: const Color(0xFFDDE8FF),
                  child: Text(
                    'ID：${user!.id}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: kLiquidGlassMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  final Map<String, int> stats;

  const _StatisticsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tintColor: const Color(0xFFFFE6C7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '记录统计',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  '${stats['total'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: kLiquidGlassAccent,
                  ),
                ),
                const Text(
                  '总记录数',
                  style: TextStyle(
                    fontSize: 14,
                    color: kLiquidGlassMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            alignment: WrapAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.text_fields,
                label: '文字',
                count: stats['text'] ?? 0,
                color: Colors.blue,
              ),
              _StatItem(
                icon: Icons.image,
                label: '图片',
                count: stats['image'] ?? 0,
                color: Colors.green,
              ),
              _StatItem(
                icon: Icons.mic,
                label: '音频',
                count: stats['audio'] ?? 0,
                color: Colors.orange,
              ),
              _StatItem(
                icon: Icons.videocam,
                label: '视频',
                count: stats['video'] ?? 0,
                color: Colors.red,
              ),
              _StatItem(
                icon: Icons.layers,
                label: '混合',
                count: stats['mixed'] ?? 0,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  final MomentProvider momentProvider;

  const _SyncStatusCard({required this.momentProvider});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final uploadAt = momentProvider.lastUploadAt != null
        ? formatter.format(momentProvider.lastUploadAt!)
        : '暂无';
    final fetchAt = momentProvider.lastFetchAt != null
        ? formatter.format(momentProvider.lastFetchAt!)
        : '暂无';

    return LiquidGlassCard(
      tintColor: const Color(0xFFD6F2FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '同步状态',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _StatusLine(
            label: '当前动作',
            value: momentProvider.activeSyncLabel ?? '空闲',
          ),
          _StatusLine(
            label: '本地未同步',
            value: '${momentProvider.unsyncedCount} 条',
          ),
          _StatusLine(
            label: '同步冲突',
            value: '${momentProvider.conflictCount} 条',
            isError: momentProvider.conflictCount > 0,
          ),
          _StatusLine(label: '最近上传', value: uploadAt),
          _StatusLine(label: '最近拉取', value: fetchAt),
          if (momentProvider.lastUploadError != null)
            _StatusLine(
              label: '上传失败',
              value: momentProvider.lastUploadError!,
              isError: true,
            ),
          if (momentProvider.lastFetchError != null)
            _StatusLine(
              label: '拉取失败',
              value: momentProvider.lastFetchError!,
              isError: true,
            ),
        ],
      ),
    );
  }
}

class _SyncActionGroup extends StatelessWidget {
  final MomentProvider momentProvider;

  const _SyncActionGroup({required this.momentProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.cloud_download_outlined,
          title: '从云端拉取',
          subtitle: '将服务器中的时光合并到当前设备，适合新设备登录后首次同步',
          isLoading: momentProvider.isSyncing,
          onTap: momentProvider.isSyncing
              ? null
              : () async {
                  final ok = await momentProvider.fetchFromServer();
                  if (!context.mounted) return;
                  final msg = ok
                      ? '已完成云端拉取，本地列表已刷新'
                      : (momentProvider.lastFetchError ?? '云端拉取失败');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                },
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.cloud_upload_outlined,
          title: '同步到云端',
          subtitle: _syncSubtitle(momentProvider),
          isLoading: momentProvider.isSyncing,
          onTap: momentProvider.isSyncing
              ? null
              : () async {
                  await momentProvider.syncToServer();
                  if (!context.mounted) return;
                  final u = momentProvider.lastSyncUploaded;
                  final f = momentProvider.lastSyncFailed;
                  final String msg;
                  if (u == 0 && f == 0) {
                    if (momentProvider.conflictCount > 0) {
                      msg =
                          '没有可上传记录；当前有 ${momentProvider.conflictCount} 条同步冲突，请先处理冲突';
                    } else {
                      msg = '没有待同步记录（若后台仍无数据，可先“重置同步标记”再同步）';
                    }
                  } else if (f == 0) {
                    msg = momentProvider.conflictCount > 0
                        ? '已成功上传 $u 条；另有 ${momentProvider.conflictCount} 条冲突待处理'
                        : '已成功上传 $u 条，可在管理后台按该用户 ID 查看';
                  } else if (u == 0) {
                    msg = '本次上传失败 $f 条（常见原因：正文与媒体均为空、或未登录）。可点“重置同步标记”后重试';
                  } else {
                    msg = '成功 $u 条、失败 $f 条；失败原因见调试控制台';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                },
        ),
        if (momentProvider.conflictCount > 0) ...[
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.sync_problem_outlined,
            title: '按本地覆盖云端',
            subtitle:
                '将 ${momentProvider.conflictCount} 条冲突记录重新标记为待上传，下一次同步会以本地版本覆盖服务端',
            onTap: momentProvider.isSyncing
                ? null
                : () async {
                    final ok = await _confirm(
                      context,
                      title: '按本地覆盖云端',
                      content:
                          '确定将 ${momentProvider.conflictCount} 条冲突记录改为待上传吗？下一次同步会以当前设备上的本地版本覆盖服务端版本。',
                    );
                    if (ok != true || !context.mounted) return;
                    final n =
                        await momentProvider.promoteConflictMomentsForUpload();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已将 $n 条冲突记录改为待上传')),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.cloud_sync_outlined,
            title: '使用云端版本',
            subtitle:
                '用服务端最新版本覆盖 ${momentProvider.conflictCount} 条本地冲突记录，本地未上传改动会丢失',
            onTap: momentProvider.isSyncing
                ? null
                : () async {
                    final ok = await _confirm(
                      context,
                      title: '使用云端版本',
                      content:
                          '确定用服务端最新版本覆盖 ${momentProvider.conflictCount} 条本地冲突记录吗？当前设备上的未上传改动将被丢弃。',
                    );
                    if (ok != true || !context.mounted) return;
                    final n =
                        await momentProvider.resolveConflictMomentsWithRemote();
                    if (!context.mounted) return;
                    final msg = n > 0
                        ? '已使用云端版本解决 $n 条冲突'
                        : (momentProvider.lastFetchError ?? '没有可用的云端版本可覆盖当前冲突');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  },
          ),
        ],
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.replay_outlined,
          title: '重置同步标记',
          subtitle: '将全部时光重新加入同步队列，便于在修复历史状态后补齐云端数据',
          onTap: momentProvider.isSyncing
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    title: '重置同步标记',
                    content:
                        '确定将所有本地记录重新加入同步队列吗？已有 server_id 的记录会更新原云端数据；仅本地记录会按客户端 ID 幂等创建。',
                  );
                  if (ok != true || !context.mounted) return;
                  final n = await momentProvider.resetAllMomentsSyncFlags();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已重置 $n 条记录的同步标记')),
                  );
                },
        ),
      ],
    );
  }

  static String _syncSubtitle(MomentProvider provider) {
    if (provider.unsyncedCount == 0) {
      return provider.conflictCount > 0
          ? '当前没有可上传记录，但有 ${provider.conflictCount} 条冲突待处理'
          : '当前没有待上传记录';
    }

    return provider.conflictCount > 0
        ? '可上传 ${provider.unsyncedCount} 条，另有 ${provider.conflictCount} 条冲突待处理'
        : '当前还有 ${provider.unsyncedCount} 条本地未同步记录';
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: LiquidGlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: BorderRadius.circular(18),
          tintColor: const Color(0xFFDDE8FF),
          child: Icon(icon, color: kLiquidGlassAccent),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: const TextStyle(
              height: 1.45,
              color: kLiquidGlassMuted,
            ),
          ),
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded, color: kLiquidGlassMuted),
        onTap: onTap,
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _StatusLine({
    required this.label,
    required this.value,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: kLiquidGlassMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isError ? Colors.red[700] : kLiquidGlassInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: kLiquidGlassMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final VoidCallback onLogout;

  const _SettingsSection({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsItem(
            icon: Icons.logout,
            title: '退出登录',
            onTap: onLogout,
            isDestructive: true,
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.35)),
          _SettingsItem(
            icon: Icons.info_outline,
            title: '关于',
            onTap: () => _showAboutDialog(context),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.35)),
          _SettingsItem(
            icon: Icons.storage,
            title: '存储管理',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('存储管理功能开发中')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.access_time, color: kLiquidGlassAccent),
            SizedBox(width: 8),
            Text('拾光记'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 1.0.0'),
            SizedBox(height: 8),
            Text(
              '记录生活的点滴，留住美好的时光。',
              style: TextStyle(color: kLiquidGlassMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : kLiquidGlassMuted,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : kLiquidGlassInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: isDestructive
          ? null
          : const Icon(Icons.chevron_right_rounded, color: kLiquidGlassMuted),
      onTap: onTap,
    );
  }
}
