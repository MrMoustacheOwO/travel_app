import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/supabase_sync_service.dart';

class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTimer(context.watch<SupabaseSyncService>().syncing);
  }

  @override
  void didUpdateWidget(covariant SyncStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTimer(context.read<SupabaseSyncService>().syncing);
  }

  void _updateTimer(bool syncing) {
    if (!syncing) {
      _timer?.cancel();
      _timer = null;
      _timedOut = false;
      return;
    }
    if (_timer != null) return;
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
    final sync = context.watch<SupabaseSyncService>();
    if (!sync.syncing && sync.error == null) return const SizedBox.shrink();
    final message = sync.error ??
        (_timedOut
            ? 'Не удалось подключиться к базе данных за 10 секунд. Данные останутся в кэше.'
            : 'Синхронизация данных...');
    return Material(
      color: sync.error == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (sync.syncing && !_timedOut)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (sync.syncing && !_timedOut) const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (sync.error != null || _timedOut)
              IconButton(
                tooltip: 'Повторить синхронизацию',
                onPressed: sync.syncNow,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}
