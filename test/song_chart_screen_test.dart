import 'package:awake/features/song/sample_songs.dart';
import 'package:awake/features/song/song_chart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('반음 올리면 코드와 인트로가 같이 바뀐다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongChartScreen(song: sampleSong)),
    );

    expect(find.text('| G | D/F# | Em7 | Csus2 |'), findsOneWidget);
    expect(find.text('D/F# '), findsOneWidget);

    await tester.tap(find.byTooltip('반음 올리기'));
    await tester.tap(find.byTooltip('반음 올리기'));
    await tester.pump();

    expect(find.text('| A | E/G# | F#m7 | Dsus2 |'), findsOneWidget);
    expect(find.text('E/G# '), findsOneWidget);
    expect(find.textContaining('원래 조 G → A'), findsOneWidget);
  });
}
