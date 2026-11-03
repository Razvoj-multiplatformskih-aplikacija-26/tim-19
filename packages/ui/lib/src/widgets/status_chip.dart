import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../labels.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = SoundTheme.statusColor(Theme.of(context).colorScheme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
