import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import '../models/session_summary.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import 'summary_screen.dart';
import 'word_bank_screen.dart';

/// The main tutoring chat screen with an iPad-optimized layout, a massive
/// walkie-talkie style Push-to-Talk microphone button, chat bubble transcript,
/// and text input fallback.
class ChatScreen extends StatefulWidget {
  /// The name of the active lesson mode (e.g. "Free Talk", "Pronunciation Guru").
  final String lessonModeName;

  const ChatScreen({super.key, this.lessonModeName = 'Free Talk'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isEndingSession = false;

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
    if (_isEndingSession) return;

    setState(() => _isEndingSession = true);

    final chatProvider = context.read<ChatProvider>();
    final profileProvider = context.read<ProfileProvider>();

    final summary = await chatProvider.endSession();
    profileProvider.clearSelection();

    if (!context.mounted) return;

    // Navigate to Summary Screen, replacing the chat screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen(
          summary: summary ?? const SessionSummary.empty(),
        ),
      ),
    );
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
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                Expanded(
                  child: _MessageList(
                    messages: chatProvider.messages,
                    scrollController: _scrollController,
                    liveTranscript: chatProvider.liveTranscript,
                  ),
                ),
                if (chatProvider.hasError)
                  _ErrorBanner(
                    chatProvider.error!,
                    onDismiss: chatProvider.clearError,
                  ),
                _BottomActionArea(
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
            Row(
              children: [
                Text(
                  '${profile.englishLevel} • Age ${profile.age}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Mode: ${widget.lessonModeName}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        // Word Bank button
        if (profile != null)
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordBankScreen(
                    profileId: profile.id,
                    profileName: profile.name,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_stories_rounded),
            tooltip: 'Word Bank',
          ),
        _isEndingSession
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : TextButton.icon(
                onPressed: () => _endSession(context),
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.white),
                label:
                    const Text('End Session', style: TextStyle(color: Colors.white)),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_rounded,
                size: 64,
                color: const Color(0xFF4361EE).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Press the microphone to start speaking…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8D99AE), fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
              constraints: const BoxConstraints(maxWidth: 560),
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
                      fontSize: 16,
                      height: 1.5,
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF4361EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
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
// Bottom action area with text input and massive mic button
// ---------------------------------------------------------------------------

class _BottomActionArea extends StatelessWidget {
  final TextEditingController textController;
  final VoidCallback onSendText;
  final ChatProvider chatProvider;

  const _BottomActionArea({
    required this.textController,
    required this.onSendText,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = chatProvider.audioState == ChatAudioState.idle;
    final isProcessing = chatProvider.isProcessing;
    final isSpeaking = chatProvider.isSpeaking;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Massive Push-to-Talk mic button (walkie-talkie style)
          _WalkieTalkieMicButton(chatProvider: chatProvider),
          const SizedBox(height: 16),
          // Text input row as fallback
          Row(
            children: [
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
                            ? 'AI is speaking… (tap mic to interrupt)'
                            : 'Or type a message…',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8D99AE),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0F2F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    suffixIcon: isIdle
                        ? IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF4361EE),
                            ),
                            onPressed: onSendText,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Walkie-Talkie style mic button with pulse animation
// ---------------------------------------------------------------------------

class _WalkieTalkieMicButton extends StatefulWidget {
  final ChatProvider chatProvider;

  const _WalkieTalkieMicButton({required this.chatProvider});

  @override
  State<_WalkieTalkieMicButton> createState() =>
      _WalkieTalkieMicButtonState();
}

class _WalkieTalkieMicButtonState extends State<_WalkieTalkieMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_WalkieTalkieMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final isListening = widget.chatProvider.isListening;
    if (isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = widget.chatProvider;
    final isListening = chatProvider.isListening;
    final isProcessing = chatProvider.isProcessing;
    final isSpeaking = chatProvider.isSpeaking;

    // Mic is tappable when idle, listening, or speaking (for interruption).
    final bool enabled = !isProcessing;

    Color bgColor;
    Widget iconWidget;
    String label;

    if (isListening) {
      bgColor = const Color(0xFFEF233C);
      iconWidget = const Icon(Icons.mic_rounded, color: Colors.white, size: 40);
      label = 'Listening… tap to stop';
    } else if (isProcessing) {
      bgColor = const Color(0xFFFFB347);
      iconWidget = const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
      label = 'AI is thinking…';
    } else if (isSpeaking) {
      bgColor = const Color(0xFF06D6A0);
      iconWidget = const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 40,
      );
      label = 'Tap to interrupt & speak';
    } else {
      bgColor = const Color(0xFF4361EE);
      iconWidget = const Icon(
        Icons.mic_none_rounded,
        color: Colors.white,
        size: 40,
      );
      label = 'Tap to speak';
    }

    // Start or stop pulse animation based on state.
    _syncAnimation();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = isListening ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: _buildButton(bgColor, iconWidget, enabled),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isListening
                  ? const Color(0xFFEF233C)
                  : const Color(0xFF8D99AE),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(Color bgColor, Widget iconWidget, bool enabled) {
    return Tooltip(
      message: widget.chatProvider.isListening
          ? 'Tap to stop'
          : widget.chatProvider.isSpeaking
              ? 'Tap to interrupt & speak'
              : 'Tap to speak',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: enabled
              ? bgColor
              : bgColor.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
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
                    if (widget.chatProvider.isListening) {
                      await widget.chatProvider.stopListening();
                    } else {
                      await widget.chatProvider.startListening();
                    }
                  }
                : null,
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner with dismiss
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onDismiss;

  const _ErrorBanner(this.error, {required this.onDismiss});

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
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
