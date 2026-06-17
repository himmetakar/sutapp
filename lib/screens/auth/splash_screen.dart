import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  final List<MilkParticle> _particles = [];
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    
    // Logo entrance and heartbeat animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Particle animation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (kIsWeb) {
      // Immediately navigate without any delay or animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToNext();
        }
      });
      return;
    }

    _logoController.forward();

    // After 2 seconds, start the milk droplet dispersion animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _startDropletsAnimation();
      }
    });
  }

  void _navigateToNext() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn) {
      switch (auth.user!.role) {
        case UserRole.admin:
          context.go('/admin');
          break;
        case UserRole.firma:
          context.go('/firma');
          break;
        case UserRole.surucu:
          context.go('/surucu');
          break;
        case UserRole.uretici:
          context.go('/uretici');
          break;
      }
    } else {
      context.go('/login');
    }
  }

  void _startDropletsAnimation() {
    setState(() {
      _isTransitioning = true;
    });

    // Initialize milk droplets starting from the logo area
    final random = math.Random();
    const int particleCount = 45;
    
    for (int i = 0; i < particleCount; i++) {
      // Angle in radians (mostly downwards and outwards)
      final double angle = random.nextDouble() * 2 * math.pi;
      final double speed = 3.0 + random.nextDouble() * 7.0;
      final double radius = 4.0 + random.nextDouble() * 12.0;
      
      _particles.add(MilkParticle(
        x: 0, // centered relative to logo
        y: 0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed + 3.0, // bias downwards with gravity
        radius: radius,
        color: Colors.white.withValues(alpha: 0.85 + random.nextDouble() * 0.15),
      ));
    }

    _particleController.forward().then((_) {
      _navigateToNext();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: Stack(
          children: [
            // Center Logo and slogan
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_logoController, _particleController]),
                builder: (context, child) {
                  // Logo scale & fade out
                  double scale = 1.0;
                  double opacity = 1.0;

                  if (!_isTransitioning) {
                    // Slight breathing / entrance scale effect
                    scale = 0.95 + 0.05 * math.sin(_logoController.value * math.pi);
                  } else {
                    // During transition: fade out and shrink slightly
                    opacity = 1.0 - _particleController.value;
                    scale = 1.0 - _particleController.value * 0.15;
                  }

                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          'assets/images/logo+slogan.png',
                          width: screenSize.width * 0.75,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Custom Painter overlay for milk particles
            if (_isTransitioning)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: MilkDropletsPainter(
                        particles: _particles,
                        progress: _particleController.value,
                        center: Offset(screenSize.width / 2, screenSize.height / 2),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MilkParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;

  MilkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });

  void update(double gravity) {
    x += vx;
    y += vy;
    vy += gravity; // Apply gravity over time
  }
}

class MilkDropletsPainter extends CustomPainter {
  final List<MilkParticle> particles;
  final double progress;
  final Offset center;

  MilkDropletsPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Update and draw each particle
    for (var particle in particles) {
      // Calculate current positions based on animation progress
      // Gravity pulls droplets down
      const double gravity = 0.25;
      
      // We simulate physics up to the current progress frame
      double posX = center.dx + particle.x + (particle.vx * progress * 30);
      double posY = center.dy + particle.y + (particle.vy * progress * 30) + (0.5 * gravity * progress * progress * 900);
      
      // Fade particles as they spread
      double particleOpacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = particle.color.withValues(alpha: particle.color.opacity * particleOpacity);
      
      // Shrink particles slightly at the end
      double currentRadius = particle.radius * (1.0 - progress * 0.3);
      
      // Draw droplet as a smooth circle
      canvas.drawCircle(Offset(posX, posY), currentRadius, paint);
      
      // Optionally draw a tiny tail/secondary circle above it to make it look like a droplet
      if (currentRadius > 4.0) {
        canvas.drawCircle(
          Offset(posX, posY - currentRadius * 0.6), 
          currentRadius * 0.6, 
          paint
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MilkDropletsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
