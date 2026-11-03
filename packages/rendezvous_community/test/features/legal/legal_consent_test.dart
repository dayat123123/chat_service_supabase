import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/legal/data/repositories/legal_repository_impl.dart';

import '../../support/legal_fakes.dart';
import '../../support/mock_api.dart';

Map<String, dynamic> _row(
  String id,
  String kind, {
  int version = 1,
  String? summary,
  bool required = true,
  bool accepted = false,
}) => {
  'id': id,
  'kind': kind,
  'version': version,
  'title': 'Judul $id',
  'body': 'Baris satu\nBaris dua',
  'change_summary': summary,
  'effective_at': '2026-11-01T05:00:00+00:00',
  'required': required,
  'accepted': accepted,
};

void main() {
  group('LegalRepositoryImpl', () {
    test('maps get_legal_documents rows and orders them by kind', () async {
      final api = mockApi();
      when(() => api.rpcRows('get_legal_documents')).thenAnswer(
        (_) async => [
          _row('p', 'privacy', required: false),
          _row('g', 'community_guidelines', version: 4, summary: '  Larangan spam diperjelas.  '),
          _row('t', 'terms', version: 2, summary: '   ', accepted: true),
          _row('x', 'cookies'),
        ],
      );

      final documents = await LegalRepositoryImpl(api).getDocuments();

      expect(documents.map((d) => d.kind), [
        LegalDocumentKind.terms,
        LegalDocumentKind.communityGuidelines,
        LegalDocumentKind.privacy,
        LegalDocumentKind.other,
      ]);
      final terms = documents[0];
      expect(terms.version, 2);
      expect(terms.body, 'Baris satu\nBaris dua');
      expect(terms.changeSummary, isNull);
      expect(terms.isPending, isFalse);
      expect(terms.effectiveAt, DateTime.utc(2026, 11, 1, 5));
      final guidelines = documents[1];
      expect(guidelines.changeSummary, 'Larangan spam diperjelas.');
      expect(guidelines.isPending, isTrue);
      expect(guidelines.isUpdate, isTrue);
      expect(documents[2].isPending, isFalse);
    });

    test('accepts a document by id', () async {
      final api = mockApi();
      when(() => api.rpcValue(any(), any())).thenAnswer((_) async => null);

      await LegalRepositoryImpl(api).accept('d-1');

      verify(() => api.rpcValue('accept_legal_document', {'p_document_id': 'd-1'})).called(1);
    });
  });

  group('CommunityConsent', () {
    late FakeLegalRepository legal;
    late CommunityConsent consent;

    setUp(() {
      legal = FakeLegalRepository([updatedTerms, updatedGuidelines, privacyPolicy]);
      consent = CommunityConsent(legal);
    });

    tearDown(() => consent.dispose());

    test('loads once per session and again when another user signs in', () async {
      consent.onUserChanged('u-1');
      await pumpEventQueue();
      expect(legal.loads, 1);
      expect(consent.pendingNow.map((d) => d.id), ['d-terms', 'd-guide']);

      await consent.documents();
      await consent.pending();
      consent.ensureLoaded();
      consent.onUserChanged('u-1');
      await pumpEventQueue();
      expect(legal.loads, 1);

      consent.onUserChanged(null);
      expect(consent.loaded, isNull);
      consent.onUserChanged('u-2');
      await pumpEventQueue();
      expect(legal.loads, 2);
    });

    test('accepting refreshes the documents and clears the pending list', () async {
      consent.onUserChanged('u-1');
      await pumpEventQueue();
      var notified = 0;
      consent.addListener(() => notified++);

      await consent.accept(['d-terms', 'd-guide']);

      expect(legal.accepted, ['d-terms', 'd-guide']);
      expect(consent.pendingNow, isEmpty);
      expect(legal.loads, 2);
      expect(notified, greaterThan(0));
    });

    test('a dismissed banner stays hidden until a new document is pending', () async {
      legal.documents = [updatedGuidelines];
      consent.onUserChanged('u-1');
      await pumpEventQueue();
      expect(consent.bannerDocuments.single.id, 'd-guide');

      consent.dismissBanner();
      expect(consent.bannerDocuments, isEmpty);

      legal.documents = [updatedGuidelines, updatedTerms];
      await consent.documents(refresh: true);
      expect(consent.bannerDocuments.single.id, 'd-terms');
    });

    test('waits before retrying after a failed load', () async {
      var now = DateTime(2026, 11, 3, 9);
      final retrying = CommunityConsent(legal, clock: () => now);
      addTearDown(retrying.dispose);
      legal.loadError = const CommunityException(CommunityErrorKind.notFound, code: 'PGRST202');

      retrying.onUserChanged('u-1');
      await pumpEventQueue();
      retrying.ensureLoaded();
      await pumpEventQueue();
      expect(legal.loads, 1);

      legal.loadError = null;
      now = now.add(const Duration(seconds: 31));
      retrying.ensureLoaded();
      await pumpEventQueue();
      expect(legal.loads, 2);
      expect(retrying.pendingNow, hasLength(2));
    });

    test('shows one consent prompt at a time', () async {
      var shown = 0;
      Future<bool> show() async {
        shown++;
        await pumpEventQueue();
        return true;
      }

      final results = await Future.wait([consent.prompt(show), consent.prompt(show)]);

      expect(results, [true, true]);
      expect(shown, 1);
    });
  });

  group('ConsentGate', () {
    test('asks for consent once and retries the action once', () async {
      var prompts = 0;
      var calls = 0;
      final gate = ConsentGate(() async {
        prompts++;
        return true;
      });

      final result = await gate.run(() async {
        calls++;
        if (calls == 1) throw consentRequired;
        return 'post';
      });

      expect(result, 'post');
      expect((prompts, calls), (1, 2));
    });

    test('a declined prompt keeps the action from running again', () async {
      var calls = 0;
      final gate = ConsentGate(() async => false);

      await expectLater(
        gate.run<void>(() async {
          calls++;
          throw consentRequired;
        }),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'consent_declined')),
      );
      expect(calls, 1);
    });

    test('does not loop when the server still asks for consent after accepting', () async {
      var prompts = 0;
      final gate = ConsentGate(() async {
        prompts++;
        return true;
      });

      await expectLater(
        gate.run<void>(() async => throw consentRequired),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'consent_required')),
      );
      expect(prompts, 1);
    });

    test('other errors pass through without a prompt', () async {
      var prompts = 0;
      final gate = ConsentGate(() async {
        prompts++;
        return true;
      });

      await expectLater(
        gate.run<void>(() async => throw const CommunityException(CommunityErrorKind.rateLimited)),
        throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.rateLimited)),
      );
      expect(prompts, 0);
    });
  });
}
