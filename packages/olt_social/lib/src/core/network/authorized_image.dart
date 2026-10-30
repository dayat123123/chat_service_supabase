class AuthorizedImage {
  const AuthorizedImage(this.url, this.headers);

  final String url;
  final Map<String, String> headers;
}
