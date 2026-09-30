import 'package:flutter/material.dart';

import '../models/observation.dart';

class SoilMoistureProfile extends StatelessWidget {
  const SoilMoistureProfile({required this.observation, super.key});

  static const double _maximumPercent = 55;

  final Observation observation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Soil moisture profile',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildDepthRow(context, '12 in', observation.soil12m),
          const SizedBox(height: 6),
          _buildDepthRow(context, '24 in', observation.soil24m),
          const SizedBox(height: 6),
          _buildDepthRow(context, '50 in', observation.soil50m),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0%', style: Theme.of(context).textTheme.bodySmall),
                    Text('55%', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepthRow(BuildContext context, String depth, double? value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 48, child: Text(depth)),
        Expanded(
          child: LinearProgressIndicator(
            value: value == null
                ? 0
                : (value / _maximumPercent).clamp(0.0, 1.0),
            minHeight: 6,
            color: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            value == null ? 'M' : '${value.toStringAsFixed(1)}%',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}