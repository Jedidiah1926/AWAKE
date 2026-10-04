import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../models/team.dart';

/// 팀 정보, 초대 코드, 멤버 목록과 역할 관리.
class TeamSettingsScreen extends StatelessWidget {
  const TeamSettingsScreen({super.key, required this.onSwitchTeam});

  final VoidCallback onSwitchTeam;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final scope = TeamScope.of(context);
    final teamId = scope.membership.teamId;

    return Scaffold(
      appBar: AppBar(
        title: Text(scope.membership.teamName),
        actions: [
          TextButton.icon(
            onPressed: onSwitchTeam,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('팀 바꾸기'),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: backend.auth.signOut,
          ),
        ],
      ),
      body: FormWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(scope.user.displayName),
              subtitle: Text('내 역할: ${scope.role.label}'),
            ),
            if (scope.role.canManage) _InviteCard(teamId: teamId),
            const SizedBox(height: 16),
            Text('멤버', style: Theme.of(context).textTheme.titleMedium),
            StreamView<List<Membership>>(
              create: () => backend.teams.watchMembers(teamId),
              id: teamId,
              builder: (context, members) => Column(
                children: [
                  for (final m in members)
                    _MemberTile(
                      member: m,
                      isMe: m.uid == scope.user.uid,
                      canManage: scope.role.canManage,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    final teams = BackendScope.of(context).teams;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamView(
          create: () => teams.watchTeam(teamId),
          id: teamId,
          builder: (context, team) {
            final code = team?.inviteCode;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('초대 코드'),
                const SizedBox(height: 4),
                SelectableText(
                  code ?? '-',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                const Text('이 코드를 받은 사람은 멤버로 참여할 수 있습니다.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: code == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: code),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('복사했습니다.')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy),
                      label: const Text('복사'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await confirm(
                          context,
                          title: '초대 코드 새로 만들기',
                          message: '이전 코드로는 더 이상 참여할 수 없습니다.',
                          action: '새로 만들기',
                        );
                        if (ok && context.mounted) {
                          await runWithFeedback(
                            context,
                            () => teams.regenerateInviteCode(teamId),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('새로 만들기'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
  });

  final Membership member;
  final bool isMe;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final teams = BackendScope.of(context).teams;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          member.displayName.isEmpty
              ? '?'
              : member.displayName.characters.first,
        ),
      ),
      title: Text(isMe ? '${member.displayName} (나)' : member.displayName),
      subtitle: Text(member.role.label),
      // 리더는 다른 사람의 역할만 바꿀 수 있다 (리더가 없어지는 것 방지).
      trailing: canManage && !isMe
          ? PopupMenuButton<Object>(
              tooltip: '역할 변경',
              onSelected: (choice) async {
                if (choice is TeamRole) {
                  await runWithFeedback(
                    context,
                    () => teams.setRole(member, choice),
                  );
                } else if (choice == #remove) {
                  final ok = await confirm(
                    context,
                    title: '팀에서 내보내기',
                    message: '${member.displayName}님을 팀에서 내보낼까요?',
                    action: '내보내기',
                  );
                  if (ok && context.mounted) {
                    await runWithFeedback(
                      context,
                      () => teams.removeMember(member),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                for (final role in TeamRole.values)
                  CheckedPopupMenuItem(
                    value: role,
                    checked: role == member.role,
                    child: Text(role.label),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: #remove, child: Text('내보내기')),
              ],
            )
          : null,
    );
  }
}
