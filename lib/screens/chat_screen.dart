import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';

/// The main tutoring chat screen with a Push-to-Talk microphone button,
/// chat bubble transcript, and text input fallback.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _endSession(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();
    final profileProvider = context.read<ProfileProvider>();

    await chatProvider.endSession();
    profileProvider.clearSelection();

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _onSendText(BuildContext context) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendTextMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    // Scroll to bottom when new messages arrive.
    if (chatProvider.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context, chatProvider),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: _MessageList(
                    messages: chatProvider.messages,
                    scrollController: _scrollController,
                    liveTranscript: chatProvider.liveTranscript,
                  ),
                ),
                if (chatProvider.error != null) _ErrorBanner(chatProvider.error!),
                _BottomInputBar(
                  textController: _textController,
                  onSendText: () => _onSendText(context),
                  chatProvider: chatProvider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ChatProvider chatProvider) {
    final profile = chatProvider.profile;
    return AppBar(
      backgroundColor: const Color(0xFF4361EE),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile != null ? '${profile.name}\'s Session' : 'PaceLingo',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (profile != null)
            Text(
              '${profile.englishLevel} • Age ${profile.age}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _endSession(context),
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
          label: const Text('End', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Message list
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String liveTranscript;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.liveTranscript,
  });

  @override
  Widget build(BuildContext context) {
    final items = messages.length + (liveTranscript.isNotEmpty ? 1 : 0);

    if (items == 0) {
      return const Center(
        child: Text(
          'Press the microphone to start speaking…',
          style: TextStyle(color: Color(0xFF8D99AE), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items,
      itemBuilder: (context, index) {
        if (index == messages.length && liveTranscript.isNotEmpty) {
          return _LiveTranscriptBubble(text: liveTranscript);
        }
        final msg = messages[index];
        return _ChatBubble(message: msg);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) _TutorAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isUser
                    ? const Color(0xFF4361EE)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(_isUser ? 18 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: _isUser ? Colors.white : const Color(0xFF2D3142),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: _isUser
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF8D99AE),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _TutorAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF4361EE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
    );
  }
}

class _LiveTranscriptBubble extends StatelessWidget {
  final String text;

  const _LiveTranscriptBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4361EE).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF4361EE).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 16,
                    color: Color(0xFF4361EE),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFF2D3142),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom input bar
// ---------------------------------------------------------------------------

class _BottomInputBar extends StatelessWidget {
  final TextEditingController textController;
  final VoidCallback onSendText;
  final ChatProvider chatProvider;

  const _BottomInputBar({
    required this.textController,
    required this.onSendText,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = chatProvider.audioState == ChatAudioState.idle;
    final isListening = chatProvider.isListening;
    final isProcessing = chatProvider.isProcessing;
    final isSpeaking = chatProvider.isSpeaking;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: textController,
              enabled: isIdle,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSendText(),
              decoration: InputDecoration(
                hintText: isProcessing
                    ? 'AI is thinking…'
                    : isSpeaking
                        ? 'AI is speaking…'
                        : 'Type a message…',
                hintStyle: const TextStyle(color: Color(0xFF8D99AE)),
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                suffixIcon: isIdle
                    ? IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Color(0xFF4361EE)),
                        onPressed: onSendText,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Push-to-Talk microphone button
          _MicButton(chatProvider: chatProvider),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final ChatProvider chatProvider;

  const _MicButton({required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    final isListening = chatProvider.isListening;
    final isProcessing = chatProvider.isProcessing;
    final isSpeaking = chatProvider.isSpeaking;

    final bool enabled = !isProcessing && !isSpeaking;

    Color bgColor;
    IconData icon;
    String tooltip;

    if (isListening) {
      bgColor = Colors.red;
      icon = Icons.mic_rounded;
      tooltip = 'Tap to stop';
    } else if (isProcessing) {
      bgColor = const Color(0xFFFFB347);
      icon = Icons.hourglass_top_rounded;
      tooltip = 'AI is thinking…';
    } else if (isSpeaking) {
      bgColor = const Color(0xFF06D6A0);
      icon = Icons.volume_up_rounded;
      tooltip = 'AI is speaking…';
    } else {
      bgColor = const Color(0xFF4361EE);
      icon = Icons.mic_none_rounded;
      tooltip = 'Tap to speak';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: enabled ? bgColor : bgColor.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () async {
                    if (isListening) {
                      await chatProvider.stopListening();
                    } else {
                      await chatProvider.startListening();
                    }
                  }
                : null,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;

  const _ErrorBanner(this.error);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
