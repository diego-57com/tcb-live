import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// Marcador de paragem no mapa.
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
      height: selected ? 12 : 12,
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

/// Ponto azul com halo para a posição do utilizador.
class UserMarkerWidget extends StatelessWidget {
  const UserMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A73E8);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: blue.withAlpha(38),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// Marcador de autocarro: número da carreira + seta de direção (rumo).
class BusMarkerWidget extends StatelessWidget {
  const BusMarkerWidget({
    super.key,
    required this.color,
    this.bearing,
    this.label,
    this.selected = false,
  });

  final Color color;
  final double? bearing;
  final String? label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final angle = (bearing ?? 0) * math.pi / 180;
    final size = selected ? 40.0 : 34.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seta que aponta no sentido do movimento.
        Transform.rotate(
          angle: angle,
          child: Icon(
            Icons.navigation,
            size: 16,
            color: color,
          ),
        ),
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.white70,
              width: selected ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label ?? '',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: (label ?? '').length > 3 ? 10 : 13,
            ),
          ),
        ),
      ],
    );
  }
}
