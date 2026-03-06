/// Re-exports the voice chat state management from [ChatProvider].
///
/// The [ChatProvider] in `chat_provider.dart` implements the full voice
/// interaction loop (STT → Gemini → TTS) with interruption handling, profile
/// integration, and Firestore persistence. This barrel file provides the
/// `voice_chat_provider` import path referenced in the project specification.
library voice_chat_provider;

export 'chat_provider.dart';
