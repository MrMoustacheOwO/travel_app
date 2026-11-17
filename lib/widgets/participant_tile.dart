import 'package:flutter/material.dart';

import '../models/participant.dart';

class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final double amountPaid;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.amountPaid = 0,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(participant.name.isNotEmpty
              ? participant.name.substring(0, 1).toUpperCase()
              : '?'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(participant.name),
            const SizedBox(height: 4),
            Chip(
              label: Text(participant.role.label),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (participant.contact.isNotEmpty) Text(participant.contact),
            Text(participant.status.label),
            Text('Внесено ${amountPaid.toStringAsFixed(0)} ₽'),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
