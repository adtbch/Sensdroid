import 'package:flutter/material.dart';

/// Animated pulsing dot to indicate connection / transmission status.
class AnimatedStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const AnimatedStatusDot({
    super.key,
    required this.color,
    this.size = 10,
    this.animate = true,
  });

  @override
  State<AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);

    _scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
