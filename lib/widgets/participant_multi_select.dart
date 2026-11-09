import 'package:flutter/material.dart';

import '../models/participant.dart';

class ParticipantMultiSelect extends StatelessWidget {
  final List<Participant> participants;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ParticipantMultiSelect({
    super.key,
    required this.participants,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Участники',
          border: OutlineInputBorder(),
        ),
        child: Text('Сначала добавьте участников поездки на вкладке «Участники».'),
      );
    }

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Участники',
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    onChanged(participants.map((p) => p.id).toSet()),
                child: const Text('Все'),
              ),
              TextButton(
                onPressed: () => onChanged({}),
                child: const Text('Сбросить'),
              ),
            ],
          ),
          for (final p in participants)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              value: selectedIds.contains(p.id),
              onChanged: (checked) {
                final next = {...selectedIds};
                if (checked == true) {
                  next.add(p.id);
                } else {
                  next.remove(p.id);
                }
                onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}

String participantNames(List<Participant> all, List<String> ids) {
  if (ids.isEmpty) return '';
  final names = all
      .where((p) => ids.contains(p.id))
      .map((p) => p.name)
      .toList();
  if (names.isEmpty) return '';
  return names.join(', ');
}
