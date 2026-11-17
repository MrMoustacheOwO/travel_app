import 'dart:async';

import 'package:flutter/material.dart';

class DataLoadingWidget extends StatefulWidget {
  const DataLoadingWidget({
    super.key,
    this.error,
    this.onRetry,
  });

  final String? error;
  final VoidCallback? onRetry;

  @override
  State<DataLoadingWidget> createState() => _DataLoadingWidgetState();
}

class _DataLoadingWidgetState extends State<DataLoadingWidget> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant DataLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) {
      _timer?.cancel();
      _timedOut = false;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.error ??
        (_timedOut
            ? 'Не удалось подключиться к базе данных. Проверьте интернет.'
            : 'Загружаем данные...');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.error == null && !_timedOut)
              const CircularProgressIndicator(),
            if (widget.error == null && !_timedOut) const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if ((widget.error != null || _timedOut) && widget.onRetry != null)
              TextButton(
                onPressed: () {
                  setState(() => _timedOut = false);
                  _startTimer();
                  widget.onRetry!();
                },
                child: const Text('Повторить'),
              ),
          ],
        ),
      ),
    );
  }
}
