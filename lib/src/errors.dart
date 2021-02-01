class ApiException implements Exception {
  final String message;
  const ApiException([String msg]) : message = msg ?? "API call failed";
  @override
  String toString() => 'ApiException: $message';
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String message])
      : super(message ?? "Cannot authenticate user. A common cause is an expired JSON web token.");
  @override
  String toString() => 'UnauthenticatedException: $message';
}
