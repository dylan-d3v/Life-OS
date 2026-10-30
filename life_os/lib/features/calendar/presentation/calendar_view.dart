import 'package:flutter/material.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calendario',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Planificación temporal, eventos y fechas límite',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 28),
          Expanded(
            child: Center(
              child: Text(
                'Módulo de Calendario en preparación (Fase 3.6)',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

