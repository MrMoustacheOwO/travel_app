import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../providers/trips_provider.dart';

class AddTripScreen extends StatefulWidget {
  final Trip? trip;

  const AddTripScreen({super.key, this.trip});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _peopleController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  final _df = DateFormat('dd.MM.yyyy');

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _nameController = TextEditingController(text: trip?.name ?? '');
    _peopleController =
        TextEditingController(text: '${trip?.peopleCount ?? 1}');
    _startDate = trip?.startDate;
    _endDate = trip?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите даты начала и окончания поездки')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<TripsProvider>();
    if (_isEditing) {
      final trip = widget.trip!
        ..name = _nameController.text.trim()
        ..startDate = _startDate!
        ..endDate = _endDate!
        ..peopleCount = int.tryParse(_peopleController.text) ?? 1;
      await provider.updateTrip(trip);
      if (!mounted) return;
      Navigator.of(context).pop(trip);
    } else {
      final Trip trip = await provider.addTrip(
        name: _nameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        peopleCount: int.tryParse(_peopleController.text) ?? 1,
      );
      if (!mounted) return;
      Navigator.of(context).pop(trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing ? 'Редактирование поездки' : 'Форма добавления поездки'),
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
                labelText: 'Название поездки',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null
                        ? 'Дата начала'
                        : _df.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                        _endDate == null ? 'Дата окончания' : _df.format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _peopleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество людей',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Укажите число людей (не менее 1)';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : Text(_isEditing ? 'Сохранить изменения' : 'Сохранить поездку'),
            ),
          ],
        ),
      ),
    );
  }
}
