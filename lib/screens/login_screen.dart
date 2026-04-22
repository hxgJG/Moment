import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/liquid_glass.dart';

/// 登录页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLogin = true; // true=登录，false=注册
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isLogin) {
      success = await authProvider.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await authProvider.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
      );
    }

    if (success && mounted) {
      context.go('/');
    }
  }

  Color get _pageBackground =>
      _isLogin ? const Color(0xFFC8E6C9) : const Color(0xFFFFE082);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 760;
    final topInset = isCompact ? 14.0 : (size.height * 0.045).clamp(16.0, 34.0);
    final cardPadding = isCompact ? 22.0 : 24.0;
    final fieldGap = isCompact ? 12.0 : 14.0;

    return Scaffold(
      body: LiquidGlassBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: topInset, bottom: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Form(
                          key: _formKey,
                          child: LiquidGlassCard(
                            padding: EdgeInsets.all(cardPadding),
                            tintColor: _pageBackground,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: LiquidGlassCard(
                                    padding: const EdgeInsets.all(16),
                                    borderRadius: BorderRadius.circular(24),
                                    tintColor: _pageBackground,
                                    child: const Icon(
                                      Icons.access_time_filled_rounded,
                                      size: 38,
                                      color: kLiquidGlassAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '拾光记',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Text(
                                    _isLogin
                                        ? '像一块漂浮玻璃，装下今天的情绪、图像与声音。'
                                        : '创建一个空间，把散落的片段重新折射成回忆。',
                                    key: ValueKey(_isLogin),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: kLiquidGlassMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                LiquidGlassCard(
                                  padding: const EdgeInsets.all(5),
                                  borderRadius: BorderRadius.circular(20),
                                  blurSigma: 14,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _ModeButton(
                                          label: '登录',
                                          selected: _isLogin,
                                          onTap: () {
                                            context
                                                .read<AuthProvider>()
                                                .clearError();
                                            setState(() {
                                              _isLogin = true;
                                            });
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: _ModeButton(
                                          label: '注册',
                                          selected: !_isLogin,
                                          onTap: () {
                                            context
                                                .read<AuthProvider>()
                                                .clearError();
                                            setState(() {
                                              _isLogin = false;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Consumer<AuthProvider>(
                                  builder: (context, auth, child) {
                                    return AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: auth.error == null
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              key: ValueKey(auth.error),
                                              padding: const EdgeInsets.only(
                                                bottom: 14,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  color: Colors.red
                                                      .withOpacity(0.08),
                                                  border: Border.all(
                                                    color: Colors.red
                                                        .withOpacity(0.18),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        auth.error!,
                                                        style: TextStyle(
                                                          color: Colors
                                                              .red.shade700,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.copy_rounded,
                                                        color:
                                                            Colors.red.shade700,
                                                        size: 18,
                                                      ),
                                                      onPressed: () {
                                                        Clipboard.setData(
                                                          ClipboardData(
                                                            text: auth.error!,
                                                          ),
                                                        );
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              '已复制到剪贴板',
                                                            ),
                                                            duration: Duration(
                                                              seconds: 1,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      tooltip: '复制错误信息',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    );
                                  },
                                ),
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: '用户名',
                                    prefixIcon:
                                        Icon(Icons.person_outline_rounded),
                                  ),
                                  validator: (value) {
                                    final t = value?.trim() ?? '';
                                    if (t.isEmpty) {
                                      return '请输入用户名';
                                    }
                                    if (!_isLogin) {
                                      if (t.length < 3) {
                                        return '用户名至少 3 个字符';
                                      }
                                      if (t.length > 50) {
                                        return '用户名最多 50 个字符';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: fieldGap),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: _isLogin
                                        ? const SizedBox.shrink(
                                            key: ValueKey('nickname-empty'),
                                          )
                                        : Padding(
                                            key: const ValueKey(
                                              'register-field',
                                            ),
                                            padding: EdgeInsets.only(
                                              bottom: fieldGap,
                                            ),
                                            child: TextFormField(
                                              controller: _nicknameController,
                                              decoration: const InputDecoration(
                                                labelText: '昵称',
                                                prefixIcon: Icon(
                                                  Icons.badge_outlined,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (!_isLogin &&
                                                    (value == null ||
                                                        value.trim().isEmpty)) {
                                                  return '请输入昵称';
                                                }
                                                if (!_isLogin &&
                                                    value != null &&
                                                    value.trim() ==
                                                        _passwordController
                                                            .text) {
                                                  return '昵称不能与密码相同';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    labelText: '密码',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入密码';
                                    }
                                    if (value.length < 6) {
                                      return '密码至少6位';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: isCompact ? 18 : 20),
                                Consumer<AuthProvider>(
                                  builder: (context, auth, child) {
                                    return FilledButton(
                                      onPressed:
                                          auth.isLoading ? null : _submit,
                                      child: auth.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isLogin ? '进入时光流' : '创建时光空间',
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () {
                                    context.read<AuthProvider>().clearError();
                                    setState(() {
                                      _isLogin = !_isLogin;
                                    });
                                  },
                                  child: Text(
                                    _isLogin ? '还没有账户？立即注册' : '已有账户？立即登录',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? const Color(0xFF4D7CFE).withOpacity(0.16)
              : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? kLiquidGlassAccent : kLiquidGlassMuted,
          ),
        ),
      ),
    );
  }
}
