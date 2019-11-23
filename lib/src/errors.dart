class ApiException implements Exception {
  final String message;
  const ApiException([String message]) : this.message = message ?? "API call failed";
  String toString() => 'ApiException: $message';
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String message])
      : super(message ?? "Cannot authenticate user. A common cause is an expired JSON web token.");
  String toString() => 'UnauthenticatedException: $message';
}
