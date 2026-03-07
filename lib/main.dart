import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';
import 'services/firestore_service.dart';
import 'services/gemini_service.dart';

// ---------------------------------------------------------------------------
// IMPORTANT: Replace with your actual Gemini API key.
// In production, load this from a secure remote config or environment variable.
// NEVER commit a real API key to source control.
// ---------------------------------------------------------------------------
const String _geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PaceLingo());
}

class PaceLingo extends StatelessWidget {
  const PaceLingo({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..signInAnonymously(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(
            firestoreService: FirestoreService(),
            firebaseService: FirebaseService(),
          ),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            geminiService: GeminiService(apiKey: _geminiApiKey),
            firestoreService: FirestoreService(),
            speechToText: SpeechToText(),
            flutterTts: FlutterTts(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'PaceLingo',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _AuthGate(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4361EE),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF4361EE),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}

/// Handles the authentication gate: shows a loading indicator while Firebase
/// Anonymous Auth is in progress, then proceeds to [HomeScreen].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authProvider.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Authentication failed:\n${authProvider.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<AuthProvider>().signInAnonymously(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!authProvider.isSignedIn) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const HomeScreen();
  }
}
