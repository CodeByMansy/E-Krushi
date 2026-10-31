// Ported from ui/screens/SplashScreen.kt
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 600 + 900), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ScaleTransition(
                scale: _scale,
                child: Icon(
                  Icons.spa,
                  color: colorScheme.primary,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'e-krushi',
              style: textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Smart Plant Disease Detection',
              style: textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
