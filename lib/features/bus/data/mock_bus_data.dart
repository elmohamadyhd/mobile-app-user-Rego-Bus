// lib/features/bus/data/mock_bus_data.dart
import 'package:rego/features/bus/domain/entities/seat.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

abstract final class MockBusData {
  static const double walletBalance = 340.50;
  static const int serviceFeeEgp = 10;

  static final List<BusTripSummary> trips = [
    const BusTripSummary(
      id: 'gb-vip-0800',
      operatorName: 'Go Bus',
      operatorCode: 'GB',
      serviceClass: 'VIP',
      departHour: 8,
      departMinute: 0,
      arriveHour: 11,
      arriveMinute: 30,
      durationMin: 210,
      priceEgp: 180,
      seatsLeft: 6,
    ),
    const BusTripSummary(
      id: 'bc-dlx-0915',
      operatorName: 'Blue Bus',
      operatorCode: 'BB',
      serviceClass: 'Deluxe',
      departHour: 9,
      departMinute: 15,
      arriveHour: 12,
      arriveMinute: 25,
      durationMin: 190,
      priceEgp: 150,
      seatsLeft: 12,
    ),
    const BusTripSummary(
      id: 'sj-eco-1030',
      operatorName: 'SuperJet',
      operatorCode: 'SJ',
      serviceClass: 'Economy',
      departHour: 10,
      departMinute: 30,
      arriveHour: 14,
      arriveMinute: 15,
      durationMin: 225,
      priceEgp: 120,
      seatsLeft: 2,
    ),
  ];

  static final List<SeatRow> seatLayout = [
    const SeatRow(cells: [
      SeatCell(id: 'A1', status: SeatStatus.booked),
      SeatCell(id: 'A2', status: SeatStatus.available),
      null, // aisle
      SeatCell(id: 'C1', status: SeatStatus.available),
      SeatCell(id: 'D1', status: SeatStatus.available),
    ]),
    const SeatRow(cells: [
      SeatCell(id: 'A3', status: SeatStatus.available),
      SeatCell(id: 'A4', status: SeatStatus.available),
      null,
      SeatCell(id: 'C2', status: SeatStatus.booked),
      SeatCell(id: 'D2', status: SeatStatus.available),
    ]),
    const SeatRow(cells: [
      SeatCell(id: 'A5', status: SeatStatus.available),
      SeatCell(id: 'A6', status: SeatStatus.available),
      null,
      SeatCell(id: 'C3', status: SeatStatus.available),
      SeatCell(id: 'D3', status: SeatStatus.available),
    ]),
    const SeatRow(cells: [
      SeatCell(id: 'A7', status: SeatStatus.available),
      SeatCell(id: 'A8', status: SeatStatus.available),
      null,
      SeatCell(id: 'C4', status: SeatStatus.booked),
      SeatCell(id: 'D4', status: SeatStatus.available),
    ]),
    const SeatRow(cells: [
      SeatCell(id: 'A9', status: SeatStatus.available),
      SeatCell(id: 'A10', status: SeatStatus.available),
      null,
      SeatCell(id: 'C5', status: SeatStatus.available),
      SeatCell(id: 'D5', status: SeatStatus.available),
    ]),
  ];

  static BusTripDetail detailFor(String tripId) {
    final summary = trips.firstWhere((t) => t.id == tripId);
    return BusTripDetail(
      summary: summary,
      terminalFrom: 'Cairo Gateway',
      terminalFromSub: 'Abbassia terminal',
      terminalTo: 'Alexandria',
      terminalToSub: 'Moharam Bek station',
      amenities: const ['Wi-Fi', 'A/C', 'Sockets', 'Water'],
    );
  }
}
