import 'dart:math' as math;
import 'package:flutter/material.dart';

class MilkLoadingIndicator extends StatefulWidget {
  final double size;
  final Duration duration;

  const MilkLoadingIndicator({
    super.key,
    this.size = 100.0,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<MilkLoadingIndicator> createState() => _MilkLoadingIndicatorState();
}

class _MilkLoadingIndicatorState extends State<MilkLoadingIndicator> with TickerProviderStateMixin {
  late AnimationController _fillController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _fillController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fillController, _waveController]),
      builder: (context, child) {
        double fillValue = _fillController.value;
        
        // Define animation cycle phases:
        // 0.0 - 0.75: Fill milk from bottom to top (0.0 to 1.0)
        // 0.75 - 0.90: Stay full (1.0)
        // 0.90 - 1.0: Fade out / reset
        double displayFill;
        double opacity = 1.0;
        
        if (fillValue < 0.75) {
          displayFill = fillValue / 0.75;
        } else if (fillValue < 0.90) {
          displayFill = 1.0;
        } else {
          displayFill = 1.0;
          opacity = 1.0 - ((fillValue - 0.90) / 0.10);
        }

        double wavePhase = _waveController.value * 2 * math.pi;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Background empty bottle silhouette (low opacity)
              Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/bottle.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              ),
              // 2. White milk level filling up inside the bottle
              Opacity(
                opacity: opacity,
                child: ClipPath(
                  clipper: MilkBottleClipper(displayFill, wavePhase),
                  child: Image.asset(
                    'assets/images/bottle.png',
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
              // 3. Foreground details (bottle borders, reflections) at low opacity for depth
              Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/images/bottle.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MilkBottleClipper extends CustomClipper<Path> {
  final double fillValue; // 0.0 to 1.0
  final double wavePhase;

  MilkBottleClipper(this.fillValue, this.wavePhase);

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // In Flutter y=0 is top, y=height is bottom.
    // Map fillValue from 0.0 (empty -> y=height) to 1.0 (full -> y=0)
    final fillHeight = size.height * (1.0 - fillValue);

    path.moveTo(0, size.height);
    path.lineTo(0, fillHeight);

    if (fillValue > 0.0 && fillValue < 1.0) {
      for (double x = 0; x <= size.width; x++) {
        // Wave height is larger in the middle and decreases at the very top and bottom
        final waveAmplitude = 4.0 * math.sin(fillValue * math.pi);
        final y = fillHeight + waveAmplitude * math.sin((x / size.width * 2.0 * math.pi) + wavePhase);
        path.lineTo(x, y);
      }
    } else {
      path.lineTo(size.width, fillHeight);
    }

    path.lineTo(size.width, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant MilkBottleClipper oldClipper) {
    return oldClipper.fillValue != fillValue || oldClipper.wavePhase != wavePhase;
  }
}

/// Helper dialog overlay for full-screen loading states
class MilkLoadingOverlay extends StatelessWidget {
  final String? message;
  
  const MilkLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Premium dark mode background
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MilkLoadingIndicator(size: 80),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show loading overlay as a dialog route
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: MilkLoadingOverlay(message: message),
        ),
      ),
    );
  }

  /// Hide the loading overlay
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
