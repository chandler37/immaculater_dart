import 'dart:convert' as convert;

abstract class Authorizer {
  // TODO(chandler37): Use a JSON Web Token (JWT) in another class (as opposed
  // to username and password)
  void addHeaders(Map<String, String> headers);
}

class UsernamePasswordAuthorizer implements Authorizer {
  final String _username;
  final String _password;

  UsernamePasswordAuthorizer(this._username, this._password);

  void addHeaders(Map<String, String> headers) {
    String plaintextPassword = convert.base64Encode(convert.utf8.encode('$_username:$_password'));
    headers['authorization'] = 'Basic ' + plaintextPassword;
  }
}
