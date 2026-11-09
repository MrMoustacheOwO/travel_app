import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../providers/participants_provider.dart';

class AddParticipantScreen extends StatefulWidget {
  final String tripId;
  final Participant? participant;

  const AddParticipantScreen({super.key, required this.tripId, this.participant});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _notesController;
  late ParticipationStatus _status;
  late TripParticipantRole _role;
  bool _saving = false;

  bool get _isEditing => widget.participant != null;

  @override
  void initState() {
    super.initState();
    final participant = widget.participant;
    _nameController = TextEditingController(text: participant?.name ?? '');
    _contactController = TextEditingController(text: participant?.contact ?? '');
    _notesController = TextEditingController(text: participant?.notes ?? '');
    _status = participant?.status ?? ParticipationStatus.confirmed;
    final existing = context.read<ParticipantsProvider>().participants;
    _role = participant?.role ??
        (existing.isEmpty ? TripParticipantRole.organizer : TripParticipantRole.participant);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ParticipantsProvider>();
    if (_isEditing) {
      final participant = widget.participant!
        ..name = _nameController.text.trim()
        ..contact = _contactController.text.trim()
        ..notes = _notesController.text.trim()
        ..status = _status
        ..role = _role;
      await provider.updateParticipant(participant);
    } else {
      await provider.addParticipant(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        notes: _notesController.text.trim(),
        status: _status,
        role: _role,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing
            ? 'Редактирование участника'
            : 'Форма добавления участника'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя участника',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите имя участника' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Контактные данные',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ParticipationStatus>(
              key: ValueKey(_status),
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Статус участия',
                border: OutlineInputBorder(),
              ),
              items: ParticipationStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TripParticipantRole>(
              key: ValueKey(_role),
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Роль в поездке',
                border: OutlineInputBorder(),
              ),
              items: TripParticipantRole.values
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Дополнительные сведения об участнике',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : Text(_isEditing ? 'Сохранить изменения' : 'Добавить участника'),
            ),
          ],
        ),
      ),
    );
  }
}
