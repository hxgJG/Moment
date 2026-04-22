import 'dart:ui';

import 'package:flutter/material.dart';

const Color kLiquidGlassInk = Color(0xFF14213D);
const Color kLiquidGlassMuted = Color(0xFF5F6C87);
const Color kLiquidGlassAccent = Color(0xFF4D7CFE);

class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF6FAFF),
              Color(0xFFE7EEFF),
              Color(0xFFF7F1EA),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: -100,
              left: -70,
              child: _AmbientOrb(
                size: 260,
                colors: [
                  Color(0x99A7C8FF),
                  Color(0x44FFFFFF),
                ],
              ),
            ),
            const Positioned(
              top: 120,
              right: -90,
              child: _AmbientOrb(
                size: 280,
                colors: [
                  Color(0x88FFD7A8),
                  Color(0x33FFFFFF),
                ],
              ),
            ),
            const Positioned(
              bottom: -120,
              left: 40,
              child: _AmbientOrb(
                size: 320,
                colors: [
                  Color(0x6666D0FF),
                  Color(0x22FFFFFF),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color tintColor;
  final double blurSigma;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.tintColor = Colors.white,
    this.blurSigma = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tintColor.withOpacity(0.32),
                Colors.white.withOpacity(0.16),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.42),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return surface;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: surface,
      ),
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color = kLiquidGlassInk,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 16,
      onTap: onPressed,
      child: Icon(icon, size: size, color: color),
    );
  }
}

class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final Color tintColor;
  final EdgeInsetsGeometry padding;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.tintColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: padding,
      blurSigma: 14,
      borderRadius: BorderRadius.circular(999),
      tintColor: tintColor,
      child: child,
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _AmbientOrb({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}
