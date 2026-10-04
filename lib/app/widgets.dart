import 'package:flutter/material.dart';

import '../data/backend.dart';

/// 넓은 화면(데스크톱, 태블릿 가로) 기준 폭.
const wideBreakpoint = 720.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// 넓은 화면에서 폼이 너무 길게 늘어나지 않게 가운데 정렬한다.
class FormWidth extends StatelessWidget {
  const FormWidth({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// 스트림 로딩/오류/빈 상태를 한곳에서 처리한다.
///
/// 스트림은 처음 한 번만 만든다. 화면이 다시 그려질 때마다 새로 구독하면
/// Firestore 리스너가 계속 다시 붙기 때문이다. [id]가 바뀌면 다시 만든다.
class StreamView<T> extends StatefulWidget {
  const StreamView({
    super.key,
    required this.create,
    required this.builder,
    this.id,
    this.empty,
    this.isEmpty,
  });

  final Stream<T> Function() create;
  final Object? id;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? empty;
  final bool Function(T data)? isEmpty;

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(StreamView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _stream = widget.create();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _stream,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '불러오지 못했습니다.\n${snap.error}',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      // 첫 값이 오기 전. (값이 null일 수 있는 스트림도 있어서 hasData로는 판단하지 않는다)
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snap.data as T;
      if (widget.empty != null && (widget.isEmpty?.call(data) ?? false)) {
        return widget.empty!;
      }
      return widget.builder(context, data);
    },
  );
}

/// 빈 목록 안내.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// 비동기 작업을 실행하고, 실패하면 스낵바로 알린다. 성공하면 true.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
  }
  return false;
}

/// 삭제 같은 되돌릴 수 없는 작업 확인.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = '삭제',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// 글자 하나를 입력받는 대화상자. 취소하면 null.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String? hint,
  String initial = '',
  bool capitalize = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPromptDialog(
    title: title,
    label: label,
    action: action,
    hint: hint,
    initial: initial,
    capitalize: capitalize,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.hint,
    required this.initial,
    required this.capitalize,
  });

  final String title, label, action, initial;
  final String? hint;
  final bool capitalize;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: widget.capitalize
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.action)),
    ],
  );
}
