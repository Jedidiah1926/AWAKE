import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/backend.dart';
import 'data/firestore_backend.dart';
import 'data/memory_backend.dart';
import 'features/song/sample_songs.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AwakeApp(backend: await _createBackend()));
}

/// Firebase가 설정돼 있으면 Firebase, 아니면 데모(메모리) 백엔드.
Future<Backend> _createBackend() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return firebaseBackend();
  } on UnsupportedError catch (e) {
    debugPrint('Firebase 없이 데모 모드로 실행합니다: ${e.message}');
    final memory = MemoryBackend();
    await memory.seedDemo(
      const AppUser(
        uid: 'demo',
        displayName: '데모 인도자',
        email: 'demo@awake.app',
      ),
      songs: sampleSongs,
    );
    return memory.toBackend();
  }
}
