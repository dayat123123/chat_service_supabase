enum OltSocialErrorKind {
  network,
  unauthenticated,
  rateLimited,
  contentBlocked,
  invalidInput,
  forbidden,
  notFound,
  unavailable,
  unknown,
}

class OltSocialException implements Exception {
  const OltSocialException(this.kind, {this.code, this.message, this.cause});

  const OltSocialException.unauthenticated([String? message])
    : this(OltSocialErrorKind.unauthenticated, message: message);

  final OltSocialErrorKind kind;

  final String? code;

  final String? message;

  final Object? cause;

  @override
  String toString() =>
      'OltSocialException(${kind.name}${code == null ? '' : ', $code'}'
      '${message == null ? '' : ', $message'})';
}
