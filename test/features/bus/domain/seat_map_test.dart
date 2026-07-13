import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';

const _salon = SeatSalon(id: 1, name: 'Express', rows: 1, columns: 1);

void main() {
  group('SeatMapLabels', () {
    test('labelForSeatId returns seatNo when it differs from id', () {
      const map = SeatMap(
        salon: _salon,
        cells: [
          SeatMapCell(
            kind: SeatMapCellKind.available,
            id: '9387818',
            seatNo: '24',
          ),
        ],
      );

      expect(map.labelForSeatId('9387818'), '24');
    });

    test('labelForSeatId falls back to id when seatNo is null', () {
      const map = SeatMap(
        salon: _salon,
        cells: [
          SeatMapCell(
            kind: SeatMapCellKind.available,
            id: '16',
          ),
        ],
      );

      expect(map.labelForSeatId('16'), '16');
    });

    test('labelForSeatId returns the input when the id is unknown', () {
      const map = SeatMap(salon: _salon, cells: []);

      expect(map.labelForSeatId('missing'), 'missing');
    });

    test('labelsForSeatIds preserves order', () {
      const map = SeatMap(
        salon: _salon,
        cells: [
          SeatMapCell(
            kind: SeatMapCellKind.available,
            id: '9387818',
            seatNo: '24',
          ),
          SeatMapCell(
            kind: SeatMapCellKind.available,
            id: '9387819',
            seatNo: '25',
          ),
        ],
      );

      expect(
        map.labelsForSeatIds(['9387819', '9387818']),
        ['25', '24'],
      );
    });
  });
}
