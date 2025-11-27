import 'package:flutter/material.dart';

/// Widget that wraps a child with fade and slide transition animation
/// 
/// Useful for animating items appearing in lists (e.g., series cards)
class FadeSlideTransition extends StatefulWidget {
  /// The child widget to animate
  final Widget child;
  
  /// Delay before animation starts (in milliseconds)
  final int delay;
  
  /// Duration of the animation (default: 300ms)
  final Duration duration;
  
  /// Direction of slide animation (default: from right)
  final SlideDirection direction;
  
  /// Offset distance for slide animation (default: 20.0)
  final double offset;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = const Duration(milliseconds: 300),
    this.direction = SlideDirection.right,
    this.offset = 20.0,
  });

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Determine slide offset based on direction
    Offset beginOffset;
    switch (widget.direction) {
      case SlideDirection.left:
        beginOffset = Offset(-widget.offset, 0);
        break;
      case SlideDirection.right:
        beginOffset = Offset(widget.offset, 0);
        break;
      case SlideDirection.up:
        beginOffset = Offset(0, widget.offset);
        break;
      case SlideDirection.down:
        beginOffset = Offset(0, -widget.offset);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation after delay
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Direction for slide animation
enum SlideDirection {
  left,
  right,
  up,
  down,
}

