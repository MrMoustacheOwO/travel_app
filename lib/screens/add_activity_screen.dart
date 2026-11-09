import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../models/participant.dart';
import '../models/spending_category.dart';
import '../models/ticket_info.dart';
import '../providers/activities_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../widgets/category_dropdown.dart';
import '../widgets/participant_multi_select.dart';
import '../widgets/ticket_form.dart';

class AddActivityScreen extends StatefulWidget {
  final String tripId;
  final TripActivity? activity;
  final bool readOnly;

  const AddActivityScreen({
    super.key,
    required this.tripId,
    this.activity,
    this.readOnly = false,
  });

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;
  late SpendingCategory _category;
  late DateTime _dateTime;
  late TicketInfo _ticket;
  late bool _isMain;
  late bool _privateOnly;
  Set<String> _participantIds = {};
  bool _saving = false;

  bool get _isEditing => widget.activity != null;

  bool _isOrganizer(List<Participant> participants) {
    if (participants.isEmpty) return true;
    return participants.first.role == TripParticipantRole.organizer;
  }

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    _nameController = TextEditingController(text: activity?.name ?? '');
    _locationController = TextEditingController(text: activity?.location ?? '');
    _descriptionController =
        TextEditingController(text: activity?.description ?? '');
    _costController = TextEditingController(
      text: activity == null ? '0' : activity.cost.toStringAsFixed(0),
    );
    _category = activity?.category ?? SpendingCategory.entertainment;
    _dateTime = activity?.dateTime ?? DateTime.now();
    _ticket = activity?.ticket.copy() ?? TicketInfo();
    _isMain = activity?.isMain ?? false;
    _participantIds = {...?activity?.participantIds};
    final participants = context.read<ParticipantsProvider>().participants;
    _privateOnly = !_isOrganizer(participants) && widget.activity == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantsProvider>().loadForTrip(widget.tripId);
      context.read<ExpensesProvider>().loadForTrip(widget.tripId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String? _validateTicketDates() {
    if (_category != SpendingCategory.tickets) return null;
    if (_ticket.departureDate == null) return 'Укажите дату убывания';
    if (_ticket.arrivalDate == null) return 'Укажите дату прибытия';
    if (_ticket.arrivalDate!.isBefore(_ticket.departureDate!)) {
      return 'Дата прибытия не может быть раньше убывания';
    }
    return null;
  }

  Future<void> _save({bool complete = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final ticketError = _validateTicketDates();
    if (ticketError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ticketError)));
      return;
    }
    setState(() => _saving = true);
    final cost = double.tryParse(_costController.text.replaceAll(',', '.')) ?? 0;
    final ticket =
        _category == SpendingCategory.tickets ? _ticket : TicketInfo();
    final participants = _participantIds.toList();
    final allParticipants = context.read<ParticipantsProvider>().participants;
    final effectiveParticipants =
        (!_isOrganizer(allParticipants) && _privateOnly && allParticipants.isNotEmpty)
            ? [allParticipants.first.id]
            : participants;
    final activities = context.read<ActivitiesProvider>();
    final expenses = context.read<ExpensesProvider>();

    TripActivity? saved;
    if (_isEditing) {
      final activity = widget.activity!
        ..name = _nameController.text.trim()
        ..category = _category
        ..dateTime = _dateTime
        ..location = _locationController.text.trim()
        ..description = _descriptionController.text.trim()
        ..cost = cost
        ..isMain = _isMain
        ..isCompleted = widget.activity!.isCompleted || complete
        ..ticket = ticket
        ..participantIds = effectiveParticipants;
      await activities.updateActivity(activity);
      saved = activity;
    } else {
      saved = await activities.addActivity(
        name: _nameController.text.trim(),
        category: _category,
        dateTime: _dateTime,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        cost: cost,
        isMain: _isMain,
        ticket: ticket,
        participantIds: effectiveParticipants,
      );
    }

    if (saved != null && saved.isCompleted) {
      await expenses.syncExpenseForActivity(saved);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final participants = context.watch<ParticipantsProvider>().participants;
    final canCreatePrivate = !widget.readOnly && !_isOrganizer(participants);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing
            ? 'Редактирование активности'
            : 'Форма добавления активности'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.readOnly)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Просмотр справочной информации: редактирование и изменение недоступны для участника без роли организатора.',
                  textAlign: TextAlign.center,
                ),
              ),
            TextFormField(
              enabled: !widget.readOnly,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название активности',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            CategoryDropdown(
              value: _category,
              onChanged: widget.readOnly ? (_) {} : (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            if (canCreatePrivate)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Личная активность (видно только мне)'),
                value: _privateOnly,
                onChanged: (value) => setState(() => _privateOnly = value),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Главная активность поездки'),
              value: _isMain,
              onChanged: widget.readOnly ? null : (value) => setState(() => _isMain = value),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.readOnly ? null : _pickDateTime,
              icon: const Icon(Icons.event),
              label: Text('Дата и время: ${df.format(_dateTime)}'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !widget.readOnly,
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Место проведения',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !widget.readOnly,
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание активности',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !widget.readOnly,
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Стоимость активности',
                border: OutlineInputBorder(),
                helperText: 'Если больше 0, активность появится в расходах',
                suffixText: '₽',
              ),
            ),
            const SizedBox(height: 16),
            ParticipantMultiSelect(
              participants: participants,
              selectedIds: _participantIds,
              onChanged: widget.readOnly ? (_) {} : (ids) => setState(() => _participantIds = ids),
            ),
            if (_category == SpendingCategory.tickets) ...[
              const SizedBox(height: 16),
              TicketForm(
                ticket: _ticket,
                onChanged: (t) => setState(() => _ticket = t),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.readOnly || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : Text(
                      widget.readOnly
                          ? 'Только просмотр'
                          : (_isEditing ? 'Сохранить изменения' : 'Сохранить активность'),
                    ),
            ),
            if (_isEditing && widget.activity!.isCompleted) ...[
              const SizedBox(height: 12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text('Активность завершена'),
              ),
            ] else if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.readOnly || _saving ? null : () => _save(complete: true),
                icon: const Icon(Icons.task_alt),
                label: const Text('Завершить активность'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
