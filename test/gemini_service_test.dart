import 'package:flutter_test/flutter_test.dart';
import 'package:pacelingo/models/profile.dart';
import 'package:pacelingo/services/gemini_service.dart';

void main() {
  group('GeminiService – Prompt Orchestrator', () {
    late GeminiService service;
    late Profile childProfile;
    late Profile adultProfile;

    setUp(() {
      // API key is not used for prompt-building tests (no network calls).
      service = GeminiService(apiKey: 'test-key');
      childProfile = Profile.defaultChild();
      adultProfile = Profile.defaultAdult();
    });

    test('buildSystemPrompt contains base role text', () {
      final prompt = service.buildSystemPrompt(childProfile);
      expect(prompt, contains('PaceLingo'));
      expect(prompt, contains('English language tutor'));
    });

    test('buildSystemPrompt includes learner profile data', () {
      final prompt = service.buildSystemPrompt(childProfile);
      expect(prompt, contains('Daughter'));
      expect(prompt, contains('11'));
      expect(prompt, contains('intermediate'));
    });

    test('buildSystemPrompt includes personalised teaching rules', () {
      final prompt = service.buildSystemPrompt(childProfile);
      expect(prompt, contains(childProfile.systemPromptRules));
    });

    test('buildSystemPrompt includes correction protocol', () {
      final prompt = service.buildSystemPrompt(childProfile);
      expect(prompt, contains('CORRECTION PROTOCOL'));
    });

    test('buildSystemPrompt includes previous session summary when provided',
        () {
      const summary = 'Learner practised past tense verbs.';
      final prompt =
          service.buildSystemPrompt(childProfile, previousSessionSummary: summary);
      expect(prompt, contains(summary));
      expect(prompt, contains('PREVIOUS SESSION SUMMARY'));
    });

    test(
        'buildSystemPrompt does NOT include previous session section when summary is empty',
        () {
      final prompt =
          service.buildSystemPrompt(childProfile, previousSessionSummary: '');
      expect(prompt, isNot(contains('PREVIOUS SESSION SUMMARY')));
    });

    test(
        'buildSystemPrompt does NOT include previous session section when summary is null',
        () {
      final prompt =
          service.buildSystemPrompt(childProfile, previousSessionSummary: null);
      expect(prompt, isNot(contains('PREVIOUS SESSION SUMMARY')));
    });

    test('buildSystemPrompt adapts to adult profile', () {
      final prompt = service.buildSystemPrompt(adultProfile);
      expect(prompt, contains('Wife'));
      expect(prompt, contains(adultProfile.systemPromptRules));
    });

    test('buildSystemPrompt includes next focus when provided in profile', () {
      final profileWithFocus =
          childProfile.copyWith(nextFocus: 'Focus on past tense verbs.');
      final prompt = service.buildSystemPrompt(profileWithFocus);
      expect(prompt, contains('PRIORITY FOCUS FOR THIS SESSION'));
      expect(prompt, contains('Focus on past tense verbs.'));
    });

    test(
        'buildSystemPrompt does NOT include next focus section when nextFocus is empty',
        () {
      final prompt = service.buildSystemPrompt(childProfile);
      expect(prompt, isNot(contains('PRIORITY FOCUS FOR THIS SESSION')));
    });
  });

  group('Profile model', () {
    test('defaultChild creates correct profile', () {
      final profile = Profile.defaultChild();
      expect(profile.id, 'daughter');
      expect(profile.age, 11);
    });

    test('defaultAdult creates correct profile', () {
      final profile = Profile.defaultAdult();
      expect(profile.id, 'wife');
      expect(profile.age, greaterThan(0));
    });

    test('toFirestore / fromFirestore round-trip preserves data', () {
      final original = Profile.defaultChild();
      final map = original.toFirestore();

      expect(map['name'], original.name);
      expect(map['age'], original.age);
      expect(map['english_level'], original.englishLevel);
      expect(map['system_prompt_rules'], original.systemPromptRules);
      expect(map['next_focus'], original.nextFocus);
    });

    test('copyWith updates only specified fields', () {
      final original = Profile.defaultChild();
      final updated = original.copyWith(name: 'Emma', age: 12);

      expect(updated.name, 'Emma');
      expect(updated.age, 12);
      expect(updated.englishLevel, original.englishLevel);
      expect(updated.id, original.id);
    });

    test('copyWith updates nextFocus field', () {
      final original = Profile.defaultChild();
      final updated =
          original.copyWith(nextFocus: 'Practice irregular verbs.');

      expect(updated.nextFocus, 'Practice irregular verbs.');
      expect(updated.name, original.name);
    });
  });
}
