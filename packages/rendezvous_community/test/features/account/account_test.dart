import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/account/data/repositories/account_repository_impl.dart';

import '../../support/legal_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  group('AccountRepositoryImpl', () {
    test('exports pretty-printed UTF-8 JSON named after the user and the day', () async {
      final api = mockApi();
      final data = {
        'exported_at': '2026-11-03T02:00:00Z',
        'profile': {'username': 'budi_santoso', 'bio': 'Investor ritel · Surabaya'},
        'posts': [
          {'id': 'p-1', 'body': r'$BBCA naik'},
        ],
      };
      when(() => api.rpcValue('export_my_data')).thenAnswer((_) async => data);

      final export = await AccountRepositoryImpl(api, clock: () => DateTime(2026, 11, 3, 9)).exportMyData();

      expect(export.fileName, 'data-komunitas-budi_santoso-20261103.json');
      final text = utf8.decode(export.bytes);
      expect(jsonDecode(text), data);
      expect(text, contains('\n  "profile": {\n    "username": "budi_santoso",'));
      expect(text, contains('Investor ritel · Surabaya'));
      expect(CommunityDataExport.mimeType, 'application/json');
    });

    test('falls back to the session username and then to the user id', () async {
      final api = mockApi();
      when(() => api.rpcValue('export_my_data')).thenAnswer((_) async => {'profile': null});
      when(() => api.currentUserId).thenReturn('72689cd3-ea55-584f-9e84-c257af0564e0');
      final day = DateTime(2026, 1, 9);

      expect(
        (await AccountRepositoryImpl(
          api,
          currentUsername: () => 'sari_invest',
          clock: () => day,
        ).exportMyData()).fileName,
        'data-komunitas-sari_invest-20260109.json',
      );
      expect(
        (await AccountRepositoryImpl(api, clock: () => day).exportMyData()).fileName,
        'data-komunitas-72689cd3-ea55-584f-9e84-c257af0564e0-20260109.json',
      );
    });

    test('deletes the account through the backend', () async {
      final api = mockApi();
      when(() => api.rpcValue(any())).thenAnswer((_) async => null);

      await AccountRepositoryImpl(api).deleteMyAccount();

      verify(() => api.rpcValue('delete_my_account')).called(1);
    });
  });

  group('RendezvousCommunity', () {
    test('deleting the account clears the local community session without signing in again', () async {
      final requests = <String>[];
      final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'u-1', 'exp': expiresAt}))).replaceAll('=', '');
      final community = RendezvousCommunity.create(
        supabaseUrl: 'http://api.test',
        anonKey: 'anon',
        tokenProvider: () async => 'olt-session',
        trackDelivery: false,
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          return switch (request.url.path) {
            '/bridge/v1/exchange' => http.Response(
              jsonEncode({
                'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.c2lnbmF0dXJl',
                'expires_at': expiresAt,
                'user': {'id': 'u-1', 'username': 'budi_santoso'},
              }),
              200,
              request: request,
            ),
            '/rest/v1/rpc/get_legal_documents' => http.Response('[]', 200, request: request),
            '/rest/v1/rpc/delete_my_account' => http.Response('', 204, request: request),
            _ => http.Response('{}', 404, request: request),
          };
        }),
      );
      addTearDown(community.dispose);

      await community.ensureSignedIn();
      await pumpEventQueue();
      expect(requests, ['/bridge/v1/exchange', '/rest/v1/rpc/get_legal_documents']);

      await community.deleteMyAccount();
      await pumpEventQueue();

      expect(community.currentUser, isNull);
      expect(community.consent.loaded, isNull);
      expect(requests, ['/bridge/v1/exchange', '/rest/v1/rpc/get_legal_documents', '/rest/v1/rpc/delete_my_account']);
    });
  });

  group('CommunityAccountSettings', () {
    late FakeLegalRepository legal;
    late FakeAccount account;
    late List<CommunityDataExport> saved;

    setUp(() {
      legal = FakeLegalRepository([updatedTerms, updatedGuidelines.copyWith(isAccepted: true), privacyPolicy]);
      account = FakeAccount(legal);
      saved = [];
    });

    Future<List<int>> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final deletedCalls = <int>[];
      await pumpCommunity(
        tester,
        CommunityAccountSettings(
          onAccountDeleted: () => deletedCalls.add(1),
          exportSaver: (context, export) async {
            saved.add(export);
            return true;
          },
        ),
        account: account,
      );
      return deletedCalls;
    }

    testWidgets('links to every legal document', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Dokumen hukum'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan'), findsWidgets);

      await tester.tap(find.text('Kebijakan Privasi'));
      await tester.pumpAndSettle();
      final reader = find.byType(CommunityLegalDocumentReader);
      expect(find.descendant(of: find.byType(Dialog), matching: reader), findsOneWidget);
      expect(find.descendant(of: reader, matching: find.text('Kebijakan Privasi')), findsOneWidget);
      expect(find.descendant(of: reader, matching: find.text('Versi 1 · berlaku 1 November 2026')), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(reader, findsNothing);
    });

    testWidgets('"Unduh data saya" hands the JSON file to the saver', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Unduh data saya'));
      await tester.pumpAndSettle();

      expect(saved.single.fileName, 'data-komunitas-budi_santoso-20261103.json');
      expect(utf8.decode(saved.single.bytes), contains('"profile"'));
      expect(find.text('Data komunitas Anda sudah diunduh.'), findsOneWidget);
    });

    testWidgets('explains the daily export limit', (tester) async {
      account.exportError = const CommunityException(CommunityErrorKind.rateLimited, code: 'too_many_requests');
      await pumpSettings(tester);

      await tester.tap(find.text('Unduh data saya'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.text('Unduh data dibatasi 3 kali sehari. Coba lagi besok.'), findsOneWidget);
    });

    testWidgets('deleting asks to type HAPUS, shows progress, then calls the host', (tester) async {
      final deletedCalls = await pumpSettings(tester);
      account.deleteGate = Completer<void>();

      await tester.tap(find.text('Hapus akun komunitas'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun komunitas?'), findsOneWidget);
      expect(find.text('Akun trading OLT Anda tidak terpengaruh.'), findsOneWidget);
      expect(
        find.text(
          'Tiket layanan CS tetap tercatat untuk keperluan kepatuhan, tetapi pesan dan lampiran chat CS ikut dihapus.',
        ),
        findsOneWidget,
      );
      expect(find.text('Salinan konten tetap diarsipkan untuk regulator sesuai ketentuan hukum.'), findsOneWidget);

      FilledButton confirm() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hapus akun'));
      expect(confirm().onPressed, isNull);

      final field = find.byKey(const ValueKey('community-delete-confirmation'));
      await tester.enterText(field, 'hapus');
      await tester.pump();
      expect(confirm().onPressed, isNull);

      await tester.enterText(field, 'HAPUS');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus akun'));
      await tester.pump();

      expect(find.text('Menghapus akun komunitas…'), findsOneWidget);
      expect(account.deletes, 1);
      expect(deletedCalls, isEmpty);

      account.deleteGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Hapus akun komunitas?'), findsNothing);
      expect(deletedCalls, [1]);
      expect(find.text('Akun komunitas Anda sudah dihapus.'), findsOneWidget);
    });

    testWidgets('a failed deletion stays in the dialog with the error', (tester) async {
      final deletedCalls = await pumpSettings(tester);
      account.deleteError = const CommunityException(CommunityErrorKind.network);

      await tester.tap(find.text('Hapus akun komunitas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('community-delete-confirmation')), 'HAPUS');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus akun'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus akun komunitas?'), findsOneWidget);
      expect(find.text('Tidak ada koneksi. Periksa jaringan Anda.'), findsOneWidget);
      expect(deletedCalls, isEmpty);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun komunitas?'), findsNothing);
    });

    testWidgets('pending documents show the consent banner at the top', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Syarat & Ketentuan diperbarui — tinjau dan setujui.'), findsOneWidget);
    });
  });
}
