import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

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

class JsonWebTokenAuthorizer implements Authorizer {
  final String _jwt;

  JsonWebTokenAuthorizer(this._jwt);

  void addHeaders(Map<String, String> headers) {
    headers['authorization'] = 'Bearer $_jwt';
  }
}

/// Mints a new JSON Web Token (JWT) that you may later use with
/// JsonWebTokenAuthorizer. Note that the client should use
/// UsernamePasswordAuthorizer; see withClient3.
Future<String> createJsonWebToken(
    {@required String username,
    @required String password,
    @required http.Client client,
    @required String backendUrl}) async {
  var response = await client.post(backendUrl);
  var json = convert.jsonDecode(response.body) as Map<String, dynamic>;
  assert(json["token"] != null);
  assert(json["token"] is String);
  String ret = json["token"] as String;
  assert(ret.isNotEmpty);
  return ret;
}
