import 'dart:convert' as convert;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:immaculater_dart/immaculater_dart.dart';
import 'package:immaculater_dart/src/auth.dart';
import 'package:immaculater_dart/src/generated/core/pyatdl.pb.dart' as pb;

// TODO(chandler37): All cassettes besides read_before_write*.dart use the SHA1
// checksum of a compressed payload... rerecord them.
import 'cassettes/read_again_now_that_a_starter_todolist_exists.dart' as rantaste;
import 'cassettes/read_before_write0.dart' as rbw0;
import 'cassettes/read_before_write1.dart' as rbw1;
import 'cassettes/read_something_given_empty_input.dart' as rsgei;
import 'cassettes/read_when_no_todolist_exists.dart' as rwntdle;

String backendUrl = Platform.environment["DART_TEST_IMMACULATER_URL"];
String username = Platform.environment["DART_TEST_IMMACULATER_USERNAME"];
String password = Platform.environment["DART_TEST_IMMACULATER_PASSWORD"];
Authorizer auth = UsernamePasswordAuthorizer(username, password);

Map<String, String> importantResponseHeaders = {
  'content-type': 'application/x-protobuf; messageType="pyatdl.MergeToDoListResponse"'
};

Map<String, String> jsonResponseHeaders = {
  'content-type': 'application/json'
};

void main() {
  runTests();
}

String backendUrlOrDummySufficientForReplayingCasssettes() {
  if (backendUrl?.isEmpty ?? true) {
    return "https://www.example.com/todo/mergeprotobufs";
  }
  return backendUrl;
}

// These are only needed when recording cassettes so restrict your check
void assertEnvVars() {
  if (backendUrl?.isEmpty ?? true) {
    throw FormatException(
        "DART_TEST_IMMACULATER_URL environment variable is required, like https://www.example.com/todo/mergeprotobufs");
  }
  if (username?.isEmpty ?? true) {
    throw FormatException(
        "DART_TEST_IMMACULATER_USERNAME environment variable is required, like foobar");
  }
  if (password?.isEmpty ?? true) {
    throw FormatException(
        "DART_TEST_IMMACULATER_PASSWORD environment variable is required, the password");
  }
}

void assertUrl(String url) {
  if (url != "/todo/mergeprotobufs") {
    throw FormatException("odd URL ${url}");
  }
}

Future<http.Response> Function(http.Request) helpMock(
    {@required Uint8List expectedBodyBytes, @required String resultingBase64}) {
  return (http.Request request) async {
    assertUrl(request.url.path);
    expect(request.bodyBytes, expectedBodyBytes);
    return http.Response(String.fromCharCodes(convert.base64Decode(resultingBase64)), 200,
        headers: importantResponseHeaders);
  };
}

void expectSaneResponse(pb.MergeToDoListResponse respPb) {
  expect(respPb.sanityCheck.toInt(), -77129852519530274);
  // In python3, 2**64-18369614221190021342 is 77129852519530274. Int64 is the
  // wrong abstraction for a `fixed64` field; Uint64 would be better but does
  // not exist. Integer overflow yields -77129852519530274:
  expect(Int64.parseInt("-77129852519530274"), Int64.parseInt("18369614221190021342"));
}

Future<pb.MergeToDoListResponse> expectCassetteMatches(
    {@required Uint8List body,
    @required String b64,
    @required String sha1Checksum,
    @required String textOfMergeToDoListResponse}) async {
  Uint8List body = emptyMergeRequest();
  var client = MockClient(helpMock(expectedBodyBytes: body, resultingBase64: b64));
  pb.MergeToDoListResponse respPb = await merge(
      backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(), client: client, body: body);
  expectSaneResponse(respPb);
  expect(respPb.sha1Checksum, sha1Checksum);
  expect(respPb.toString(), textOfMergeToDoListResponse);
  return respPb;
}

void runTestsOfUserWithoutTodolistYet() {
  // "No to-do list" means "no row in the todo_todolist table", just a row in auth_user.
  //
  // This test case requires poking around on the Django backend. You can only
  // run it once before you must delete the todo_todolist row using the /admin
  // interface (or create a new user via the /admin interface). The
  // DART_TEST_IMMACULATER_USERNAME environment variable must match the User
  // without a to-do list. But you must, after running it, try to read with an
  // emptyMergeRequest() as input, because that's what triggered the issue fixed
  // by
  // https://github.com/chandler37/immaculater/commit/60470dc090968391707cf657a869a3797563946d
  test(
      'doing a read (with an empty input) of a User with no to-do list yet should result in the creation of a starter to-do list that is saved to the database',
      () async {
    await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rwntdle.b64,
        sha1Checksum: rwntdle.sha1Checksum,
        textOfMergeToDoListResponse: rwntdle.textOfMergeToDoListResponse);
  });

  // This test case follows on after the above 'doing a read (with an empty
  // input) of a User with no to-do list' test case.
  test('after the first read that created the starter template, a second read of the same.',
      () async {
    await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rantaste.b64,
        sha1Checksum: rantaste.sha1Checksum,
        textOfMergeToDoListResponse: rantaste.textOfMergeToDoListResponse);
  });
}

void runTests() {
  runTestsOfUserWithoutTodolistYet();

  // This example template does a merge() call that actually makes an HTTP call
  // and uses verbose mode to display some base64 (the heart of what we call a
  // "cassette", a term that is an homage to VCR, a Ruby framework we could
  // really use in Dart) for you to use later with a mock client
  // (MockClient). Great tests do not require network access except for the
  // initial HTTP call when writing the test.
  test("SKIPPED EXAMPLE of how you record a cassette for later playback.", () async {
    assertEnvVars();
    pb.MergeToDoListResponse _ = await withClient(merge,
        backendUrl: backendUrl, authorizer: auth, verbose: true, body: emptyMergeRequest());
    expect("your next move", """
        is to use what was printed on stdout to construct a cassette like cassettes/read_something_given_empty_input.dart and use a MockClient to simulate this HTTP call so that tests do not require network access.
        """);
  }, skip: "NOTE: When you want to add a new test requiring an HTTP call, use this technique.");

  test('cassette rbw0 internal consistency', () async {
    await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw0.b64,
        sha1Checksum: rbw0.sha1Checksum,
        textOfMergeToDoListResponse: rbw0.textOfMergeToDoListResponse);
  });

  test('cassette rbw1 internal consistency', () async {
    await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw1.b64,
        sha1Checksum: rbw1.sha1Checksum,
        textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
  });

  test(
      'merge() given empty input and gets a mocked response from rsgei cassette -- in this case the User already had a to-do list created by logging into the Django webapp',
      () async {
    await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rsgei.b64,
        sha1Checksum: rsgei.sha1Checksum,
        textOfMergeToDoListResponse: rsgei.textOfMergeToDoListResponse);
  });

  test('do something requiring a merge, receiving, for now, a 500 with checksums', () async {
    bool recording = false; // NOTE: change this if you must rerecord.
    pb.MergeToDoListResponse beginning = await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw1.b64,
        sha1Checksum: rbw1.sha1Checksum,
        textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
    assertEnvVars();
    var req = saneMergeRequest();
    var newAction = pb.Action();
    newAction.ensureCommon().ensureMetadata().name = "i remembered to set a UID";  // should not matter
    var prng = math.Random(37);
    newAction.common.uid = randomUid(prng);
    beginning.toDoList.inbox.actions.add(newAction);
    req.latest = createChecksumAndData(beginning.toDoList);
    req.previousSha1Checksum = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    var msg = '''{"error": "The server does not yet implement merging, but merging is required because the sha1_checksum of the todolist prior to your input is 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' and the sha1_checksum of the database is 'f5d57bd3462b245cafb529d8eb19d6929504910b'"}''';
    var client = MockClient((request) async {
        assertUrl(request.url.path);
        return http.Response(msg, 500, headers: jsonResponseHeaders);
    });
    var body = req.writeToBuffer();
    if (recording) {
      await withClient(merge,
        backendUrl: backendUrl, authorizer: auth, verbose: false, body: body);
      expect("should have thrown", "but did not");
    } else {
      expect(
        () async => await merge(
          backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
          client: client,
          body: body),
        throwsA(predicate(
            (Exception e) {
              return e is ApiException && e.message == "unexpected httpStatusCode=500 with body " + msg;
      })));
    }
  });

  test('create an action but forget to set its UID and get a 422', () async {
    bool recording = false; // NOTE: change this if you must rerecord.
    pb.MergeToDoListResponse beginning = await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw1.b64,
        sha1Checksum: rbw1.sha1Checksum,
        textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
    assertEnvVars();
    var req = saneMergeRequest();
    var newAction = pb.Action();
    newAction.ensureCommon().ensureMetadata().name = "i forgot to set a UID";
    beginning.toDoList.inbox.actions.add(newAction);
    req.latest = createChecksumAndData(beginning.toDoList);
    req.previousSha1Checksum = 'f5d57bd3462b245cafb529d8eb19d6929504910b';
    var msg = '''{"error": "The given to-do list is ill-formed: Illegal UID value 0 from metadata {\n  name: \"i forgot to set a UID\"\n}\n: not in range [-2**63, 0) or (0, 2**63)"}''';
    var statusCode = 422;
    var client = MockClient((request) async {
        assertUrl(request.url.path);
        return http.Response(msg, statusCode, headers: jsonResponseHeaders);
    });
    var body = req.writeToBuffer();
    if (recording) {
      await withClient(merge,
        backendUrl: backendUrl, authorizer: auth, verbose: false, body: body);
      expect("should have thrown", "but did not");
    } else {
      expect(
        () async => await merge(
          backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
          client: client,
          body: body),
        throwsA(predicate(
            (Exception e) {
              return e is ApiException && e.message == "unexpected httpStatusCode=${statusCode} with body " + msg;
      })));
    }
  });

  // To set this up you must know the sha1_checksum of the uncompressed
  // pyatdl.ToDoList in the database, and the database does use compression so
  // you cannot simply decrypt todo_todolist.encrypted_contents2 and look at
  // pyatdl.ChecksumAndData.sha1_checksum because it sums the compressed
  // payload. So how do you learn it? By doing a read. See SKIPPED EXAMPLE of
  // how you record a cassette for later playback and record a new cassette.
  //
  // When it works, make sure it works when you do it again (assuming your input
  // is deterministic). You should run it twice once it succeeds because such a
  // write is idempotent (HTTP 204 each time) so long as the database is not
  // mutated in between.
  //
  // Then set 'recording = false' so the tests do not do HTTP interactions but
  // still run the setup code so it doesn't become stale.
  test(
      'create an action and write it and verify the read returned nothing new (null merge() result from HTTP 204 NO CONTENT)',
      () async {
    bool recording = false; // NOTE: change this if you must rerecord.
    pb.MergeToDoListResponse beginning = await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw1.b64,
        sha1Checksum: rbw1.sha1Checksum,
        textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
    assertEnvVars();
    var req = saneMergeRequest();
    var newAction = pb.Action();
    newAction.ensureCommon().ensureMetadata().name =
        "buy even more soymilk plus write a Flutter app using immaculater_dart";
    var prng = math.Random(37);
    newAction.common.uid = randomUid(prng);
    beginning.toDoList.inbox.actions.add(newAction);
    req.latest = createChecksumAndData(beginning.toDoList);
    req.previousSha1Checksum = rbw1.sha1Checksum;
    pb.MergeToDoListResponse resp;
    var body = req.writeToBuffer();
    if (recording) {
      resp = await withClient(merge,
          backendUrl: backendUrl, authorizer: auth, verbose: false, body: body);
    } else {
      var client = MockClient((request) async {
        assertUrl(request.url.path);
        return http.Response("", 204, headers: importantResponseHeaders);
      });
      resp = await merge(
          backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
          client: client,
          body: body);
    }
    expect(resp, null);
  });

  test('insane protobuf encoding in mocked response', () async {
    var client = MockClient((request) async {
      assertUrl(request.url.path);
      return http.Response(String.fromCharCodes([0, 255]), 200, headers: importantResponseHeaders);
    });

    expect(
        () async => await merge(
            backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
            client: client,
            body: emptyMergeRequest()),
        throwsA(predicate((Exception e) =>
            e is ApiException &&
            e.message ==
                'ill-formatted protocol buffer received; httpStatusCode=200: InvalidProtocolBufferException: Protocol message contained an invalid tag (zero).')));
  });

  test('insane sanity check in mocked response', () async {
    var client = MockClient((request) async {
      assertUrl(request.url.path);
      return http.Response("", 200, headers: importantResponseHeaders);
    });

    expect(
        () async => await merge(
            backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
            client: client,
            body: emptyMergeRequest()),
        throwsA(predicate(
            (Exception e) => e is ApiException && e.message == 'sanityCheck found was 0')));
  });

  test('sha1 checksum via creating ChecksumAndData', () async {
    var csd = createChecksumAndData(pb.ToDoList());
    expect(csd.sha1Checksum, "da39a3ee5e6b4b0d3255bfef95601890afd80709");
  });

  test('randomUid', () {
    var prng = math.Random(37);
    expect(randomUid(prng), Int64.parseInt("3419955505961620937"));
    expect(randomUid(prng), Int64.parseInt("-5429577978529790140"));
    expect(randomUid(prng), Int64.parseInt("3715348543216817317"));
  });
}

// TODO(chandler37): Add more test cases, including:
//
// test("Creating a new Action that is complete except for a Timestamp but otherwise blank", () => {
// test("makeMergeToDoListRequestToMergeOursWithTheirs", () => {
// test("test deserialization, serialization, and CRUD operations for folders, project, actions, context, notes", () => {
// Plus coverage of 'new_data: true' (with and without 'latest' filled in).

// TODO(chandler37): implement Matcher that uses
// https://github.com/google/diff-match-patch/wiki/Language:-Dart because for
// these multi-KB strings the default equals Matcher gives a nearly useful diff
// in terms of character position. If you use '''strings''' it isn't quite as
// bad since the character position matches reality mostly.

// TODO(chandler37): Run code coverage tools to automate making sure we're
// actually calling the functions that we define here.

// TODO(chandler37): Simulate doing a write that seems to fail but did work on
// the backend. Test how one recovers from that by reading, checking to see if
// it worked on the backend, and otherwise using the read value to reapply the
// delta.
