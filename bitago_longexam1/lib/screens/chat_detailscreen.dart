import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.user,
    required this.service,
  });
  final ChatUser user;
  final ChatService service;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  StreamSubscription<List<MessageModel>>? _subscription;
  List<MessageModel> _messages = [];
  bool _loading = true, _sending = false, _foreground = true;
  bool _acknowledging = false, _receiptRetry = false, _receiptsQueued = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _connect();
  }

  Future<void> _connect() async {
    await _subscription?.cancel();
    try {
      await widget.service.openConversation(widget.user.uid);
      if (!mounted) return;
      _subscription = widget.service
          .getMessages(widget.user.uid)
          .listen(
            (messages) {
              if (!mounted) return;
              setState(() {
                _messages = messages;
                _loading = false;
                _error = null;
              });
              _acknowledge();
            },
            onError: (Object error) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _error =
                      'Could not load this conversation. Check your connection and retry.';
                });
              }
            },
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not open this conversation. The account may no longer be available.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _acknowledge();
  }

  Future<void> _acknowledge() async {
    if (!mounted) return;
    if (_acknowledging) {
      _receiptsQueued = true;
      return;
    }
    _acknowledging = true;
    try {
      do {
        if (!mounted) break;
        _receiptsQueued = false;
        final seen =
            _foreground && (ModalRoute.of(context)?.isCurrent ?? false);
        await widget.service.acknowledge(
          widget.user.uid,
          _messages,
          seen: seen,
        );
      } while (mounted && _receiptsQueued);
      if (mounted && _receiptRetry) setState(() => _receiptRetry = false);
    } catch (_) {
      if (mounted) setState(() => _receiptRetry = true);
    } finally {
      _acknowledging = false;
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendMessage(widget.user.uid, text);
      if (!mounted) return;
      _composer.clear();
      _focus.requestFocus();
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message was not sent. Your text is saved below; please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              child: Text(widget.user.name.characters.first.toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    widget.user.email,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (_receiptRetry)
                  MaterialBanner(
                    content: const Text('Could not sync message receipts.'),
                    actions: [
                      TextButton(
                        onPressed: _acknowledge,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _loading = true;
                                      _error = null;
                                    });
                                    _connect();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.waving_hand_outlined,
                                size: 48,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Say hello to ${widget.user.name.split(' ').first}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text('Your conversation starts here.'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          itemCount: _messages.length,
                          findChildIndexCallback: (key) {
                            final index = _messages.indexWhere(
                              (m) => ValueKey(m.id) == key,
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _MessageBubble(
                              key: ValueKey(message.id),
                              message: message,
                              mine:
                                  message.senderId ==
                                  widget.service.currentUserId,
                            );
                          },
                        ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          focusNode: _focus,
                          enabled: !_sending && !_loading && _error == null,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Write a message…',
                            counterText: '',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: _sending ? 'Sending message' : 'Send message',
                        onPressed:
                            _sending ||
                                _loading ||
                                _error != null ||
                                _composer.text.trim().isEmpty
                            ? null
                            : _send,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _sending
                              ? const SizedBox(
                                  key: ValueKey('sending'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward,
                                  key: ValueKey('send'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message, required this.mine});
  final MessageModel message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = message.timestamp?.toDate();
    final time = date == null
        ? ''
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: .8,
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: mine
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.message,
                    style: TextStyle(
                      color: mine
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      if (mine) ...[
                        Icon(
                          message.pending
                              ? Icons.schedule
                              : message.deliveredAt != null ||
                                    message.seenAt != null
                              ? Icons.done_all
                              : Icons.check,
                          size: 15,
                          color: message.seenAt != null
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        Text(
                          message.status,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
