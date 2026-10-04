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

Firebase를 설정하기 전에는 **데모 모드**(메모리 저장, 앱을 끄면 사라짐)로 실행됩니다.
데모 계정: `demo@awake.app` / `demo1234`

### Firebase 연결

- Firebase 프로젝트: `awake-praise` (`.firebaserc`)
- 앱 ID: `com.pilcrow1926.awake` (Android, iOS, macOS)

1. Firebase 콘솔에서 Authentication(**이메일/비밀번호** 로그인)과 Firestore를 켭니다.
2. 아래 명령으로 앱을 등록하고 설정 파일을 만듭니다 (본인 PC에서, 브라우저 로그인 필요).
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --project=awake-praise --platforms=android,ios,macos,windows
   ```
   생성되는 `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`는 커밋합니다.
3. 보안 규칙과 인덱스를 배포합니다: `firebase deploy --only firestore`

### 보안 규칙 테스트 (Firestore 에뮬레이터, Java 필요)

```bash
cd rules_test
npm install
npm test
```

## 폴더 구조

```
lib/
  app/              앱 진입 흐름, 공용 위젯
  core/music/       조성, 코드, 조옮김
  core/chordpro/    코드 악보(ChordPro) 파서
  models/           곡, 콘티, 주석, 팀
  data/             백엔드 (인터페이스, Firebase, 데모용 메모리)
  features/         화면 (로그인, 팀, 곡, 콘티)
firestore.rules     Firestore 보안 규칙
rules_test/         보안 규칙 테스트 (에뮬레이터)
docs/               설계 문서
```
