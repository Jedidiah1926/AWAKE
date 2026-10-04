// 자리 표시용 파일입니다.
//
// Firebase 프로젝트를 만든 뒤 아래 명령을 실행하면 이 파일이 실제 설정으로 바뀝니다.
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// 설정 전에는 앱이 Firebase 없이 (예제 데이터로) 실행됩니다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase가 아직 설정되지 않았습니다. `flutterfire configure`를 실행하세요.',
  );
}
