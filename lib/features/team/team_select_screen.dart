import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../data/backend.dart';
import '../../models/team.dart';

/// 내 팀 목록. 팀 만들기, 초대 코드로 참여.
class TeamSelectScreen extends StatelessWidget {
  const TeamSelectScreen({
    super.key,
    required this.user,
    required this.onSelect,
  });

  final AppUser user;
  final ValueChanged<Membership> onSelect;

  Future<void> _create(BuildContext context) async {
    final name = await askText(
      context,
      title: '팀 만들기',
      label: '팀 이름',
      hint: '예: 청년부 찬양팀',
      action: '만들기',
    );
    if (name == null || !context.mounted) return;
    final teams = BackendScope.of(context).teams;
    Membership? created;
    await runWithFeedback(
      context,
      () async => created = await teams.createTeam(name: name, owner: user),
    );
    if (created != null) onSelect(created!);
  }

  Future<void> _join(BuildContext context) async {
    final code = await askText(
      context,
      title: '초대 코드로 참여',
      label: '초대 코드',
      hint: '리더에게 받은 8자리 코드',
      action: '참여',
      capitalize: true,
    );
    if (code == null || !context.mounted) return;
    final teams = BackendScope.of(context).teams;
    Membership? joined;
    await runWithFeedback(
      context,
      () async => joined = await teams.joinTeam(code: code, user: user),
    );
    if (joined != null) onSelect(joined!);
  }

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.group_add),
          label: const Text('팀 만들기'),
        ),
        OutlinedButton.icon(
          onPressed: () => _join(context),
          icon: const Icon(Icons.vpn_key),
          label: const Text('초대 코드로 참여'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.displayName}님의 팀'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: backend.auth.signOut,
          ),
        ],
      ),
      body: StreamView<List<Membership>>(
        create: () => backend.teams.watchMyTeams(user.uid),
        id: user.uid,
        isEmpty: (teams) => teams.isEmpty,
        empty: EmptyMessage(
          icon: Icons.groups,
          message: '아직 속한 팀이 없습니다.\n팀을 만들거나 리더에게 받은 초대 코드로 참여하세요.',
          action: actions,
        ),
        builder: (context, teams) => FormWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in teams)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups),
                    title: Text(m.teamName),
                    subtitle: Text(m.role.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(m),
                  ),
                ),
              const SizedBox(height: 16),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
