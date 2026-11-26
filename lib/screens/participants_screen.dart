import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/participant.dart';
import '../models/trip.dart';
import '../models/trip_chat.dart';
import '../providers/auth_provider.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../utils/trip_access.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/participant_tile.dart';
import 'add_participant_screen.dart';
import 'profile_settings_screen.dart';

class ParticipantsScreen extends StatefulWidget {
  final Trip trip;

  const ParticipantsScreen({super.key, required this.trip});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late final TabController _tabController;
  int _selectedTabIndex = 0;
  _ParticipantSort _participantSort = _ParticipantSort.name;
  List<TripChatMessage> _messages = [];
  bool _chatLoading = true;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
      _subscribeToChat();
      _loadMessages(showLoading: true);
    });
  }

  void _subscribeToChat() {
    unawaited(_chatChannel?.unsubscribe());
    _chatChannel = Supabase.instance.client
        .channel('trip-messages-${widget.trip.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: widget.trip.id,
          ),
          callback: (_) => _loadMessages(),
        )
        .subscribe();
  }

  Future<void> _loadMessages({bool showLoading = false}) async {
    final shouldScrollToBottom = !_chatScrollController.hasClients ||
        _chatScrollController.position.maxScrollExtent -
                _chatScrollController.position.pixels <
            100;
    if (showLoading && mounted) setState(() => _chatLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('messages')
          .select('id, trip_id, author_id, body, created_at')
          .eq('trip_id', widget.trip.id)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _messages = rows
            .map((row) => TripChatMessage(
                  id: row['id'] as String,
                  tripId: row['trip_id'] as String,
                  authorId: row['author_id'] as String,
                  text: row['body'] as String? ?? '',
                  createdAt: DateTime.parse(row['created_at'] as String),
                ))
            .toList();
        _chatLoading = false;
      });
      if (shouldScrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_chatScrollController.hasClients) return;
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _chatLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить чат: $error')),
      );
    }
  }

  void _onTabChanged() {
    if (_selectedTabIndex == _tabController.index) return;
    setState(() => _selectedTabIndex = _tabController.index);
  }

  @override
  void didUpdateWidget(covariant ParticipantsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
      _subscribeToChat();
      _loadMessages(showLoading: true);
    }
  }

  @override
  void dispose() {
    unawaited(_chatChannel?.unsubscribe());
    _chatController.dispose();
    _chatScrollController.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('messages').insert({
        'trip_id': widget.trip.id,
        'author_id': userId,
        'body': text,
      });
      _chatController.clear();
      await _loadMessages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить сообщение: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final participantsProvider = context.watch<ParticipantsProvider>();
    final expensesProvider = context.watch<ExpensesProvider>();
    final participants = participantsProvider.participants;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final organizerId = widget.trip.organizerId ?? widget.trip.userId;
    final isOrganizer = isTripOrganizer(widget.trip, currentUser?.id);
    final selfParticipantId = participants
            .where((participant) =>
                participant.userId == currentUser?.id ||
                (isOrganizer &&
                    participant.role == TripParticipantRole.organizer) ||
                (participant.contact.isNotEmpty &&
                    participant.contact.trim().toLowerCase() ==
                        currentUser?.email.trim().toLowerCase()))
            .map((participant) => participant.id)
            .firstOrNull ??
        (isOrganizer ? organizerId : null);
    final displayedParticipants = participants.map((participant) {
      final isCurrentUser = participant.userId == currentUser?.id ||
          (participant.contact.isNotEmpty &&
              currentUser != null &&
              participant.contact.toLowerCase() ==
                  currentUser.email.toLowerCase()) ||
          (isOrganizer && participant.role == TripParticipantRole.organizer);
      return Participant(
        id: participant.id,
        tripId: participant.tripId,
        userId: participant.userId,
        name: isCurrentUser ? 'Вы' : participant.name,
        contact: participant.contact,
        notes: participant.notes,
        status: participant.status,
        role: participant.userId == organizerId
            ? TripParticipantRole.organizer
            : participant.role,
        synced: participant.synced,
        remoteId: participant.remoteId,
      );
    }).toList();
    if (organizerId != null &&
        !displayedParticipants.any((participant) =>
            participant.userId == organizerId ||
            participant.id == organizerId ||
            (isOrganizer &&
                participant.role == TripParticipantRole.organizer))) {
      displayedParticipants.insert(
        0,
        Participant(
          id: organizerId,
          tripId: widget.trip.id,
          userId: organizerId,
          name: organizerId == currentUser?.id ? 'Вы' : 'Организатор',
          contact: organizerId == currentUser?.id ? currentUser!.email : '',
          role: TripParticipantRole.organizer,
        ),
      );
    }
    displayedParticipants.sort((a, b) {
      final aIsSelf = a.id == selfParticipantId;
      final bIsSelf = b.id == selfParticipantId;
      if (aIsSelf != bIsSelf) return aIsSelf ? -1 : 1;

      switch (_participantSort) {
        case _ParticipantSort.name:
          return a.name.compareTo(b.name);
        case _ParticipantSort.status:
          return a.status.index.compareTo(b.status.index);
        case _ParticipantSort.role:
          return a.role.index.compareTo(b.role.index);
      }
    });
    final messages = _messages;

    final participantsList = Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<_ParticipantSort>(
            tooltip: 'Сортировка участников',
            icon: const Icon(Icons.sort),
            initialValue: _participantSort,
            onSelected: (sort) => setState(() => _participantSort = sort),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ParticipantSort.name,
                child: Text('По имени'),
              ),
              PopupMenuItem(
                value: _ParticipantSort.status,
                child: Text('По статусу'),
              ),
              PopupMenuItem(
                value: _ParticipantSort.role,
                child: Text('По роли'),
              ),
            ],
          ),
        ),
        Expanded(
          child: participantsProvider.loading
              ? const Center(child: CircularProgressIndicator())
              : displayedParticipants.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'В поездке пока нет участников.\nНажмите «+», чтобы добавить.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: displayedParticipants.length,
                      itemBuilder: (context, index) {
                        final participant = displayedParticipants[index];
                        final isOrganizerEntry =
                            participant.id == organizerId ||
                                participant.userId == organizerId;
                        final isSelf = participant.id == selfParticipantId;
                        return ParticipantTile(
                          participant: participant,
                          amountPaid: expensesProvider
                              .totalPaidByParticipant(participant.id),
                          onTap: isSelf
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ProfileSettingsScreen(),
                                    ),
                                  );
                                }
                              : isOrganizer && !isOrganizerEntry
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AddParticipantScreen(
                                            tripId: widget.trip.id,
                                            participant: participant,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                          onDelete: isOrganizer && !isOrganizerEntry
                              ? () async {
                                  final ok = await confirmDelete(
                                    context,
                                    title: 'Удалить участника?',
                                    content:
                                        'Участник «${participant.name}» будет удален.',
                                  );
                                  if (!ok || !context.mounted) return;
                                  await context
                                      .read<ParticipantsProvider>()
                                      .deleteParticipant(participant.id);
                                }
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );

    final chatView = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: _chatLoading || messages.isEmpty ? 1 : messages.length,
            itemBuilder: (context, index) {
              if (_chatLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return const Center(child: Text('Сообщений пока нет'));
              }
              final message = messages[index];
              final author = _messageAuthorName(
                message,
                participants,
                currentUser?.id,
                currentUser?.name,
                currentUser?.email,
                organizerId,
              );
              final localDate = message.createdAt.toLocal();
              final now = DateTime.now();
              final timeLabel = localDate.year == now.year &&
                      localDate.month == now.month &&
                      localDate.day == now.day
                  ? DateFormat('HH:mm').format(localDate)
                  : DateFormat('dd.MM HH:mm').format(localDate);
              return Align(
                alignment: message.authorId == currentUser?.id
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: message.authorId == currentUser?.id
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(message.text),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Напишите сообщение...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendChatMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Участники'),
              Tab(text: 'Чат'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [participantsList, chatView],
      ),
      floatingActionButton: isOrganizer && _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddParticipantScreen(tripId: widget.trip.id),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _messageAuthorName(
    TripChatMessage message,
    List<Participant> participants,
    String? currentUserId,
    String? currentUserName,
    String? currentUserEmail,
    String? organizerId,
  ) {
    for (final participant in participants) {
      if (participant.userId == message.authorId &&
          participant.name.trim().isNotEmpty) {
        return participant.name.trim();
      }
      if (participant.id == message.authorId &&
          participant.name.trim().isNotEmpty) {
        return participant.name.trim();
      }
    }

    if (message.authorId == currentUserId) {
      if (currentUserName != null && currentUserName.trim().isNotEmpty) {
        return currentUserName.trim();
      }
      final emailName = currentUserEmail?.split('@').first;
      if (emailName != null && emailName.isNotEmpty) return emailName;
    }

    if (message.authorId == organizerId) {
      final organizer = participants
          .where((participant) =>
              participant.role == TripParticipantRole.organizer &&
              participant.name.trim().isNotEmpty)
          .firstOrNull;
      if (organizer != null) return organizer.name.trim();
    }

    return 'Пользователь';
  }
}

enum _ParticipantSort { name, status, role }
