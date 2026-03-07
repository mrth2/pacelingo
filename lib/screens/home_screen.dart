import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import 'profile_editor_screen.dart';
import 'word_bank_screen.dart';

/// Lesson mode definitions used by the mode selection dialog.
class LessonMode {
  final String name;
  final String description;
  final IconData icon;
  final String? prompt;

  const LessonMode({
    required this.name,
    required this.description,
    required this.icon,
    this.prompt,
  });
}

const List<LessonMode> _lessonModes = [
  LessonMode(
    name: 'Free Talk',
    description: 'Standard conversation practice',
    icon: Icons.chat_bubble_outline_rounded,
    prompt: null,
  ),
  LessonMode(
    name: 'Pronunciation Guru',
    description: 'Focus on phonetics and pronunciation',
    icon: Icons.record_voice_over_rounded,
    prompt:
        'Focus 100% on phonetics. If a word is mispronounced, provide a '
        'phonetic breakdown (e.g., \'Schedule\' is /ˈʃɛdjuːl/) and ask to '
        'repeat. Correct every pronunciation error immediately.',
  ),
  LessonMode(
    name: 'Vocabulary Builder',
    description: 'Learn new advanced words',
    icon: Icons.menu_book_rounded,
    prompt:
        'Try to introduce 3 new advanced words related to the topic and '
        'explain their meanings. Use each word in an example sentence and '
        'ask the learner to create their own sentence with it.',
  ),
];

/// The Home Screen (Profile Selection Dashboard).
///
/// Displays a premium, iPad-friendly layout with a welcome header and large
/// interactive profile cards. Each card shows the user's name, level, and the
/// AI tutor's prepared focus for the next session ([Profile.nextFocus]).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      context.read<ProfileProvider>().loadProfiles(userId: userId);
    });
  }

  Future<void> _onProfileTap(
    BuildContext context,
    Profile profile,
  ) async {
    // Show mode selection dialog before starting the session.
    final selectedMode = await showDialog<LessonMode>(
      context: context,
      builder: (_) => const _LessonModeDialog(),
    );

    // User cancelled the dialog.
    if (selectedMode == null || !context.mounted) return;

    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final chatProvider = context.read<ChatProvider>();

    profileProvider.selectProfile(profile);

    await chatProvider.startSession(
      userId: authProvider.userId!,
      profile: profile,
      lessonModePrompt: selectedMode.prompt,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(lessonModeName: selectedMode.name),
      ),
    );
  }

  void _onEditProfile(BuildContext context, Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<Profile>(
        builder: (_) => ProfileEditorScreen(profile: profile),
      ),
    );
  }

  void _onOpenWordBank(BuildContext context, Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordBankScreen(
          profileId: profile.id,
          profileName: profile.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 52),
                  const Text(
                    'Who is learning today?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a profile to start your AI tutoring session',
                    style: TextStyle(fontSize: 15, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 36),
                  Expanded(child: _ProfileCards(
                    onProfileTap: _onProfileTap,
                    onEditProfile: _onEditProfile,
                    onOpenWordBank: _onOpenWordBank,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF4361EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(Icons.school_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PaceLingo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            Text(
              'Your Personal AI English Tutor',
              style: TextStyle(fontSize: 14, color: Color(0xFF8D99AE)),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Cards
// ---------------------------------------------------------------------------

class _ProfileCards extends StatelessWidget {
  final Future<void> Function(BuildContext, Profile) onProfileTap;
  final void Function(BuildContext, Profile) onEditProfile;
  final void Function(BuildContext, Profile) onOpenWordBank;

  const _ProfileCards({
    required this.onProfileTap,
    required this.onEditProfile,
    required this.onOpenWordBank,
  });

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    if (profileProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4361EE)),
            SizedBox(height: 20),
            Text(
              'Loading profiles…',
              style: TextStyle(fontSize: 16, color: Color(0xFF8D99AE)),
            ),
          ],
        ),
      );
    }

    if (profileProvider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading profiles:\n${profileProvider.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    final profiles = profileProvider.profiles;

    if (profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles found.',
          style: TextStyle(fontSize: 16, color: Color(0xFF8D99AE)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: profiles.map((profile) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ProfileCard(
                  profile: profile,
                  onTap: () => onProfileTap(context, profile),
                  onEdit: () => onEditProfile(context, profile),
                  onOpenWordBank: () => onOpenWordBank(context, profile),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onOpenWordBank;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onOpenWordBank,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  static final FirebaseService _firebaseService = FirebaseService();
  int _masteredCount = 0;

  Profile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _loadMasteredCount();
  }

  @override
  void didUpdateWidget(_ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _loadMasteredCount();
    }
  }

  Future<void> _loadMasteredCount() async {
    try {
      final count = await _firebaseService
          .getMasteredWordCount(profileId: profile.id);
      if (mounted) setState(() => _masteredCount = count);
    } catch (_) {
      // Best-effort; keep 0 on failure.
    }
  }

  Color get _primaryColor {
    if (profile.id.contains('wife')) return const Color(0xFF4361EE);
    if (profile.id.contains('daughter')) return const Color(0xFF7B2D8B);
    return const Color(0xFF06D6A0);
  }

  IconData get _icon {
    if (profile.id.contains('wife')) return Icons.person_rounded;
    if (profile.id.contains('daughter')) return Icons.child_care_rounded;
    return Icons.face_rounded;
  }

  Widget _buildStreakBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFF6B35).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔥',
            style: TextStyle(
              fontSize: 18,
              color: active ? null : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${profile.currentStreak}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNextFocus = profile.nextFocus.isNotEmpty;
    final hasStreak = profile.currentStreak > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 320),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top-right action icons
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Word Bank button
                    Material(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: widget.onOpenWordBank,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit button
                    Material(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: widget.onEdit,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.settings_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Streak flame icon
              _buildStreakBadge(hasStreak),
              const SizedBox(height: 12),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),

              // Name
              Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Level & Age
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${profile.englishLevel} · Age ${profile.age}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),

              // Mini-stat row
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.totalSessions} Sessions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '|',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_masteredCount Words Mastered',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Next Focus
              if (hasNextFocus) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Today's Focus",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.nextFocus,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // CTA
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Start Session →',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lesson Mode Selection Dialog
// ---------------------------------------------------------------------------

class _LessonModeDialog extends StatelessWidget {
  const _LessonModeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4361EE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Color(0xFF4361EE), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Lesson Mode',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        Text(
                          'Choose how you want to practise',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ..._lessonModes.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LessonModeTile(
                    mode: mode,
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonModeTile extends StatelessWidget {
  final LessonMode mode;
  final VoidCallback onTap;

  const _LessonModeTile({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361EE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(mode.icon, color: const Color(0xFF4361EE), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D99AE)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF8D99AE)),
            ],
          ),
        ),
      ),
    );
  }
}
