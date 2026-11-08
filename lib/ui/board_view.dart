import 'package:flutter/material.dart';

import '../core/geometry.dart';
import '../core/move.dart';
import '../game/game_controller.dart';
import 'cube3d.dart';
import 'tumbling_die.dart';

/// Player colors. 0 = South, 1 = North. Brightened for the dark board.
const List<Color> kPlayerColors = [Color(0xFF3B82F6), Color(0xFFEF4444)];

/// Dark board square colors and frame.
const Color kSquareLight = Color(0xFF3C4654);
const Color kSquareDark = Color(0xFF2A313B);
const Color kBoardBorder = Color(0xFF11151A);

/// Chooser (dark surfaces).
const Color kChooserSurface = Color(0xFF242830);
const Color kChooserCard = Color(0xFF30353E);
const Color kChooserBorder = Color(0xFF454B55);

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.controller,
    required this.kingIcon,
  });

  final GameController controller;
  final IconData kingIcon;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBoardBorder, width: 4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cell = constraints.maxWidth / kBoardSize;
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final anim = controller.animating;
                // Computed once per rebuild, not per cell.
                final threats = controller.threatenedSquares;
                final threatSource = controller.threatSource;
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
                                      kingIcon: widget.kingIcon,
                                      pulse: _pulse,
                                      threatened: threats
                                          .contains(Position(col, row)),
                                      isThreatSource: threatSource ==
                                          Position(col, row),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (anim != null)
                      TumblingDie(
                        key: ValueKey(controller.animationId),
                        anim: anim,
                        cellSize: cell,
                        color: kPlayerColors[anim.owner],
                        kingIcon: widget.kingIcon,
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
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          color: kChooserSurface,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Roll which way?',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
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
            color: hovered ? color.withValues(alpha: 0.22) : kChooserCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered ? color : kChooserBorder,
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
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.controller,
    required this.pos,
    required this.kingIcon,
    required this.pulse,
    required this.threatened,
    required this.isThreatSource,
  });

  final GameController controller;
  final Position pos;
  final IconData kingIcon;
  final Animation<double> pulse;
  final bool threatened;
  final bool isThreatSource;

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
    final bg = light ? kSquareLight : kSquareDark;
    final teamColor = kPlayerColors[state.currentPlayer];

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
            if (threatened)
              Container(color: Colors.red.withValues(alpha: 0.32)),
            if (onRoute)
              Container(color: teamColor.withValues(alpha: 0.30)),
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
                  kingIcon: piece.isKing ? kingIcon : null,
                ),
              ),
            if (isThreatSource)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 3),
                ),
              ),
            if (isDestination)
              _DestIndicator(
                moves: movesHere,
                color: teamColor,
                isPreview: isPreview,
                pulse: pulse,
              ),
          ],
        ),
      ),
    );
  }
}

/// A full-cell, borderless, pulsing move indicator in the team color. A square
/// reachable by two routes with different outcomes is bisected by the diagonal
/// between opposite corners — chosen so each route's number sits in the triangle
/// on the edge the die rolls in from — and each number is centered in its half.
class _DestIndicator extends StatelessWidget {
  const _DestIndicator({
    required this.moves,
    required this.color,
    required this.isPreview,
    required this.pulse,
  });

  final List<Move> moves;
  final Color color;
  final bool isPreview;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final distinctTops = moves.map((m) => m.resultTop).toSet();
    final split = moves.length >= 2 && distinctTops.length >= 2;

    List<_Placed> placed;
    Offset diagStart = Offset.zero, diagEnd = Offset.zero;

    if (!split) {
      placed = [
        _Placed(moves.first.resultTop, moves.first.capturesOpponent,
            const Offset(0.5, 0.5)),
      ];
    } else {
      // One route finishes on a vertical roll, the other horizontal. Each rolls
      // in from the edge opposite its final direction:
      //   final South -> top edge, North -> bottom, East -> left, West -> right.
      final vert = moves.firstWhere((m) =>
          m.path.last.direction == Direction.north ||
          m.path.last.direction == Direction.south);
      final horiz = moves.firstWhere((m) => m != vert);
      final vTop = vert.path.last.direction == Direction.south; // from top edge
      final hLeft = horiz.path.last.direction == Direction.east; // from left edge

      // Diagonal runs between opposite corners; its orientation depends on which
      // corner the two entry edges share. Numbers sit at the triangle centroids.
      Offset vPos, hPos;
      const tl = Offset(0, 0), tr = Offset(1, 0), bl = Offset(0, 1), br = Offset(1, 1);
      if (vTop && !hLeft) {
        (diagStart, diagEnd) = (tr, bl); // share TR
        (vPos, hPos) = (const Offset(1 / 3, 1 / 3), const Offset(2 / 3, 2 / 3));
      } else if (vTop && hLeft) {
        (diagStart, diagEnd) = (tl, br); // share TL
        (vPos, hPos) = (const Offset(2 / 3, 1 / 3), const Offset(1 / 3, 2 / 3));
      } else if (!vTop && !hLeft) {
        (diagStart, diagEnd) = (tl, br); // share BR
        (vPos, hPos) = (const Offset(1 / 3, 2 / 3), const Offset(2 / 3, 1 / 3));
      } else {
        (diagStart, diagEnd) = (tr, bl); // share BL
        (vPos, hPos) = (const Offset(2 / 3, 2 / 3), const Offset(1 / 3, 1 / 3));
      }
      placed = [
        _Placed(vert.resultTop, vert.capturesOpponent, vPos),
        _Placed(horiz.resultTop, horiz.capturesOpponent, hPos),
      ];
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(pulse.value);
          return CustomPaint(
            size: Size.infinite,
            painter: _DestPainter(
              color: color,
              pulse: t,
              isPreview: isPreview,
              split: split,
              placed: placed,
              diagStart: diagStart,
              diagEnd: diagEnd,
            ),
          );
        },
      ),
    );
  }
}

/// A number drawn on an indicator: its value, capture flag, and position
/// (fractional, 0..1 within the cell).
class _Placed {
  const _Placed(this.value, this.capture, this.pos);
  final int value;
  final bool capture;
  final Offset pos;
}

class _DestPainter extends CustomPainter {
  _DestPainter({
    required this.color,
    required this.pulse,
    required this.isPreview,
    required this.split,
    required this.placed,
    required this.diagStart,
    required this.diagEnd,
  });

  final Color color;
  final double pulse;
  final bool isPreview;
  final bool split;
  final List<_Placed> placed;
  final Offset diagStart;
  final Offset diagEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final base = isPreview ? 0.5 : 0.34;
    final fill = Paint()..color = color.withValues(alpha: base + 0.16 * pulse);
    canvas.drawRect(Offset.zero & size, fill);

    if (split) {
      canvas.drawLine(
        Offset(diagStart.dx * size.width, diagStart.dy * size.height),
        Offset(diagEnd.dx * size.width, diagEnd.dy * size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }

    final scale = split ? 0.28 : 0.34;
    for (final p in placed) {
      _number(canvas, size, p, scale);
    }
  }

  void _number(Canvas canvas, Size size, _Placed p, double scale) {
    final s = size.shortestSide;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: p.capture ? '×${p.value}' : '${p.value}',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: s * scale,
        ),
      ),
    )..layout();
    tp.paint(
      canvas,
      Offset(p.pos.dx * size.width - tp.width / 2,
          p.pos.dy * size.height - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DestPainter old) =>
      old.pulse != pulse ||
      old.color != color ||
      old.isPreview != isPreview ||
      old.split != split ||
      old.diagStart != diagStart ||
      old.placed.length != placed.length ||
      (placed.isNotEmpty && old.placed.first.value != placed.first.value) ||
      (placed.length > 1 && old.placed[1].value != placed[1].value);
}
