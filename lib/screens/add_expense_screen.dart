import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/spending_category.dart';
import '../models/ticket_info.dart';
import '../providers/activities_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../providers/trips_provider.dart';
import '../utils/trip_access.dart';
import '../widgets/category_dropdown.dart';
import '../widgets/participant_multi_select.dart';
import '../widgets/ticket_form.dart';

class AddExpenseScreen extends StatefulWidget {
  final String tripId;
  final Expense? expense;
  final bool readOnly;

  const AddExpenseScreen({
    super.key,
    required this.tripId,
    this.expense,
    this.readOnly = false,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late SpendingCategory _category;
  String? _activityId;
  String? _paidByParticipantId;
  late DateTime _date;
  late TicketInfo _ticket;
  Set<String> _participantIds = {};
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _nameController = TextEditingController(text: expense?.name ?? '');
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(0),
    );
    _commentController = TextEditingController(text: expense?.comment ?? '');
    _category = expense?.category ?? SpendingCategory.food;
    _activityId = expense?.activityId;
    _paidByParticipantId = expense?.paidByParticipantId;
    _date = expense?.date ?? DateTime.now();
    _ticket = expense?.ticket.copy() ?? TicketInfo();
    _participantIds = {...?expense?.participantIds};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivitiesProvider>().loadForTrip(widget.tripId);
      context.read<ParticipantsProvider>().loadForTrip(widget.tripId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _onActivityChanged(String? activityId) {
    final activities = context.read<ActivitiesProvider>().activities;
    setState(() {
      _activityId = activityId;
      if (activityId == null) return;

      TripActivityMatch? match;
      for (final a in activities) {
        if (a.id == activityId) {
          match = (a.name, a.category, a.ticket);
          break;
        }
      }

      if (match == null) return;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = match.$1;
      }
      _category = match.$2;
      if (match.$2 == SpendingCategory.tickets) {
        _ticket = match.$3.copy();
      }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ticketError = _validateTicketDates();
    if (ticketError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ticketError)),
      );
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    final participants = context.read<ParticipantsProvider>().participants;
    final self = participantForUser(
      participants,
      userId: user?.id,
      email: user?.email,
    );
    final isOrganizer = isTripOrganizer(
      context.read<TripsProvider>().tripById(widget.tripId),
      user?.id,
    );
    if (!isOrganizer && self == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ваш аккаунт не связан с участником поездки.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ticket =
        _category == SpendingCategory.tickets ? _ticket : TicketInfo();
    final provider = context.read<ExpensesProvider>();

    if (_isEditing) {
      final expense = widget.expense!
        ..activityId = _activityId
        ..category = _category
        ..name = _nameController.text.trim()
        ..amount =
            double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0
        ..date = _date
        ..comment = _commentController.text.trim()
        ..paidByParticipantId = isOrganizer ? _paidByParticipantId : self!.id
        ..participantIds = isOrganizer ? _participantIds.toList() : [self!.id]
        ..ticket = ticket
        ..createdBy = user?.id
        ..scope = isOrganizer ? 'shared' : 'private';
      await provider.updateExpense(expense);
    } else {
      final paidByParticipantId = isOrganizer ? _paidByParticipantId : self!.id;
      final confirmation = isOrganizer && paidByParticipantId != null
          ? ExpenseConfirmation.pending
          : ExpenseConfirmation.confirmed;
      await provider.addExpense(
        activityId: _activityId,
        category: _category,
        name: _nameController.text.trim(),
        amount:
            double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
        date: _date,
        comment: _commentController.text.trim(),
        paidByParticipantId: paidByParticipantId,
        participantIds: isOrganizer ? _participantIds.toList() : [self!.id],
        ticket: ticket,
        confirmation: confirmation,
        createdBy: user?.id,
        scope: isOrganizer ? 'shared' : 'private',
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activities = context.watch<ActivitiesProvider>().activities;
    final participants = context.watch<ParticipantsProvider>().participants;
    final user = context.watch<AuthProvider>().currentUser;
    final self = participantForUser(
      participants,
      userId: user?.id,
      email: user?.email,
    );
    final isOrganizer = isTripOrganizer(
      context.watch<TripsProvider>().tripById(widget.tripId),
      user?.id,
    );
    final readOnly = widget.readOnly || (!isOrganizer && self == null);
    final visibleActivities = activities
        .where((activity) => isRecordVisibleToUser(
              isOrganizer: isOrganizer,
              participantIds: activity.participantIds,
              currentParticipantId: self?.id,
              currentUserId: user?.id,
              organizerId: context
                  .read<TripsProvider>()
                  .tripById(widget.tripId)
                  ?.organizerId,
              createdBy: activity.createdBy,
              scope: activity.scope,
            ))
        .toList();
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          _isEditing ? 'Редактирование расхода' : 'Форма добавления расхода',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (readOnly)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Просмотр справочной информации: редактирование недоступно.',
                  textAlign: TextAlign.center,
                ),
              ),
            CategoryDropdown(
              value: _category,
              onChanged:
                  readOnly ? (_) {} : (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !readOnly,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название расхода',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: ValueKey('${_activityId}_${visibleActivities.length}'),
              initialValue: visibleActivities.any((a) => a.id == _activityId)
                  ? _activityId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Связанная активность (необязательно)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Не выбрано'),
                ),
                for (final activity in visibleActivities)
                  DropdownMenuItem<String?>(
                    value: activity.id,
                    child: Text(activity.name),
                  ),
              ],
              onChanged: readOnly ? null : _onActivityChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !readOnly,
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сумма расхода',
                border: OutlineInputBorder(),
                suffixText: '₽',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Укажите сумму больше нуля';
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: readOnly ? null : _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Дата расхода: ${df.format(_date)}'),
            ),
            if (isOrganizer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: ValueKey('${_paidByParticipantId}_${participants.length}'),
                initialValue:
                    participants.any((p) => p.id == _paidByParticipantId)
                        ? _paidByParticipantId
                        : null,
                decoration: const InputDecoration(
                  labelText: 'Кто оплатил (необязательно)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Если выбран участник, расход попадет в список на подтверждение',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Я (организатор)'),
                  ),
                  for (final participant in participants)
                    DropdownMenuItem<String?>(
                      value: participant.id,
                      child: Text(participant.name),
                    ),
                ],
                onChanged: readOnly
                    ? null
                    : (value) => setState(() => _paidByParticipantId = value),
              ),
              const SizedBox(height: 16),
              ParticipantMultiSelect(
                participants: participants,
                selectedIds: _participantIds,
                onChanged: readOnly
                    ? (_) {}
                    : (ids) => setState(() => _participantIds = ids),
              ),
            ],
            if (_category == SpendingCategory.tickets) ...[
              const SizedBox(height: 16),
              TicketForm(
                ticket: _ticket,
                onChanged:
                    readOnly ? (_) {} : (t) => setState(() => _ticket = t),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              enabled: !readOnly,
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Комментарий к расходу',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: readOnly || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : Text(
                      readOnly
                          ? 'Только просмотр'
                          : (_isEditing
                              ? 'Сохранить изменения'
                              : 'Сохранить расход'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef TripActivityMatch = (String, SpendingCategory, TicketInfo);
