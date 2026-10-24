import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// Marcador visual de uma paragem (ponto no mapa).
class StopMarkerWidget extends StatelessWidget {
  const StopMarkerWidget({
    super.key,
    required this.selected,
    required this.color,
  });

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ring = selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.surface;
    return Container(
      width: selected ? 16 : 12,
      height: selected ? 16 : 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Marcador visual de um autocarro, rodado segundo o rumo ([LiveVehicle.bearing]).
class BusMarkerWidget extends StatelessWidget {
  const BusMarkerWidget({
    super.key,
    required this.color,
    this.bearing,
  });

  final Color color;
  final double? bearing;

  @override
  Widget build(BuildContext context) {
    final angle = bearing == null ? 0.0 : bearing! * math.pi / 180;
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.directions_bus,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
