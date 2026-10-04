import 'dart:ui' show Color, Offset, Rect;

/// 누가 볼 수 있는 주석인지.
enum AnnotationVisibility {
  /// 작성자만 (예: 싱어 개인 메모).
  private,

  /// 팀 전체 (예: 인도자 공지).
  team,
}

/// 악보 위에 얹는 주석 하나.
///
/// Firestore: teams/{teamId}/scores/{scoreId}/annotations/{annotationId}
///
/// 좌표는 모두 악보 페이지 크기 기준 0~1 비율이다.
/// 그래서 아이패드에서 쓴 필기가 폰이나 PC에서도 같은 자리에 보인다.
sealed class Annotation {
  const Annotation({
    required this.id,
    required this.authorId,
    required this.page,
    required this.visibility,
    required this.color,
    this.setlistId,
  });

  final String id;
  final String authorId;

  /// 여러 페이지 악보에서 몇 번째 페이지인지 (0부터).
  final int page;
  final AnnotationVisibility visibility;
  final Color color;

  /// 특정 콘티에서만 보이는 주석이면 그 콘티 id. null이면 악보에 항상 표시.
  final String? setlistId;

  /// 각 타입의 고유 값. Firestore 문서의 `type` 필드.
  String get type;

  /// 영역 검사, 선택 표시 등에 쓰는 경계 (0~1 좌표).
  Rect get bounds;

  Map<String, dynamic> toMap() => {
    'type': type,
    'authorId': authorId,
    'page': page,
    'visibility': visibility.name,
    'color': color.toARGB32(),
    'setlistId': setlistId,
    ..._fields(),
  };

  Map<String, dynamic> _fields();

  static Annotation fromMap(String id, Map<String, dynamic> map) {
    final authorId = map['authorId'] as String;
    final page = (map['page'] as num?)?.toInt() ?? 0;
    final visibility = AnnotationVisibility.values.byName(
      map['visibility'] as String,
    );
    final color = Color((map['color'] as num).toInt());
    final setlistId = map['setlistId'] as String?;

    return switch (map['type']) {
      InkAnnotation.typeName => InkAnnotation(
        id: id,
        authorId: authorId,
        page: page,
        visibility: visibility,
        color: color,
        setlistId: setlistId,
        width: (map['width'] as num).toDouble(),
        strokes: [
          for (final s in map['strokes'] as List)
            InkStroke.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
      ),
      TextAnnotation.typeName => TextAnnotation(
        id: id,
        authorId: authorId,
        page: page,
        visibility: visibility,
        color: color,
        setlistId: setlistId,
        position: Offset(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        ),
        text: map['text'] as String,
        fontSize: (map['fontSize'] as num).toDouble(),
      ),
      MaskAnnotation.typeName => MaskAnnotation(
        id: id,
        authorId: authorId,
        page: page,
        visibility: visibility,
        color: color,
        setlistId: setlistId,
        rect: Rect.fromLTWH(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
          (map['w'] as num).toDouble(),
          (map['h'] as num).toDouble(),
        ),
        replacement: map['replacement'] as String?,
      ),
      final other => throw FormatException('알 수 없는 주석 타입: $other'),
    };
  }
}

/// 손글씨 (펜슬, 손가락, 마우스, 펜 태블릿).
///
/// 펜을 뗄 때마다 획이 하나 추가된다. 획을 모아 한 문서에 저장해서 쓰기 횟수를 줄인다.
class InkAnnotation extends Annotation {
  const InkAnnotation({
    required super.id,
    required super.authorId,
    required super.page,
    required super.visibility,
    required super.color,
    super.setlistId,
    required this.strokes,
    required this.width,
  });

  static const typeName = 'ink';

  final List<InkStroke> strokes;

  /// 선 굵기 (페이지 너비 기준 비율).
  final double width;

  @override
  String get type => typeName;

  @override
  Rect get bounds {
    final points = [for (final s in strokes) ...s.points];
    if (points.isEmpty) return Rect.zero;
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    return rect;
  }

  InkAnnotation addStroke(InkStroke stroke) => InkAnnotation(
    id: id,
    authorId: authorId,
    page: page,
    visibility: visibility,
    color: color,
    setlistId: setlistId,
    width: width,
    strokes: [...strokes, stroke],
  );

  @override
  Map<String, dynamic> _fields() => {
    'width': width,
    'strokes': [for (final s in strokes) s.toMap()],
  };
}

/// 획 하나. Firestore는 배열 안의 배열을 저장할 수 없어서
/// 점을 [x0, y0, x1, y1, ...] 형태로 펼쳐서 맵에 담는다.
class InkStroke {
  const InkStroke(this.points, {this.pressures});

  final List<Offset> points;

  /// 펜 압력 (0~1). 펜슬이 아니면 null.
  final List<double>? pressures;

  factory InkStroke.fromMap(Map<String, dynamic> map) {
    final flat = [for (final v in map['p'] as List) (v as num).toDouble()];
    return InkStroke(
      [
        for (var i = 0; i + 1 < flat.length; i += 2)
          Offset(flat[i], flat[i + 1]),
      ],
      pressures: (map['pr'] as List?)
          ?.map((v) => (v as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'p': [
      for (final o in points) ...[_round(o.dx), _round(o.dy)],
    ],
    if (pressures != null) 'pr': [for (final v in pressures!) _round(v)],
  };

  /// 소수점 4자리면 4K 화면에서도 충분하고 문서 크기가 줄어든다.
  static double _round(double v) => (v * 10000).roundToDouble() / 10000;
}

/// 키보드로 입력한 글자 주석.
class TextAnnotation extends Annotation {
  const TextAnnotation({
    required super.id,
    required super.authorId,
    required super.page,
    required super.visibility,
    required super.color,
    super.setlistId,
    required this.position,
    required this.text,
    required this.fontSize,
  });

  static const typeName = 'text';

  /// 글자 왼쪽 위 위치 (0~1).
  final Offset position;
  final String text;

  /// 글자 크기 (페이지 높이 기준 비율).
  final double fontSize;

  @override
  String get type => typeName;

  @override
  Rect get bounds => Rect.fromLTWH(
    position.dx,
    position.dy,
    // 실제 폭은 렌더링해야 알 수 있으므로 대략적인 값.
    fontSize * 0.6 * text.length,
    fontSize * 1.2,
  );

  @override
  Map<String, dynamic> _fields() => {
    'x': position.dx,
    'y': position.dy,
    'text': text,
    'fontSize': fontSize,
  };
}

/// 악보 수정용 가림 박스. 잘못된 코드나 가사를 덮고, 필요하면 새 글자를 쓴다.
/// [color]는 덮는 색 (보통 흰색).
class MaskAnnotation extends Annotation {
  const MaskAnnotation({
    required super.id,
    required super.authorId,
    required super.page,
    required super.visibility,
    required super.color,
    super.setlistId,
    required this.rect,
    this.replacement,
  });

  static const typeName = 'mask';

  final Rect rect;

  /// 가린 자리에 대신 쓸 글자 (예: 잘못 인쇄된 코드를 고친 값).
  final String? replacement;

  @override
  String get type => typeName;

  @override
  Rect get bounds => rect;

  @override
  Map<String, dynamic> _fields() => {
    'x': rect.left,
    'y': rect.top,
    'w': rect.width,
    'h': rect.height,
    'replacement': replacement,
  };
}
