import 'package:flutter/material.dart';
import '../side_scroller_game.dart';

/// Overlay shown when the player loses all lives.
class GameOverOverlay extends StatelessWidget {
  final SideScrollerGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${game.gameState.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: game.restart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'RESTART',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'or press R',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
