import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/annotation.dart';
import '../models/setlist.dart';
import '../models/song.dart';

/// 팀 하나의 Firestore 데이터에 접근한다.
///
/// 경로 구조 (firestore.rules와 맞춰야 함):
/// - teams/{teamId}/members/{uid}
/// - teams/{teamId}/songs/{songId}
/// - teams/{teamId}/setlists/{setlistId}
/// - teams/{teamId}/scores/{scoreId}/annotations/{annotationId}
class TeamRepository {
  TeamRepository(this.teamId, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String teamId;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _team =>
      _db.collection('teams').doc(teamId);

  // ── 곡 ──────────────────────────────────────────────

  Stream<List<Song>> watchSongs() => _team
      .collection('songs')
      .orderBy('title')
      .snapshots()
      .map((s) => [for (final d in s.docs) Song.fromMap(d.id, d.data())]);

  Future<Song?> getSong(String songId) async {
    final doc = await _team.collection('songs').doc(songId).get();
    return doc.exists ? Song.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> saveSong(Song song) =>
      _team.collection('songs').doc(song.id).set(song.toMap());

  // ── 콘티 ────────────────────────────────────────────

  Stream<List<Setlist>> watchSetlists({int limit = 20}) => _team
      .collection('setlists')
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) Setlist.fromMap(d.id, d.data())]);

  /// 콘티 하나를 실시간으로 본다. 인도자가 키나 순서를 바꾸면 바로 반영된다.
  Stream<Setlist?> watchSetlist(String setlistId) => _team
      .collection('setlists')
      .doc(setlistId)
      .snapshots()
      .map((d) => d.exists ? Setlist.fromMap(d.id, d.data()!) : null);

  Future<void> saveSetlist(Setlist setlist) =>
      _team.collection('setlists').doc(setlist.id).set(setlist.toMap());

  // ── 주석 ────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _annotations(String scoreId) =>
      _team.collection('scores').doc(scoreId).collection('annotations');

  /// [uid]가 볼 수 있는 주석 (팀 공유 + 내 개인 주석)을 실시간으로 본다.
  ///
  /// 보안 규칙이 쿼리 단위로 검사되므로, 두 조건을 각각 쿼리하고 합친다.
  Stream<List<Annotation>> watchAnnotations(String scoreId, String uid) {
    final shared = _annotations(scoreId)
        .where('visibility', isEqualTo: AnnotationVisibility.team.name)
        .snapshots();
    final mine = _annotations(scoreId)
        .where('authorId', isEqualTo: uid)
        .where('visibility', isEqualTo: AnnotationVisibility.private.name)
        .snapshots();
    return _combine(shared, mine).map(
      (pair) => [
        for (final snap in pair)
          for (final d in snap.docs) Annotation.fromMap(d.id, d.data()),
      ],
    );
  }

  /// 새 id를 받아서 주석을 만들 때 쓴다.
  String newAnnotationId(String scoreId) => _annotations(scoreId).doc().id;

  /// 펜을 뗄 때(획 단위) 한 번씩 호출한다.
  Future<void> saveAnnotation(String scoreId, Annotation annotation) =>
      _annotations(scoreId).doc(annotation.id).set(annotation.toMap());

  Future<void> deleteAnnotation(String scoreId, String annotationId) =>
      _annotations(scoreId).doc(annotationId).delete();
}

/// 두 스트림의 최신 값을 함께 내보낸다.
Stream<List<T>> _combine<T>(Stream<T> a, Stream<T> b) {
  late StreamController<List<T>> controller;
  StreamSubscription<T>? subA, subB;
  T? lastA, lastB;
  var hasA = false, hasB = false;

  void emit() {
    if (hasA && hasB) controller.add([lastA as T, lastB as T]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
