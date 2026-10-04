# AWAKE

찬양팀 콘티 앱 (Flutter, iOS / Android / Windows / macOS).

- 콘티 관리, 조옮김, 인트로/아웃트로 코드
- 악보 OCR / 오선지 스캔
- 손글씨·글자 주석, 실시간 공유
- 악보 수정 (모바일과 데스크톱 모두)

설계와 개발 순서는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참고하세요.

## 시작하기

```bash
flutter pub get
flutter test
flutter run          # 연결된 기기 또는 데스크톱 (-d macos, -d windows)
```

Firebase를 설정하기 전에는 예제 곡 화면만 실행됩니다.

### Firebase 연결

1. [Firebase 콘솔](https://console.firebase.google.com)에서 프로젝트를 만듭니다.
2. Authentication과 Firestore를 켭니다.
3. 아래 명령으로 `lib/firebase_options.dart`를 생성합니다.
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
4. 보안 규칙을 배포합니다: `firebase deploy --only firestore:rules`

## 폴더 구조

```
lib/
  core/music/       조성, 코드, 조옮김
  core/chordpro/    코드 악보(ChordPro) 파서
  models/           곡, 콘티, 주석
  data/             Firestore 접근
  features/         화면
firestore.rules     Firestore 보안 규칙
docs/               설계 문서
```
