import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_colors.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/constants/app_constants.dart';

/// The PIXORA mark: the four-point sparkle that also drives the launcher icon,
/// drawn with [CustomPainter] so it stays crisp at every size and costs no
/// image memory on low-RAM devices.
class PixoraLogo extends StatelessWidget {
  const PixoraLogo({this.size = 44, this.showGlow = true, super.key});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: palette.brandLinearGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.brandViolet.withValues(alpha: 0.32),
                  blurRadius: size * 0.55,
                  offset: Offset(0, size * 0.16),
                  spreadRadius: -size * 0.08,
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.46),
          painter: const _SparklePainter(),
        ),
      ),
    );
  }
}

/// The PIXORA wordmark.
class PixoraWordmark extends StatelessWidget {
  const PixoraWordmark({this.color, this.fontSize = 18, super.key});

  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppConstants.appName,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: fontSize * 0.2,
          ),
    );
  }
}

/// Paints a four-point sparkle with concave sides.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final Path path = Path()
      ..moveTo(width * 0.5, 0)
      ..quadraticBezierTo(width * 0.58, height * 0.42, width, height * 0.5)
      ..quadraticBezierTo(width * 0.58, height * 0.58, width * 0.5, height)
      ..quadraticBezierTo(width * 0.42, height * 0.58, 0, height * 0.5)
      ..quadraticBezierTo(width * 0.42, height * 0.42, width * 0.5, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => false;
}
