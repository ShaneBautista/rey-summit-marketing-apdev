import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AnimatedButton({super.key, required this.child, required this.onTap});

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  double scale = 1.0;
  bool isHovering = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => scale = 0.92);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => scale = isHovering ? 1.05 : 1.0);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => scale = isHovering ? 1.05 : 1.0);
  }

  void _onHoverEnter(PointerEnterEvent event) {
    setState(() {
      isHovering = true;
      scale = 1.05;
    });
  }

  void _onHoverExit(PointerExitEvent event) {
    setState(() {
      isHovering = false;
      scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
