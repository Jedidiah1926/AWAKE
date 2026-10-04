import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../data/memory_backend.dart';

/// 이메일 로그인 / 회원가입.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _signUp = false;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = BackendScope.of(context).auth;
    setState(() => _busy = true);
    await runWithFeedback(
      context,
      () => _signUp
          ? auth.signUp(
              email: _email.text,
              password: _password.text,
              displayName: _name.text,
            )
          : auth.signIn(email: _email.text, password: _password.text),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = BackendScope.of(context).isDemo;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FormWidth(
            maxWidth: 400,
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'AWAKE',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('찬양팀 콘티', textAlign: TextAlign.center),
                    const SizedBox(height: 40),
                    if (_signUp) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          helperText: '팀원에게 보이는 이름',
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '이름을 입력해 주세요.' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: '이메일'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : '이메일을 입력해 주세요.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        helperText: _signUp ? '6자 이상' : null,
                      ),
                      obscureText: true,
                      autofillHints: [
                        _signUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v ?? '').length < 6 ? '6자 이상 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_signUp ? '가입하기' : '로그인'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signUp = !_signUp),
                      child: Text(_signUp ? '이미 계정이 있어요' : '처음이에요 (회원가입)'),
                    ),
                    if (isDemo) ...[
                      const SizedBox(height: 24),
                      Text(
                        '데모 모드 (Firebase 미설정): 데이터는 앱을 끄면 사라집니다.\n'
                        '데모 계정 demo@awake.app / ${MemoryBackend.demoPassword}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
