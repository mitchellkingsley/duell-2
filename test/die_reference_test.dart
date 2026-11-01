import 'dart:convert';
import 'dart:io';

import 'package:duell/core/die.dart';
import 'package:duell/core/geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the Dart die physics against the generated reference tables in
/// `resources/duell-moves.json`. If these pass, the engine's tumbling agrees
/// exactly with the transcribed box-art movement diagrams.
void main() {
  test('die has exactly 24 orientations', () {
    expect(Die.allOrientations.length, 24);
  });

  test('opposite faces sum to 7 for every orientation', () {
    for (final d in Die.allOrientations) {
      expect(d.top + d.bottom, 7);
      expect(d.north + d.south, 7);
      expect(d.east + d.west, 7);
    }
  });

  group('matches duell-moves.json reference tables', () {
    final file = File('resources/duell-moves.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final topNumbers = data['topNumbers'] as Map<String, dynamic>;

    for (final topKey in topNumbers.keys) {
      test('Top No. $topKey', () {
        final entry = topNumbers[topKey] as Map<String, dynamic>;
        final so = entry['startOrientation'] as Map<String, dynamic>;
        final start = Die(
          top: so['top'] as int,
          bottom: so['bottom'] as int,
          north: so['north'] as int,
          south: so['south'] as int,
          east: so['east'] as int,
          west: so['west'] as int,
        );

        // The start orientation must be one the engine can produce.
        expect(Die.allOrientations.contains(start), isTrue,
            reason: 'start orientation not in chirality class');

        for (final sq in entry['squares'] as List) {
          final square = sq as Map<String, dynamic>;
          final dx = square['dx'] as int;
          final dy = square['dy'] as int;
          for (final p in square['paths'] as List) {
            final path = p as Map<String, dynamic>;
            final order = (path['order'] as List).cast<String>();
            final expectedTop = path['resultTop'] as int;

            var die = start;
            var col = 0, row = 0;
            for (final seg in order) {
              final dir = Direction.fromCode(seg[0]);
              final count = int.parse(seg.substring(1));
              for (var i = 0; i < count; i++) {
                die = die.roll(dir);
                col += dir.dCol;
                row += dir.dRow;
              }
            }

            expect(col, dx, reason: 'dx mismatch for $order (top $topKey)');
            expect(row, dy, reason: 'dy mismatch for $order (top $topKey)');
            expect(die.top, expectedTop,
                reason: 'resultTop mismatch for $order (top $topKey)');
          }
        }
      });
    }
  });
}
