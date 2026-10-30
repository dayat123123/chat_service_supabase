import 'package:cs_console/src/core/api/cs_api.dart';
import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/admin/data/admin_repository.dart';
import 'package:cs_console/src/features/admin/domain/admin_models.dart';
import 'package:cs_console/src/features/admin/presentation/cubit/admin_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockApi extends Mock implements CsApi {}

class _MockFunctions extends Mock implements FunctionsClient {}

Map<String, dynamic> accountJson({bool disabled = false}) => {
  'id': 'a-9',
  'agent_code': 'CS-0300',
  'display_name': 'Fajar',
  'email': 'fajar@cs.olt.local',
  'roles': ['cs_agent'],
  'team': 'general',
  'max_active_tickets': 5,
  'disabled_at': disabled ? '2026-10-30T10:00:00+00:00' : null,
  'status': 'offline',
  'active_tickets': 0,
  'totp': false,
  'created_at': '2026-10-30T09:00:00+00:00',
};

void main() {
  late _MockApi api;
  late _MockFunctions functions;
  late AdminRepository admin;

  setUpAll(() => registerFallbackValue(HttpMethod.post));

  setUp(() {
    api = _MockApi();
    functions = _MockFunctions();
    admin = AdminRepository(api, functions);
  });

  const draft = AccountDraft(
    email: 'fajar@cs.olt.local',
    displayName: 'Fajar',
    roles: ['cs_agent'],
    team: 'general',
    maxActiveTickets: 5,
  );

  test('buat akun lewat fungsi cs-admin dan password sementara diterima sekali', () async {
    when(() => functions.invoke(any(), method: any(named: 'method'), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'agent': accountJson(), 'temporary_password': 'Abcdefghjkmnpqrs2345'}, status: 201),
    );

    final created = await admin.createAccount(draft);

    expect(created.agent.agentCode, 'CS-0300');
    expect(created.temporaryPassword, hasLength(20));
    final call = verify(() => functions.invoke('cs-admin/agents', method: HttpMethod.post, body: captureAny(named: 'body')));
    expect(call.captured.single, {
      'email': 'fajar@cs.olt.local',
      'display_name': 'Fajar',
      'roles': ['cs_agent'],
      'team': 'general',
      'max_active_tickets': 5,
      'disabled': false,
    });
  });

  test('ubah akun tidak mengirim email dan error fungsi dipetakan ke ConsoleError', () async {
    when(() => functions.invoke(any(), method: any(named: 'method'), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'agent': accountJson(disabled: true)}, status: 200),
    );

    final updated = await admin.updateAccount('a-9', draft.copyWith(disabled: true));

    expect(updated.disabled, isTrue);
    final call = verify(() => functions.invoke('cs-admin/agents/a-9', method: HttpMethod.patch, body: captureAny(named: 'body')));
    expect((call.captured.single as Map).containsKey('email'), isFalse);

    when(() => functions.invoke(any(), method: any(named: 'method'), body: any(named: 'body'))).thenThrow(
      const FunctionException(status: 409, details: {'code': 'email_exists', 'message': 'Email sudah dipakai akun lain'}),
    );
    await expectLater(
      admin.createAccount(draft),
      throwsA(isA<ConsoleError>().having((e) => e.code, 'code', 'email_exists').having((e) => e.status, 'status', 409)),
    );
  });

  test('pilihan tim dan skill di-cache, dan dimuat ulang bila gagal', () async {
    var calls = 0;
    when(() => api.object('admin_options')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const ConsoleError('network');
      return {
        'teams': [
          {'code': 'general', 'name': 'Layanan Umum'},
        ],
        'skills': <Object>[],
      };
    });

    await expectLater(admin.options(), throwsA(isA<ConsoleError>()));
    expect((await admin.options()).teams.single.code, 'general');
    await admin.options();
    expect(calls, 2);
  });

  test('daftar admin: simpan memperbarui daftar, gagal simpan melempar error tanpa mengubah daftar', () async {
    final cubit = AdminListCubit<String>(() async => ['salam']);
    await cubit.load();
    expect(cubit.state.status, LoadStatus.ready);

    await cubit.save((items) async => [...items, 'penutup']);
    expect(cubit.state.items, ['salam', 'penutup']);

    await expectLater(
      cubit.save((_) async => throw const ConsoleError('duplicate_shortcut', status: 409)),
      throwsA(isA<ConsoleError>()),
    );
    expect(cubit.state.items, ['salam', 'penutup']);
    expect(cubit.state.saving, isFalse);
    await cubit.close();
  });
}
