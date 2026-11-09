import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.onEdit,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (trip.status) {
      case TripStatus.planned:
        return Colors.blue.shade100;
      case TripStatus.active:
        return Colors.green.shade100;
      case TripStatus.completed:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${df.format(trip.startDate)} — ${df.format(trip.endDate)}'),
                    const SizedBox(height: 4),
                    Text('Участников: ${trip.peopleCount}'),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(trip.status.label),
                      backgroundColor: _statusColor(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
