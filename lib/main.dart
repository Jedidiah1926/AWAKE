import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/song/song_chart_screen.dart';
import 'features/song/sample_songs.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initFirebase();
  runApp(AwakeApp(firebaseReady: firebaseReady));
}

/// Firebase 설정 전(firebase_options.dart가 자리 표시용)이면 false.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } on UnsupportedError catch (e) {
    debugPrint('Firebase 없이 실행합니다: ${e.message}');
    return false;
  }
}

class AwakeApp extends StatelessWidget {
  const AwakeApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWAKE',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: SongChartScreen(song: sampleSong),
    );
  }
}
