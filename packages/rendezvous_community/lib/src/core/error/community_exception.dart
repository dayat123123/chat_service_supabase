enum CommunityErrorKind {
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

class CommunityException implements Exception {
  const CommunityException(this.kind, {this.code, this.message, this.cause, this.retryAfter});

  const CommunityException.unauthenticated([String? message])
    : this(CommunityErrorKind.unauthenticated, message: message);

  final CommunityErrorKind kind;

  final String? code;

  final String? message;

  final Object? cause;

  final Duration? retryAfter;

  @override
  String toString() =>
      'CommunityException(${kind.name}${code == null ? '' : ', $code'}'
      '${message == null ? '' : ', $message'})';
}
