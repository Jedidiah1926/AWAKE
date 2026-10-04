import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../models/team.dart';

/// 위젯 트리 어디서든 백엔드를 꺼내 쓸 수 있게 한다.
class BackendScope extends InheritedWidget {
  const BackendScope({super.key, required this.backend, required super.child});

  final Backend backend;

  static Backend of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackendScope>()!.backend;

  @override
  bool updateShouldNotify(BackendScope oldWidget) =>
      backend != oldWidget.backend;
}

/// 지금 보고 있는 팀과 내 역할, 로그인한 사용자.
class TeamScope extends InheritedWidget {
  const TeamScope({
    super.key,
    required this.user,
    required this.membership,
    required this.data,
    required super.child,
  });

  final AppUser user;
  final Membership membership;
  final TeamData data;

  TeamRole get role => membership.role;
  bool get canEdit => role.canEdit;

  static TeamScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TeamScope>()!;

  @override
  bool updateShouldNotify(TeamScope oldWidget) =>
      user != oldWidget.user ||
      membership.role != oldWidget.membership.role ||
      data != oldWidget.data;
}
