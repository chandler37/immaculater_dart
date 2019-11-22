import 'dart:convert' as convert;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'package:crypto/crypto.dart' as crypto;
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as protobuf;
import 'package:immaculater_dart/src/auth.dart';
import 'package:immaculater_dart/src/generated/core/pyatdl.pb.dart' as pb;

export 'src/auth.dart';
export 'src/generated/core/pyatdl.pb.dart';

// `library immaculater_dart` is not recommended: "When the library directive
// isn’t specified, a unique tag is generated for each library based on its path
// and filename. Therefore, we suggest that you omit the library directive from
// your code unless you plan to generate library-level documentation."
// TODO(chandler37): Look into what library-level documentation would entail.

class ApiException implements Exception {
  final String message;
  const ApiException([String message]) : this.message = message ?? "API call failed";
  String toString() => 'ApiException: $message';
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([String message])
      : super(message ?? "Cannot authenticate user. A common cause is an expired JSON web token.");
}

/// A client of github.com/chandler37/immaculater which is a Django app
class DjangoClient extends http.BaseClient {
  final String userAgent;
  final Authorizer _authorizer;
  final http.Client _inner;

  DjangoClient(this._inner, this._authorizer) : userAgent = "ImmaculaterDart/0.6.0";

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = userAgent;
    _authorizer.addHeaders(request.headers);
    request.headers['content-type'] = "application/x-protobuf";
    return _inner.send(request);
  }
}

/// Returns the current time suitable for pb.Timestamp usage.
Int64 now() {
  return Int64(DateTime.now().microsecondsSinceEpoch);
}

pb.Action newAction({@required String name, @required math.Random prng, String note}) {
  assert(name != null);
  var action = pb.Action();
  action.ensureCommon().ensureMetadata().name = name;
  if (note != null && note.isNotEmpty) {
    action.ensureCommon().ensureMetadata().note = note;
  }
  var ts = action.common.ensureTimestamp();
  ts.ctime = ts.mtime = now();
  action.common.uid = randomUid(prng);
  return action;
}

/// Returns a sane MergeToDoListRequest
pb.MergeToDoListRequest saneMergeRequest() {
  var req = pb.MergeToDoListRequest();
  req.sanityCheck = Int64.parseInt("18369614221190020847");
  // TODO(chandler37): we should change the sanity check value (breaking change
  // in, say, /todo/v2/mergeprotobufs) so that Int64(18369614221190020847) will
  // not be the same to make sure we're ready to run this Dart in the browser
  // where 18369614221190020847 is a double or an imprecise int because of
  // javascript numbers (2**53 limit)
  return req;
}

/// Returns the serialization of a minimal, sane MergeToDoListRequest
Uint8List emptyMergeRequest() {
  return saneMergeRequest().writeToBuffer();
}

int _next32bitInt(math.Random prng) {
  return prng.nextInt(1 << 32);
}

const inboxUid = Int64.ONE;
const rootFolderUid = Int64.TWO;
var sanityCheckForResponse = Int64.parseInt("-77129852519530274"); // no const constructor

/// Returns a uniformly pseudorandom UID u such that -2**63 <= u < 0 or 2 < u <
/// 2**63
Int64 randomUid(math.Random prng) {
  var answer = Int64.ZERO;
  while (answer == Int64.ZERO || answer == inboxUid || answer == rootFolderUid) {
    answer = Int64.fromInts(_next32bitInt(prng), _next32bitInt(prng));
  }
  return answer;
}

pb.ChecksumAndData createChecksumAndData(pb.ToDoList tdl) {
  var result = pb.ChecksumAndData();
  Uint8List bytes = tdl.writeToBuffer();
  result.payloadLength = Int64.parseInt("${bytes.length}");
  result.payload = bytes;
  result.payloadIsZlibCompressed = false;
  result.sha1Checksum = "${crypto.sha1.convert(bytes)}";
  return result;
}

/// Calls /todo/mergeprotobufs which might be a read or a write (that also does
/// a read). Returns null when and only when you did a write and the server did
/// not merge, meaning that you have the latest result and there is no need to
/// update your state with the merged pyatdl.ToDoList. Raises ApiException and
/// errors from package:http.
Future<pb.MergeToDoListResponse> merge(
    {@required String backendUrl,
    @required http.Client client,
    @required Uint8List body,
    bool verbose = false}) async {
  if (backendUrl?.isEmpty ?? true) {
    throw FormatException("Immaculater Django backend must be specified via backendUrl.");
  }
  if (verbose) {
    print('Starting HTTP request. (Do not check in tests that do actual HTTP requests.)');
  }
  var response = await client.post(backendUrl, body: body);
  if (verbose) {
    print('Response status: ${response.statusCode}');
    var pp = response.body.replaceAllMapped(RegExp(r'[^\x20-\x7E]+'), (Match m) {
      if (m.end == m.start) {
        return '\u{00BF}';
      } else {
        return '\n\u{00BF}{${m.end - m.start + 1}}';
      }
    });
    print('Response body with unprintable characters escaped: ${pp}');
  }
  if (response.statusCode == 204) {
    return null;
  }
  if (response.statusCode == 403) {
    throw UnauthenticatedException();
  }
  if (response.statusCode != 200) {
    throw ApiException(
        "unexpected httpStatusCode=${response.statusCode} with body ${response.body}");
  }
  Uint8List bodyList = Uint8List.fromList(response.body.codeUnits);
  if (verbose) {
    print('Response body as base64: ${convert.base64Encode(bodyList)}');
  }
  pb.MergeToDoListResponse resp_pb;
  try {
    resp_pb = pb.MergeToDoListResponse.fromBuffer(bodyList);
  } on protobuf.InvalidProtocolBufferException catch (e) {
    throw ApiException(
        "ill-formatted protocol buffer received; httpStatusCode=${response.statusCode}: $e");
  }
  if (resp_pb.sanityCheck != Int64.parseInt("18369614221190021342")) {
    throw ApiException("sanityCheck found was ${resp_pb.sanityCheck}");
  }
  // Or, for testing: return Future.delayed(Duration(microseconds: 2000000), () => resp_pb);
  return resp_pb;
}

/// Returns true iff respPb.sanityCheck is sane.
bool isSaneResponse(pb.MergeToDoListResponse respPb) {
  // In python3, 2**64-18369614221190021342 is 77129852519530274. Int64 is the
  // wrong abstraction for a `fixed64` field; Uint64 would be better but does
  // not exist. Integer overflow yields -77129852519530274:
  if (sanityCheckForResponse != Int64.parseInt("18369614221190021342")) {
    throw ApiException("Assertion failed re: -77129852519530274 and 18369614221190021342");
  }
  return (respPb.sanityCheck == sanityCheckForResponse);
}

/// Reads in the latest ToDoList, wrapped up in a MergeToDoListResponse.
Future<pb.MergeToDoListResponse> readToDoList(
    {@required String backendUrl, @required http.Client client}) async {
  pb.MergeToDoListResponse resp =
      await merge(backendUrl: backendUrl, client: client, body: emptyMergeRequest());
  if (!isSaneResponse(resp)) {
    throw ApiException("Sanity check failed on response");
  }
  return resp;
}

Future<T> withClient<T>(
    Future<T> fn(
        {@required String backendUrl,
        @required http.Client client,
        @required Uint8List body,
        bool verbose}),
    {@required Authorizer authorizer,
    @required String backendUrl,
    @required Uint8List body,
    @required bool verbose}) async {
  var client = DjangoClient(http.Client(), authorizer);
  try {
    return await fn(backendUrl: backendUrl, client: client, body: body, verbose: verbose);
  } finally {
    client.close();
  }
}

Future<T> withClient2<T>(Future<T> fn({@required String backendUrl, @required http.Client client}),
    {@required Authorizer authorizer, @required String backendUrl}) async {
  var client = DjangoClient(http.Client(), authorizer);
  try {
    return await fn(backendUrl: backendUrl, client: client);
  } finally {
    client.close();
  }
}

Future<T> withClient3<T>(
    Future<T> fn(
        {@required http.Client client,
        @required String backendUrl,
        @required String username,
        @required String password}),
    {@required String backendUrl,
    @required String username,
    @required String password}) async {
  var client = DjangoClient(http.Client(), UsernamePasswordAuthorizer(username, password));
  try {
    return await fn(backendUrl: backendUrl, client: client, username: username, password: password);
  } finally {
    client.close();
  }
}

// TODO(chandler37): maybe make a pull request against dart protobuf library to
// better handle int64, at least when creating ASCII prettyprint which prints
// fixed64 as negative (see sanityCheck)

// TODO(chandler37): Handle timeouts with TimeoutException. Test with
// a new /todo/timeoutplease handler perhaps.

// TODO(chandler37): Note that https://pub.dev/packages/alice exists for flutter
// inspection of http calls.
