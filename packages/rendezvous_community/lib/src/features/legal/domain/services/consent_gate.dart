import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';

const consentRequiredCode = 'consent_required';
const consentDeclinedCode = 'consent_declined';

bool isConsentRequired(Object error) => mapError(error).code == consentRequiredCode;

class ConsentGate {
  const ConsentGate(this._prompt);

  final Future<bool> Function() _prompt;

  Future<T> run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (!isConsentRequired(error)) rethrow;
      if (!await _prompt()) {
        throw CommunityException(CommunityErrorKind.forbidden, code: consentDeclinedCode, cause: error);
      }
    }
    return action();
  }
}

extension ConsentGateRun on ConsentGate? {
  Future<T> guard<T>(Future<T> Function() action) {
    final gate = this;
    return gate == null ? action() : gate.run(action);
  }
}
