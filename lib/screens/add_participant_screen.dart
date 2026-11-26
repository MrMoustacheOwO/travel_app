import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../data/supabase_sync_service.dart';
import '../providers/participants_provider.dart';

class AddParticipantScreen extends StatefulWidget {
  final String tripId;
  final Participant? participant;

  const AddParticipantScreen(
      {super.key, required this.tripId, this.participant});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  bool _saving = false;

  bool get _isEditing => widget.participant != null;

  @override
  void initState() {
    super.initState();
    final participant = widget.participant;
    _nameController = TextEditingController(text: participant?.name ?? '');
    _contactController =
        TextEditingController(text: participant?.contact ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ParticipantsProvider>();
    final contact = _contactController.text.trim();
    try {
      if (!_isEditing) {
        await context.read<SupabaseSyncService>().inviteTripMember(
              tripId: widget.tripId,
              email: contact,
              displayName: _nameController.text.trim(),
            );
        await provider.loadForTrip(widget.tripId);
      } else if (_isEditing) {
        final participant = widget.participant!
          ..name = _nameController.text.trim()
          ..contact = contact;
        await provider.updateParticipant(participant);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить приглашение: $error')),
        );
      }
      return;
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
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите имя участника'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Электронная почта',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Введите корректный адрес электронной почты';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : Text(_isEditing
                      ? 'Сохранить изменения'
                      : 'Добавить участника'),
            ),
          ],
        ),
      ),
    );
  }
}
