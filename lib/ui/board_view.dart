import 'package:flutter/material.dart';

import '../core/geometry.dart';
import '../core/move.dart';
import '../game/game_controller.dart';
import 'cube3d.dart';
import 'tumbling_die.dart';

/// Player colors. 0 = South, 1 = North.
const List<Color> kPlayerColors = [Color(0xFF2E6FB8), Color(0xFFC0392B)];

class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown.shade800, width: 4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cell = constraints.maxWidth / kBoardSize;
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final anim = controller.animating;
                return Stack(
                  children: [
                    Column(
                      children: [
                        for (var row = 0; row < kBoardSize; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < kBoardSize; col++)
                                  Expanded(
                                    child: _Cell(
                                      controller: controller,
                                      pos: Position(col, row),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (anim != null)
                      TumblingDie(
                        key: ValueKey(controller.state.turnNumber),
                        anim: anim,
                        cellSize: cell,
                        color: kPlayerColors[anim.owner],
                        onDone: controller.onTumbleComplete,
                      ),
                    if (controller.isChoosing)
                      ..._chooserLayer(controller, cell, constraints.maxWidth),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The route chooser: a tap-to-cancel scrim plus an anchored panel of routes.
  List<Widget> _chooserLayer(
      GameController controller, double cell, double boardW) {
    final dest = controller.choiceDest!;
    final options = controller.choiceOptions;
    final color = kPlayerColors[controller.state.currentPlayer];

    const cardW = 64.0;
    final panelW = options.length * cardW + (options.length - 1) * 8 + 20;
    const panelH = 104.0;

    var left = dest.col * cell + cell / 2 - panelW / 2;
    left = left.clamp(2.0, boardW - panelW - 2);
    var top = dest.row * cell - panelH - 6;
    if (top < 2) top = dest.row * cell + cell + 6; // flip below if no room above

    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: controller.cancelChoice,
        ),
      ),
      Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Roll which way?',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _OptionCard(
                        controller: controller,
                        move: options[i],
                        color: color,
                        width: cardW,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

IconData _directionIcon(Direction d) => switch (d) {
      Direction.north => Icons.arrow_upward,
      Direction.south => Icons.arrow_downward,
      Direction.east => Icons.arrow_forward,
      Direction.west => Icons.arrow_back,
    };

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.controller,
    required this.move,
    required this.color,
    required this.width,
  });

  final GameController controller;
  final Move move;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final hovered = controller.hoveredOption == move;
    return MouseRegion(
      onEnter: (_) => controller.hoverOption(move),
      onExit: (_) => controller.hoverOption(null),
      child: GestureDetector(
        onTap: () => controller.chooseOption(move),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: hovered ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered ? color : Colors.grey.shade300,
              width: hovered ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_directionIcon(move.firstDirection), size: 18, color: color),
              const SizedBox(height: 4),
              SizedBox(
                width: 36,
                height: 36,
                child: Cube3D(die: move.resultDie, color: color),
              ),
              const SizedBox(height: 2),
              Text('top ${move.resultTop}',
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.controller, required this.pos});

  final GameController controller;
  final Position pos;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    // Hide the piece that is mid-tumble at its destination; the overlay draws it.
    final animatingHere = controller.animating?.move.to == pos;
    final piece = animatingHere ? null : state.pieceAt(pos);
    final isSelected = controller.selected == pos;
    final movesHere = controller.movesTo(pos);
    final isDestination = movesHere.isNotEmpty;
    final isPreview = controller.previewDest == pos;

    final light = (pos.col + pos.row) % 2 == 0;
    final bg = light ? const Color(0xFFEBD9B3) : const Color(0xFF9E7B4F);

    // When hovering a chooser option, highlight the squares its route passes.
    final onRoute = controller.highlightedRoute.contains(pos);

    return MouseRegion(
      onEnter: (_) => controller.hover(pos),
      onExit: (_) => controller.hover(null),
      child: GestureDetector(
        onTap: () => controller.tap(pos),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: bg),
            if (onRoute)
              Container(
                color: kPlayerColors[controller.state.currentPlayer]
                    .withValues(alpha: 0.30),
              ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.35),
                  border: Border.all(color: Colors.yellow.shade700, width: 3),
                ),
              ),
            if (piece != null)
              Padding(
                padding: const EdgeInsets.all(3),
                child: Cube3D(
                  die: piece.die,
                  color: kPlayerColors[piece.owner],
                  isKing: piece.isKing,
                ),
              ),
            if (isDestination) _destinationOverlay(movesHere, isPreview),
          ],
        ),
      ),
    );
  }

  /// A marker on a legal destination. Shows the resulting top face(s) so the
  /// outcome of the move is visible before committing (on hover and on touch).
  Widget _destinationOverlay(List<Move> moves, bool isPreview) {
    final capture = moves.any((m) => m.capturesOpponent);
    final tops = moves.map((m) => m.resultTop).toSet().toList()..sort();
    final label = tops.join(' / ');

    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (capture ? Colors.red : Colors.green)
                .withValues(alpha: isPreview ? 0.95 : 0.7),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: isPreview ? 2.5 : 1.5,
            ),
          ),
          child: Text(
            capture ? '×$label' : label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isPreview ? 15 : 12,
            ),
          ),
        ),
      ),
    );
  }
}
