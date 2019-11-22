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
import 'package:immaculater_dart/src/generated/core/pyatdl.pb.dart' as pb;

// TODO(chandler37): All cassettes besides read_before_write*.dart use the SHA1
// checksum of a compressed payload... rerecord them.
import 'cassettes/read_again_now_that_a_starter_todolist_exists.dart' as rantaste;
import 'cassettes/read_before_write0.dart' as rbw0;
import 'cassettes/read_before_write1.dart' as rbw1;
import 'cassettes/read_something_given_empty_input.dart' as rsgei;
import 'cassettes/read_when_no_todolist_exists.dart' as rwntdle;

String backendUrl = Platform.environment["DART_TEST_IMMACULATER_URL"] + "/todo/mergeprotobufs";
String backendUrlJwt = Platform.environment["DART_TEST_IMMACULATER_URL"] + "/todo/v1/create_jwt";
String username = Platform.environment["DART_TEST_IMMACULATER_USERNAME"];
String password = Platform.environment["DART_TEST_IMMACULATER_PASSWORD"];
Authorizer auth = UsernamePasswordAuthorizer(username, password);
// Call /todo/v1/create_jwt to get a JWT, this one expiring in 24 hours:
Authorizer authJwt = JsonWebTokenAuthorizer(Platform.environment["DART_TEST_IMMACULATER_JWT"]);
Authorizer authExpiredJwt =
    JsonWebTokenAuthorizer(Platform.environment["DART_TEST_IMMACULATER_EXPIRED_JWT"]);

Map<String, String> importantResponseHeaders = {
  'content-type': 'application/x-protobuf; messageType="pyatdl.MergeToDoListResponse"'
};

Map<String, String> jsonResponseHeaders = {'content-type': 'application/json'};

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

void assertJwtUrl(String url) {
  if (url != "/todo/v1/create_jwt") {
    throw FormatException("odd URL ${url}");
  }
}

Future<http.Response> Function(http.Request) helpMock(
    {@required Uint8List expectedBodyBytes, @required String resultingBase64}) {
  return (http.Request request) async {
    assertUrl(request.url.path);
    expect(request.bodyBytes, expectedBodyBytes);
    String body;
    if (resultingBase64 == null) {
      body = "";
    } else {
      body = String.fromCharCodes(convert.base64Decode(resultingBase64));
    }
    return http.Response(body, (resultingBase64 == null) ? 204 : 200,
        headers: importantResponseHeaders);
  };
}

Future<http.Response> Function(http.Request) helpMockRaw(
    {@required Uint8List expectedBodyBytes, @required Uint8List resultingBytes}) {
  return (http.Request request) async {
    assertUrl(request.url.path);
    expect(request.bodyBytes, expectedBodyBytes);
    Uint8List body;
    if (resultingBytes == null) {
      body = Uint8List(0);
    } else {
      body = resultingBytes;
    }
    return http.Response.bytes(body, (resultingBytes == null) ? 204 : 200,
        headers: importantResponseHeaders);
  };
}

void expectSaneResponse(pb.MergeToDoListResponse respPb) {
  expect(isSaneResponse(respPb), true);
}

void helpTestJsonError(
    {@required bool recording,
    @required Function updateTdl,
    @required String msg,
    @required int statusCode,
    @required String previousSha1Checksum,
    bool newData = false}) async {
  pb.MergeToDoListResponse beginning = await expectCassetteMatches(
      body: emptyMergeRequest(),
      b64: rbw1.b64,
      sha1Checksum: rbw1.sha1Checksum,
      textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
  if (recording) {
    assertEnvVars();
  }
  updateTdl(beginning.toDoList);
  var req = saneMergeRequest();
  req.latest = createChecksumAndData(beginning.toDoList);
  req.newData = newData;
  if (previousSha1Checksum != null) {
    req.previousSha1Checksum = previousSha1Checksum;
  }
  var body = req.writeToBuffer();
  if (recording) {
    var threw = false;
    try {
      await withClient(merge, backendUrl: backendUrl, authorizer: auth, verbose: true, body: body);
    } on ApiException catch (e) {
      threw = true;
      expect("$e", "ApiException: unexpected httpStatusCode=$statusCode with body $msg");
    }
    expect(threw, true);
    expect("recording", "should now be set to false");
  } else {
    var client = MockClient((request) async {
      assertUrl(request.url.path);
      return http.Response(msg, statusCode, headers: jsonResponseHeaders);
    });
    expect(
        () async => await merge(
            backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
            client: client,
            body: body), throwsA(predicate((Exception e) {
      return e is ApiException &&
          e.message == "unexpected httpStatusCode=${statusCode} with body ${msg}";
    })));
  }
}

void helpTestSuccess(
    {@required bool recording,
    @required Function updateTdl,
    @required String previousSha1Checksum,
    Uint8List responseBytes,
    bool expectNoop = false,
    bool newData = false}) async {
  pb.MergeToDoListResponse beginning = await expectCassetteMatches(
      body: emptyMergeRequest(),
      b64: rbw1.b64,
      sha1Checksum: rbw1.sha1Checksum,
      textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
  if (recording) {
    assertEnvVars();
  }
  updateTdl(beginning.toDoList);
  var req = saneMergeRequest();
  req.latest = createChecksumAndData(beginning.toDoList);
  req.newData = newData;
  if (previousSha1Checksum != null) {
    req.previousSha1Checksum = previousSha1Checksum;
  }
  var body = req.writeToBuffer();
  pb.MergeToDoListResponse resp;
  if (recording) {
    resp = await withClient(merge,
        backendUrl: backendUrl, authorizer: auth, verbose: true, body: body);
  } else {
    assert(expectNoop || responseBytes != null);
    var client = MockClient(helpMockRaw(
        expectedBodyBytes: body,
        resultingBytes: (expectNoop)
            ? null
            : responseBytes)); // rbw1 would not be returned, but we just care about noop vs. otherwise
    resp = await merge(
        backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
        client: client,
        body: body);
  }
  if (expectNoop) {
    expect(resp, null);
  } else {
    expect(resp, pb.MergeToDoListResponse.fromBuffer(responseBytes));
  }
  if (recording) {
    expect("recording", "should now be set to false");
  }
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

void runJsonErrorTests() {
  test('do something requiring a merge, receiving, for now, a 500 with checksums', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          var newAction = pb.Action();
          newAction.ensureCommon().ensureMetadata().name =
              "i remembered to set a UID"; // should not matter
          var prng =
              math.Random(); // truly random so that the new to-do list is guaranteed to mismatch
          newAction.common.uid = randomUid(prng);
          beginning.inbox.actions.add(newAction);
        },
        msg:
            '''{"error": "The server does not yet implement merging, but merging is required because the sha1_checksum of the todolist prior to your input is 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' and the sha1_checksum of the database is 'ca9005dc33a1c988aa6f84a4a94e2904a534013f'"}''',
        statusCode: 500,
        previousSha1Checksum: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
  });

  test('test erroneous previousSha1Checksum passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
        },
        msg:
            '''{"error": "new data should not be based on a previous checksum aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}''',
        statusCode: 422,
        previousSha1Checksum: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        newData: true);
  });

  test('test erroneous data (#1) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
        },
        msg: '''{"error": "req.latest.sha1_checksum given but req.latest.payload is missing"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must have a todo_todolist row already for this to happen:
  test('test erroneous data (#2 empty inbox with tdl) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox();
        },
        msg:
            '''{"error": "You set the new_data bit, but there is already a to-do list in the database. Maybe we should overwrite it? Maybe we should do a potentially ugly merge (ugly because two or more applications are competing to get the user started)? For now we abort and await your pull request."}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#2 empty inbox w/o tdl) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox();
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: empty project in the protocol buffer -- not even a UID is present"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#3 no root) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = inboxUid;
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: protocol buffer error: the root folder, with UID=2, is required"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#4 no inbox) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureRoot().ensureCommon().uid = Int64(2);
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: protocol buffer error: the Inbox project, with UID=1, is required"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#5 no ctx_list) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = inboxUid;
          beginning.ensureRoot().ensureCommon().uid = rootFolderUid;
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: protocol buffer error: the ctx_list is required"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#6 empty ctx_list) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = inboxUid;
          beginning.ensureRoot().ensureCommon().uid = rootFolderUid;
          beginning.ensureCtxList();
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: A ContextList must be nonempty -- add a name."}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  // The User must *not* have a todo_todolist row already for this to happen:
  test('test erroneous data (#7 no UID on ctx_list) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = inboxUid;
          beginning.ensureRoot().ensureCommon().uid = rootFolderUid;
          beginning.ensureCtxList().ensureCommon().ensureMetadata().name = "ctx_list";
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: A UID is missing from or explicitly zero in the protocol buffer!"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  test('test erroneous data (#8 wrong inbox UID) passed in with new_data: true', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = Int64(37); // 1 is correct
          beginning.ensureRoot().ensureCommon().uid = rootFolderUid;
          beginning.ensureCtxList().ensureCommon().ensureMetadata().name = "ctx_list";
          beginning.ensureCtxList().ensureCommon().uid = randomUid(math.Random(400));
        },
        msg: '''{"error": "The given to-do list is ill-formed: Inbox UID is not 1, it is 37"}''',
        statusCode: 422,
        previousSha1Checksum: null,
        newData: true);
  });

  test('test good data passed in with new_data: true', () async {
    var resp = pb.MergeToDoListResponse();
    resp.sha1Checksum = 'd195e655d514be4d94f5bc9eb361b6bace76482d';
    resp.sanityCheck = sanityCheckForResponse;
    await helpTestSuccess(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.clear();
          beginning.ensureInbox().ensureCommon().uid = inboxUid; // 1 is correct
          beginning.ensureRoot().ensureCommon().uid = rootFolderUid;
          beginning.ensureCtxList().ensureCommon().ensureMetadata().name = "ctx_list";
          beginning.ensureCtxList().ensureCommon().uid = randomUid(math.Random(400));
        },
        previousSha1Checksum: null,
        responseBytes: resp.writeToBuffer(),
        newData: true);
  });

  // new_data is false here:
  test('create an action but forget to set its UID and get a 422', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          var newAction = pb.Action();
          newAction.ensureCommon().ensureMetadata().name = "i forgot to set a UID";
          beginning.inbox.actions.add(newAction);
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: Illegal UID value 0 from metadata {\\n  name: \\"i forgot to set a UID\\"\\n}\\n: not in range [-2**63, 0) or (0, 2**63)"}''',
        statusCode: 422,
        previousSha1Checksum: '4124b2ab67458f98e46347977d0c19174fc7b38f');
  });

  test('duplicated UIDs give a graceful error', () async {
    await helpTestJsonError(
        recording: false,
        updateTdl: (pb.ToDoList beginning) {
          beginning.inbox.actions
              .add(newAction(name: "an action", note: "a note\nwith lines", prng: math.Random(42)));
          var a2 = pb.Action();
          a2.ensureCommon().ensureMetadata().name = "another action";
          var ts = a2.common.ensureTimestamp();
          ts.ctime = ts.mtime = now();
          a2.common.uid = beginning.inbox.actions.last.common.uid;
          beginning.inbox.actions.add(a2);
        },
        msg:
            '''{"error": "The given to-do list is ill-formed: A UID -6009336601577921106 is duplicated!"}''',
        statusCode: 422,
        previousSha1Checksum: '4124b2ab67458f98e46347977d0c19174fc7b38f');
  });
}

void runJwtTests() {
  test('happy path creating a JWT', () async {
    bool recording = false;
    if (recording) {
      var token = await withClient3(createJsonWebToken,
          backendUrl: backendUrlJwt, username: username, password: password);
      expect(true, token.contains(RegExp(r'^.*\..*\.[^.]+$')));
    } else {
      var client = MockClient((request) async {
        assertJwtUrl(request.url.path);
        return http.Response('{"token":"e.a.b"}', 200, headers: jsonResponseHeaders);
      });
      var resp = await createJsonWebToken(
          client: client, username: username, password: password, backendUrl: backendUrlJwt);
      expect(resp, "e.a.b");
    }
    expect(false, recording);
  });

  test('happy path authenticating with a JWT', () async {
    bool recording =
        false; // NOTE: change this if you must rerecord. Also, change authJwt's token to something unexpired.
    pb.MergeToDoListResponse beginning = await expectCassetteMatches(
        body: emptyMergeRequest(),
        b64: rbw1.b64,
        sha1Checksum: rbw1.sha1Checksum,
        textOfMergeToDoListResponse: rbw1.textOfMergeToDoListResponse);
    if (recording) {
      assertEnvVars();
    }
    var req = saneMergeRequest();
    var newAction = pb.Action();
    newAction.ensureCommon().ensureMetadata().name = "buy gallons of soymilk";
    var prng = math.Random(37132);
    newAction.common.uid = randomUid(prng);
    beginning.toDoList.inbox.actions.add(newAction);
    req.latest = createChecksumAndData(beginning.toDoList);
    req.overwriteInsteadOfMerge = true;
    pb.MergeToDoListResponse resp;
    var body = req.writeToBuffer();
    if (recording) {
      resp = await withClient(merge,
          backendUrl: backendUrl, authorizer: authJwt, verbose: false, body: body);
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
    expect(false, recording);
  });

  test('expired token HTTP 403 path when authenticating with a JWT', () async {
    bool recording =
        false; // NOTE: change this if you must rerecord. Also, change authJwt's token to something expired.
    if (recording) {
      assertEnvVars();
    }
    var req = saneMergeRequest();
    pb.MergeToDoListResponse resp;
    var body = req.writeToBuffer();
    if (recording) {
      bool caught = false;
      try {
        resp = await withClient(merge,
            backendUrl: backendUrl, authorizer: authExpiredJwt, verbose: false, body: body);
      } on UnauthenticatedException catch (e) {
        expect(true, e is ApiException);
        caught = true;
        expect("Cannot authenticate user. A common cause is an expired JSON web token.", e.message);
      }
      expect(true, caught);
    } else {
      var client = MockClient((request) async {
        assertUrl(request.url.path);
        return http.Response(
            "arbitrary, ignored response body because HTTP status 403 is what matters", 403,
            headers: importantResponseHeaders);
      });
      bool caught = false;
      try {
        resp = await merge(
            backendUrl: backendUrlOrDummySufficientForReplayingCasssettes(),
            client: client,
            body: body);
      } on UnauthenticatedException catch (e) {
        caught = true;
        expect("Cannot authenticate user. A common cause is an expired JSON web token.", e.message);
      }
      expect(true, caught);
    }
    expect(resp, null);
    expect(false, recording);
  });
}

void runTests() {
  runTestsOfUserWithoutTodolistYet();
  runJsonErrorTests();
  runJwtTests();

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
    if (recording) {
      assertEnvVars();
    }
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
    expect(null, resp);
    expect(false, recording);
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
// test("Creating a new Action that is complete except for a Timestamp", () => {
//
// test("Creating a new Action that is blank except for a Timestamp", () => {
//
// test("test deserialization, serialization, and CRUD operations for folders, project, actions, context, notes", () => {

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
