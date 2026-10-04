# AWAKE 설계 문서

찬양팀 콘티 앱. 인도자가 콘티를 짜고 악보를 고치면, 팀원이 각자 기기에서 실시간으로 본다.

## 1. 요구사항

| # | 기능 | 설명 |
|---|---|---|
| F1 | 콘티 관리 | 예배별 곡 순서, 곡마다 부를 조, 송폼 메모 |
| F2 | 조옮김 | 코드 악보는 자동 조옮김. 이미지 악보는 OCR로 코드를 찾아서 옮김 |
| F3 | 인트로/아웃트로 코드 | 곡 기본값 + 콘티별로 따로 지정. 조를 바꾸면 같이 옮겨짐 |
| F4 | OCR | 악보 안의 글자(코드, 가사, 송폼) 인식 |
| F5 | OMR (오선지 스캔) | 오선 악보 → MusicXML. 외부 오픈소스 사용 |
| F6 | 실시간 공유 | 콘티, 주석이 팀원 기기에 바로 반영 |
| F7 | 주석 | **손글씨와 글자 둘 다**. 개인 주석 / 팀 공유 주석 구분 |
| F8 | 악보 수정 | 코드·가사 편집, 이미지 악보 위 가림 박스 + 새 글자. 음표 편집은 외부 편집기 연동 |
| F9 | 플랫폼 | iOS, Android, Windows, macOS. **모바일과 데스크톱 모두 편집 가능** |

## 2. 기술 선택

| 영역 | 선택 | 이유 |
|---|---|---|
| 앱 | **Flutter (Dart)** | 코드 하나로 모바일과 데스크톱 지원. 펜 입력과 커스텀 그리기에 강함 |
| 백엔드 | **Firebase** (Auth, Firestore, Storage) | Flutter 공식 지원. Firestore 오프라인 캐시가 기본 내장돼서 예배당 와이파이가 약해도 동작 |
| OCR/OMR 서버 | **Python** (Cloud Run) | OMR 라이브러리가 Python/Java라 기기에서 돌릴 수 없음. 데스크톱은 ML Kit도 없음 |
| 결제 (나중에) | RevenueCat | iOS와 Android 구독을 한 번에 관리 |

### 전체 구조

```
Flutter 앱 (iOS / Android / Windows / macOS)
 ├─ 콘티 · 조옮김 · 인트로/아웃트로
 ├─ 악보 뷰어 + 주석 레이어 (손글씨 / 글자 / 가림 박스)
 ├─ 코드·가사 편집기 (ChordPro)
 └─ Firebase
     ├─ Auth: 로그인
     ├─ Firestore: 곡, 콘티, 주석 (실시간)
     └─ Storage: 악보 이미지/PDF
Python 서버 (Cloud Run)
 ├─ POST /ocr  → PaddleOCR (한국어 + 코드 기호)
 ├─ POST /omr  → oemer 또는 Audiveris → MusicXML
 └─ POST /transpose-musicxml → music21
```

## 3. 플랫폼별 차이

| 기능 | 모바일 | 데스크톱 | 처리 방법 |
|---|---|---|---|
| OCR | ML Kit 사용 가능 | ML Kit 미지원 | 서버 OCR로 통일. 모바일은 오프라인일 때만 ML Kit 사용 (선택) |
| Firebase | 완전 지원 | macOS 지원, Windows는 제약 있음 | Windows 빌드를 초기에 확인 |
| 입력 | 손가락, 펜슬 | 마우스, 키보드, 펜 태블릿 | 아래 "주석 입력" 참고 |
| 레이아웃 | 보기 위주 | 편집 위주 | 넓은 화면은 사이드 패널 + 단축키 |

## 4. 데이터 모델 (Firestore)

```
invites/{code}             { teamId, teamName, createdBy }  초대 코드
teams/{teamId}             Team (이름, 주인, 현재 초대 코드)
  members/{uid}            Membership { uid, teamName, displayName, role }
  songs/{songId}           Song
  setlists/{setlistId}     Setlist (곡 목록을 문서 안에 포함)
  scores/{scoreId}         악보 파일 정보 (Storage 경로, 페이지 수)
    annotations/{id}       Annotation
```

- 코드: `lib/models/`, 접근: `lib/data/backend.dart`(인터페이스), `firestore_backend.dart`, 권한: `firestore.rules`
- **"내 팀 목록"** 은 `members` 컬렉션 그룹 쿼리(`uid == 나`)로 만든다. `firestore.indexes.json`에 필요한 인덱스 설정이 있다.
- **팀 단위 구조**로 만들어서, 나중에 팀 단위 구독을 붙이기 쉽게 한다.
- **콘티 문서 하나에 곡 순서, 키, 인트로/아웃트로를 함께 저장**한다. 콘티를 열 때 읽기 1회로 끝난다.

### 권한

| 역할 | 곡/콘티/악보 | 주석 |
|---|---|---|
| leader | 읽기/쓰기 + 멤버 관리 | 자기 주석 + 팀 공유 주석 삭제 |
| editor | 읽기/쓰기 | 자기 주석 + 팀 공유 주석 삭제 |
| member | 읽기 | 자기 주석 |

### 팀 만들기와 참여 (Cloud Functions 없이)

- **팀 만들기**: 팀 문서, 자신의 리더 멤버 문서, 초대 코드 문서를 **한 번의 묶음 쓰기**로 만든다.
  보안 규칙이 `getAfter()`로 "새로 만드는 팀의 주인이 나"인지 확인한다.
- **참여**: `invites/{code}`를 읽어 팀을 찾고, 자기 멤버 문서를 `role: member`, `inviteCode: code`로 만든다.
  보안 규칙이 그 코드가 실제로 이 팀의 초대 코드인지 확인한다. 초대 코드 목록은 조회할 수 없다.
- **초대 코드 새로 만들기**: 리더가 이전 코드를 지우고 새 코드를 만든다. 이전 코드로는 더 이상 참여할 수 없다.
- 리더는 자기 역할을 바꿀 수 없고, 팀 주인은 팀을 나갈 수 없다 (리더가 없는 팀 방지).

보안 규칙 테스트: `rules_test/rules.test.js` (Firestore 에뮬레이터, `cd rules_test && npm install && npm test`)

개인 주석은 작성자만 읽을 수 있다. 앱은 "팀 공유" 쿼리와 "내 개인 주석" 쿼리를 각각 보내서 합친다
(Firestore 보안 규칙은 쿼리 단위로 검사하기 때문).

## 5. 조옮김 (F2, F3)

`lib/core/music/`

- `Chord`: 코드 기호를 근음 / 성격 / 베이스로 나눈다. 성격(`m7`, `sus4` 등)은 해석하지 않고 그대로 둔다.
  OCR 결과에서 코드만 골라낼 때도 `Chord.isChord()`를 쓴다.
- `MusicKey`: 조마다 음 이름 표기 규칙을 가진다.
  1. 음계음은 조표대로 적는다 (F#조의 `E#`, Gb조의 `Cb`).
  2. 나머지 중 자연음은 그대로 적는다.
  3. 남은 음은 플랫 조는 플랫, 샵 조는 샵으로 적는다. 단 샵 조에서도 `Eb`, `Bb`는 플랫 (bIII, bVII 차용 화음이 흔함).
  4. C/Am은 `C# Eb F# Ab Bb`.
- `Transposer`: 원래 조 → 목표 조. 코드 하나, 진행(인트로/아웃트로) 단위로 옮긴다.
- 콘티 항목(`SetlistItem`)은 인트로/아웃트로를 따로 적지 않으면 곡 기본값을 부를 조로 옮겨서 쓴다.
  직접 적었다면 조를 바꿀 때 같이 옮긴다.

### 이미지 악보 조옮김 (예정)

1. OCR로 글자와 위치를 얻는다.
2. `Chord.isChord()`로 코드만 고른다.
3. 각 코드 위치에 `MaskAnnotation`(가림 박스 + 바뀐 코드)을 자동으로 만든다.

즉 이미지 조옮김은 "자동으로 만든 악보 수정 주석"이다. 사용자가 잘못 인식된 곳을 고칠 수 있다.

## 6. 주석 (F7)

`lib/models/annotation.dart`

| 타입 | 용도 | 저장 내용 |
|---|---|---|
| `InkAnnotation` | 손글씨 | 획 목록 (점 + 펜 압력), 색, 굵기 |
| `TextAnnotation` | 글자 | 위치, 내용, 크기, 색 |
| `MaskAnnotation` | 악보 수정 | 가림 영역, 대신 쓸 글자 |

공통:
- **좌표는 페이지 크기 기준 0~1 비율**. 기기 화면 크기와 상관없이 같은 위치에 보인다.
- `visibility`: `private`(개인) / `team`(팀 공유)
- `setlistId`: 특정 콘티에서만 보일 주석 (예: "이번 주는 2절 생략")
- `page`: 여러 페이지 악보의 페이지 번호

### 주석 입력

| 입력 | 동작 |
|---|---|
| 펜슬 / 펜 태블릿 | 필기 |
| 손가락 (펜슬이 있는 기기) | 스크롤, 확대 (손바닥 오인식 방지) |
| 손가락 (펜슬이 없는 기기) | 필기 모드일 때 필기 |
| 마우스 드래그 | 필기 모드일 때 필기 |
| 글자 도구 + 탭/클릭 | 그 위치에 글자 입력 |

### 저장 비용

획을 그리는 도중에는 저장하지 않는다. **펜을 뗄 때 한 번** 저장한다.
점은 `[x0, y0, x1, y1, ...]`로 펼치고 소수점 4자리로 반올림해서 문서 크기를 줄인다.
(Firestore는 배열 안에 배열을 바로 넣을 수 없어서 획마다 맵으로 감싼다.)

## 7. 악보 수정 (F8)

| 단계 | 범위 | 방법 | 상태 |
|---|---|---|---|
| 1 | 코드·가사 | ChordPro 텍스트 편집 + 미리보기 | 파서/조옮김 완료, 편집 화면 예정 |
| 2 | 이미지 악보 | `MaskAnnotation`으로 가리고 새 글자 | 모델 완료, 화면 예정 |
| 3 | 음표 | MusicXML 내보내기 → MuseScore에서 수정 → 가져오기 | 예정 |

음표 편집기는 직접 만들지 않는다. OMR 결과를 고칠 때도 3단계 흐름을 쓴다.

## 8. 개발 순서

1. ✅ 프로젝트 구조, 조옮김, ChordPro, 데이터 모델, 보안 규칙 초안
2. ✅ 로그인, 팀 만들기/초대 코드 참여/역할 관리, 곡/콘티 목록·편집 화면, 보안 규칙 테스트
3. 악보 업로드 (Storage) + 악보 뷰어 (이미지/PDF, 페이지 넘김)
4. 주석 레이어: 손글씨 → 글자 → 가림 박스, 실시간 공유
5. ChordPro 편집 화면 (데스크톱 단축키 포함)
6. Python 서버: OCR → 이미지 악보 코드 인식 → 자동 조옮김
7. OMR (실험 기능) + MusicXML 가져오기/내보내기
8. 유료화: RevenueCat, 팀 플랜

## 9. 앱 구조

```
lib/
  main.dart            Firebase 설정이 있으면 Firebase, 없으면 데모(메모리) 백엔드로 시작
  app/app.dart         로그인 → 팀 선택 → 팀 홈. 팀이 바뀌면 화면 스택을 새로 만든다
  app/scope.dart       BackendScope(백엔드), TeamScope(현재 팀, 내 역할)
  data/backend.dart    AuthService, TeamDirectory, TeamData 인터페이스
  data/memory_backend.dart    데모 모드와 테스트용
  data/firestore_backend.dart Firebase 구현
  features/auth|team|song|setlist  화면
```

- 화면은 인터페이스만 쓴다. 그래서 Firebase 없이 메모리 백엔드로 전체 흐름을 위젯 테스트할 수 있다
  (`test/app_flow_test.dart`).
- 넓은 화면(720px 이상)은 왼쪽 내비게이션 레일, 곡 편집은 편집/미리보기 나란히.
  좁은 화면은 아래 탭, 곡 편집은 편집/미리보기 탭.
- 편집 버튼(곡 추가, 새 콘티, 편집)은 리더와 편집자에게만 보인다. 실제 권한은 보안 규칙이 막는다.

### 데모 모드

`flutterfire configure` 전에는 메모리 백엔드로 실행된다. 데모 계정(`demo@awake.app` / `demo1234`),
"데모 찬양팀", 예제 곡 2개가 들어 있다. 앱을 끄면 데이터는 사라진다.

## 10. 비용 관리

- Blaze 요금제로 전환하면 바로 Google Cloud **예산 알림**을 켠다.
- **App Check**를 적용해서 앱 밖에서 오는 호출을 막는다.
- 콘티는 문서 하나로, 주석은 획 단위로 저장해서 읽기/쓰기 횟수를 줄인다.
