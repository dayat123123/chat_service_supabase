import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';

abstract interface class LegalRepository {
  Future<List<LegalDocument>> getDocuments();

  Future<void> accept(String documentId);
}
