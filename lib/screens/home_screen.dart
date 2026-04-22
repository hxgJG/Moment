import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'moments_tab.dart';
import 'my_tab.dart';
import '../widgets/liquid_glass.dart';

/// 首页 - 底部Tab导航
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    MomentsTab(),
    MyTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: LiquidGlassBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 18,
              child: _LiquidNavigationBar(
                currentIndex: _currentIndex,
                onChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                onAddPressed: () => context.push('/add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAddPressed;

  const _LiquidNavigationBar({
    required this.currentIndex,
    required this.onChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          borderRadius: BorderRadius.circular(32),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 0
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  label: '时光',
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
              ),
              const SizedBox(width: 92),
              Expanded(
                child: _NavItem(
                  icon: currentIndex == 1 ? Icons.person : Icons.person_outline,
                  label: '我的',
                  selected: currentIndex == 1,
                  onTap: () => onChanged(1),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -18,
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(6),
            borderRadius: BorderRadius.circular(28),
            tintColor: const Color(0xFF9EB9FF),
            child: FilledButton(
              onPressed: onAddPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(62, 62),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kLiquidGlassAccent : kLiquidGlassMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected ? Colors.white.withOpacity(0.34) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
