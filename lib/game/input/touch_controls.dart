import 'package:flutter/material.dart';

/// On-screen touch controls for mobile devices.
///
/// Provides left/right arrows and a jump button.
/// Communicates via callbacks — the game wires these
/// to the player's movement methods.
class TouchControls extends StatelessWidget {
  final VoidCallback onLeftPressed;
  final VoidCallback onLeftReleased;
  final VoidCallback onRightPressed;
  final VoidCallback onRightReleased;
  final VoidCallback onJumpPressed;
  final VoidCallback onJumpReleased;

  const TouchControls({
    super.key,
    required this.onLeftPressed,
    required this.onLeftReleased,
    required this.onRightPressed,
    required this.onRightReleased,
    required this.onJumpPressed,
    required this.onJumpReleased,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // D-pad: left + right
          Row(
            children: [
              _buildButton(
                icon: Icons.arrow_left,
                onPressed: onLeftPressed,
                onReleased: onLeftReleased,
              ),
              const SizedBox(width: 8),
              _buildButton(
                icon: Icons.arrow_right,
                onPressed: onRightPressed,
                onReleased: onRightReleased,
              ),
            ],
          ),
          // Jump button
          _buildButton(
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            onReleased: onJumpReleased,
            size: 72,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
    double size = 60,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: () => onReleased(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: size * 0.5,
        ),
      ),
    );
  }
}
