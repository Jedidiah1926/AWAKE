import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../setlist/setlist_list_screen.dart';
import '../song/song_list_screen.dart';
import 'team_settings_screen.dart';

/// 팀 안의 메인 화면. 넓은 화면은 왼쪽 레일, 좁은 화면은 아래 탭.
class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({super.key, required this.onSwitchTeam});

  /// 팀 목록으로 돌아가기.
  final VoidCallback onSwitchTeam;

  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  var _tab = 0;

  static const _destinations = [
    (icon: Icons.queue_music, label: '콘티'),
    (icon: Icons.library_music, label: '곡'),
    (icon: Icons.groups, label: '팀'),
  ];

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => const SetlistListScreen(),
      1 => const SongListScreen(),
      _ => TeamSettingsScreen(onSwitchTeam: widget.onSwitchTeam),
    };

    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
