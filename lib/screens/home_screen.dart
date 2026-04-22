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
              bottom: bottomInset + 8,
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
    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      borderRadius: BorderRadius.circular(24),
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
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAddPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFF5F8FFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.add_rounded, size: 20),
          ),
          const SizedBox(width: 8),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? Colors.white.withOpacity(0.34)
              : Colors.white.withOpacity(0.14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
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
