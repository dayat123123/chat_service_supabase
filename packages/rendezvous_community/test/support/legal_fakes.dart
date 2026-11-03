import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import 'fakes.dart';

const consentRequired = CommunityException(CommunityErrorKind.forbidden, code: 'consent_required');

LegalDocument legalDocument(
  String id, {
  LegalDocumentKind kind = LegalDocumentKind.terms,
  String title = 'Syarat & Ketentuan',
  int version = 1,
  String body = 'Pasal 1\nIsi pasal satu.\n\nPasal 2\nIsi pasal dua.',
  String? changeSummary,
  bool isRequired = true,
  bool isAccepted = false,
}) => LegalDocument(
  id: id,
  kind: kind,
  version: version,
  title: title,
  body: body,
  changeSummary: changeSummary,
  effectiveAt: DateTime.utc(2026, 11, 1, 5),
  isRequired: isRequired,
  isAccepted: isAccepted,
);

final updatedTerms = legalDocument(
  'd-terms',
  version: 3,
  changeSummary: 'Pasal 4 tentang larangan ajakan goreng saham diperjelas.',
);

final updatedGuidelines = legalDocument(
  'd-guide',
  kind: LegalDocumentKind.communityGuidelines,
  title: 'Pedoman Komunitas',
  version: 2,
);

final privacyPolicy = legalDocument(
  'd-privacy',
  kind: LegalDocumentKind.privacy,
  title: 'Kebijakan Privasi',
  isRequired: false,
);

class FakeLegalRepository implements LegalRepository {
  FakeLegalRepository(this.documents);

  List<LegalDocument> documents;
  final accepted = <String>[];
  int loads = 0;
  Object? loadError;

  @override
  Future<List<LegalDocument>> getDocuments() async {
    loads++;
    final error = loadError;
    if (error != null) throw error;
    return [for (final d in documents) accepted.contains(d.id) ? d.copyWith(isAccepted: true) : d];
  }

  @override
  Future<void> accept(String documentId) async => accepted.add(documentId);
}

class FakeAccount implements CommunityAccountDependencies {
  FakeAccount(this.legal, {String? userId = 'u-me'}) : consent = CommunityConsent(legal) {
    if (userId != null) consent.onUserChanged(userId);
  }

  final FakeLegalRepository legal;

  @override
  final CommunityConsent consent;

  Object? exportError;
  final exports = <CommunityDataExport>[];
  int deletes = 0;
  Object? deleteError;
  Completer<void>? deleteGate;

  @override
  Future<CommunityDataExport> exportMyData() async {
    final error = exportError;
    if (error != null) throw error;
    final export = CommunityDataExport(
      bytes: Uint8List.fromList('{\n  "profile": {}\n}'.codeUnits),
      fileName: 'data-komunitas-budi_santoso-20261103.json',
    );
    exports.add(export);
    return export;
  }

  @override
  Future<void> deleteMyAccount() async {
    deletes++;
    await deleteGate?.future;
    final error = deleteError;
    if (error != null) throw error;
  }
}

Future<void> pumpCommunity(
  WidgetTester tester,
  Widget child, {
  FakeAccount? account,
  CommunityDependencies? dependencies,
  Locale locale = const Locale('id'),
}) async {
  final body = CommunityScope(dependencies: dependencies ?? FakeDependencies(), child: child);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      builder: (context, navigator) =>
          account == null ? navigator! : CommunityAccountScope(dependencies: account, child: navigator!),
      home: Scaffold(body: body),
    ),
  );
  await tester.pumpAndSettle();
}
