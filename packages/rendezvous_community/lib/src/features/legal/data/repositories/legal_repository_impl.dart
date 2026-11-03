import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/legal/data/models/legal_document_model.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/repositories/legal_repository.dart';

class LegalRepositoryImpl implements LegalRepository {
  LegalRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<List<LegalDocument>> getDocuments() async {
    final rows = await _api.rpcRows('get_legal_documents');
    return [for (final row in rows) LegalDocumentModel.fromJson(row).toEntity()]..sort(_byKind);
  }

  @override
  Future<void> accept(String documentId) => _api.rpcValue('accept_legal_document', {'p_document_id': documentId});

  static int _byKind(LegalDocument a, LegalDocument b) {
    final kind = a.kind.index.compareTo(b.kind.index);
    return kind != 0 ? kind : a.title.compareTo(b.title);
  }
}
