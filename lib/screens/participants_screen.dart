import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../models/trip.dart';
import '../models/trip_chat.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/participant_tile.dart';
import 'add_participant_screen.dart';

class ParticipantsScreen extends StatefulWidget {
  final Trip trip;

  const ParticipantsScreen({super.key, required this.trip});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
    });
  }

  @override
  void didUpdateWidget(covariant ParticipantsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  bool _isOrganizer(List<Participant> participants) {
    if (participants.isEmpty) return true;
    return participants.first.role == TripParticipantRole.organizer;
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    TripChatStore.sendMessage(widget.trip.id, author: 'Вы', text: text);
    _chatController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final participantsProvider = context.watch<ParticipantsProvider>();
    final expensesProvider = context.watch<ExpensesProvider>();
    final participants = participantsProvider.participants;
    final isOrganizer = _isOrganizer(participants);
    final messages = TripChatStore.messagesFor(widget.trip.id);

    final participantsList = participantsProvider.loading
        ? const Center(child: CircularProgressIndicator())
        : participants.isEmpty
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
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return ParticipantTile(
                    participant: participant,
                    amountPaid: expensesProvider.totalPaidByParticipant(participant.id),
                    onTap: isOrganizer
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
                    onDelete: isOrganizer
                        ? () async {
                            final ok = await confirmDelete(
                              context,
                              title: 'Удалить участника?',
                              content: 'Участник «${participant.name}» будет удалён.',
                            );
                            if (!ok || !context.mounted) return;
                            await context
                                .read<ParticipantsProvider>()
                                .deleteParticipant(participant.id);
                          }
                        : null,
                  );
                },
              );

    final chatView = Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Align(
                alignment: message.author == 'Вы'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: message.author == 'Вы'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.author,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(message.text),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Участники поездки'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Участники'),
              Tab(text: 'Чат'),
            ],
          ),
        ),
        body: TabBarView(
          children: [participantsList, chatView],
        ),
        floatingActionButton: isOrganizer
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddParticipantScreen(tripId: widget.trip.id),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}
