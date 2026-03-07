import 'package:flutter/material.dart';

import '../models/word_item.dart';
import '../services/firebase_service.dart';

/// A beautiful "Notebook" aesthetic Word Bank screen with two tabs:
/// "New Vocabulary" and "Common Mistakes".
///
/// Each tab shows a list of [WordItem]s with a mastered toggle switch.
/// Designed for an iPad-friendly, kid-rewarding experience.
class WordBankScreen extends StatefulWidget {
  final String profileId;
  final String profileName;

  const WordBankScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<WordBankScreen> createState() => _WordBankScreenState();
}

class _WordBankScreenState extends State<WordBankScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  List<WordItem> _allItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWordBank();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWordBank() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items =
          await _firebaseService.getWordBank(profileId: widget.profileId);
      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load Word Bank: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMastered(WordItem item) async {
    final newValue = !item.isMastered;

    // Optimistic UI update.
    setState(() {
      final index = _allItems.indexWhere((w) => w.id == item.id);
      if (index != -1) {
        _allItems[index] = item.copyWith(isMastered: newValue);
      }
    });

    try {
      await _firebaseService.toggleWordMastered(
        profileId: widget.profileId,
        wordId: item.id,
        isMastered: newValue,
      );
    } catch (_) {
      // Revert on failure.
      setState(() {
        final index = _allItems.indexWhere((w) => w.id == item.id);
        if (index != -1) {
          _allItems[index] = item.copyWith(isMastered: !newValue);
        }
      });
    }
  }

  List<WordItem> get _vocabularyItems =>
      _allItems.where((w) => w.type == WordItemType.vocabulary).toList();

  List<WordItem> get _mistakeItems =>
      _allItems.where((w) => w.type == WordItemType.mistake).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4A3F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_stories_rounded, size: 26),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.profileName}\'s Word Bank',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Your personal vocabulary notebook',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF4A261),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              text: 'New Vocabulary (${_vocabularyItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.error_outline_rounded, size: 20),
              text: 'Common Mistakes (${_mistakeItems.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: Color(0xFF5B4A3F)),
                  SizedBox(height: 16),
                  Text(
                    'Opening your notebook…',
                    style:
                        TextStyle(fontSize: 16, color: Color(0xFF8D99AE)),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWordBank,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _WordList(
                      items: _vocabularyItems,
                      emptyIcon: Icons.menu_book_rounded,
                      emptyTitle: 'No vocabulary yet!',
                      emptySubtitle:
                          'Start a tutoring session to discover new words.',
                      onToggleMastered: _toggleMastered,
                      isMistakeTab: false,
                    ),
                    _WordList(
                      items: _mistakeItems,
                      emptyIcon: Icons.check_circle_outline_rounded,
                      emptyTitle: 'No mistakes recorded!',
                      emptySubtitle:
                          'Great job! Keep practising to stay error-free.',
                      onToggleMastered: _toggleMastered,
                      isMistakeTab: true,
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word List
// ---------------------------------------------------------------------------

class _WordList extends StatelessWidget {
  final List<WordItem> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function(WordItem) onToggleMastered;
  final bool isMistakeTab;

  const _WordList({
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onToggleMastered,
    required this.isMistakeTab,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: const Color(0xFFCDBBAF)),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B4A3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF8D99AE)),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          itemCount: items.length,
          itemBuilder: (context, index) => _WordCard(
            item: items[index],
            onToggleMastered: onToggleMastered,
            isMistake: isMistakeTab,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word Card
// ---------------------------------------------------------------------------

class _WordCard extends StatelessWidget {
  final WordItem item;
  final Future<void> Function(WordItem) onToggleMastered;
  final bool isMistake;

  const _WordCard({
    required this.item,
    required this.onToggleMastered,
    required this.isMistake,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = item.isMastered
        ? const Color(0xFFE8F5E9)
        : isMistake
            ? const Color(0xFFFFF3E0)
            : Colors.white;

    final accentColor = isMistake
        ? const Color(0xFFE76F51)
        : const Color(0xFF2A9D8F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isMastered
              ? const Color(0xFF81C784)
              : accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isMistake
                    ? Icons.edit_note_rounded
                    : Icons.auto_stories_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3142),
                      decoration:
                          item.isMastered ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.definition.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.definition,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (item.exampleSentence.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded,
                              size: 16, color: Color(0xFF8D99AE)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.exampleSentence,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (item.isMastered) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFF4A261)),
                        SizedBox(width: 4),
                        Text(
                          'Mastered!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Mastered toggle
            Column(
              children: [
                Switch(
                  value: item.isMastered,
                  onChanged: (_) => onToggleMastered(item),
                  activeColor: const Color(0xFF4CAF50),
                  inactiveThumbColor: const Color(0xFFCDBBAF),
                  inactiveTrackColor: const Color(0xFFE8E0D8),
                ),
                Text(
                  item.isMastered ? 'Mastered' : 'Learning',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: item.isMastered
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF8D99AE),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
