import 'dart:io' as io;
import 'dart:math' as math;
import 'package:meta/meta.dart';

import 'package:immaculater_dart/immaculater_dart.dart' as immaculater_dart;

String backendUrl = io.Platform.environment["IMMACULATER_URL"];

void prettyPrintInbox(immaculater_dart.ToDoList tdl) {
  print("The inbox contains the following actions:");
  for (var x in tdl.inbox.actions) {
    print("${x.common.metadata.name}");
    print("");
  }
}

/// Returns an error or the empty string upon success. tdlAndChecksum is a single-item list
/// perhaps containing null if you do not have the to-do list yet. NOTE: tdlAndChecksum is
/// not the result of calling immaculater_url.merge; it is a convenient data
/// structure to contain a ToDoList and a checksum.
Future<String> addAction(
    {@required String name,
    @required math.Random prng,
    @required immaculater_dart.Authorizer auth,
    @required List<immaculater_dart.MergeToDoListResponse> tdlAndChecksum}) async {
  assert(tdlAndChecksum.length == 1);
  var req = immaculater_dart.saneMergeRequest();
  if (tdlAndChecksum[0] == null) {
    tdlAndChecksum[0] = await immaculater_dart.withClient2(immaculater_dart.readToDoList,
        authorizer: auth, backendUrl: backendUrl);
    prettyPrintInbox(tdlAndChecksum[0].toDoList);
  }
  // We must preserve their version of the checksum because we don't serialize
  // the same necessarily across Dart and python.
  req.previousSha1Checksum = tdlAndChecksum[0].sha1Checksum;
  if (req.previousSha1Checksum?.isEmpty ?? true) {
    req.previousSha1Checksum =
        immaculater_dart.createChecksumAndData(tdlAndChecksum[0].toDoList).sha1Checksum;
  }
  tdlAndChecksum[0].toDoList.inbox.actions.add(immaculater_dart.newAction(name: name, prng: prng));
  req.latest = immaculater_dart.createChecksumAndData(tdlAndChecksum[0].toDoList);
  try {
    immaculater_dart.MergeToDoListResponse resp = await immaculater_dart.withClient(
        immaculater_dart.merge,
        backendUrl: backendUrl,
        authorizer: auth,
        verbose: false,
        body: req.writeToBuffer());
    print("Added action successfully");
    tdlAndChecksum[0].sha1Checksum = resp.sha1Checksum;
  } on immaculater_dart.ApiException catch (e) {
    return "$e";
  }
  return "";
}

String readLine({bool echoMode = true}) {
  io.stdin.echoMode = echoMode;
  var line = io.stdin.readLineSync();
  if (line == null || line.isEmpty || line.trim() == "exit") {
    print("\nAll done. Exiting.");
    io.exit(0);
  }
  return line;
}

immaculater_dart.Authorizer fillInParams() {
  String username = io.Platform.environment["IMMACULATER_USERNAME"];
  String password = io.Platform.environment["IMMACULATER_PASSWORD"];

  if (backendUrl?.isEmpty ?? true) {
    io.stdout.write("Immaculater URL (or set the env var IMMACULATER_URL)> ");
    var line = readLine().trim();
    backendUrl = line;
  }
  if (!backendUrl.endsWith("/todo/mergeprotobufs")) {
    if (backendUrl.endsWith("/")) {
      backendUrl += "todo/mergeprotobufs";
    } else {
      backendUrl += "/todo/mergeprotobufs";
    }
  }

  if (username?.isEmpty ?? true) {
    io.stdout.write("username (or set the env var IMMACULATER_USERNAME)> ");
    var line = readLine().trim();
    username = line;
  }

  if (password?.isEmpty ?? true) {
    io.stdout.write("password (or set the env var IMMACULATER_PASSWORD)> ");
    var line = readLine(echoMode: false).trim();
    password = line;
  }

  return immaculater_dart.UsernamePasswordAuthorizer(username, password);
}

/// A quick capture app that creates actions in the Inbox.
void main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    print("Takes no arguments but found ${arguments.length} arguments.");
    io.exit(1);
  }
  immaculater_dart.Authorizer auth = fillInParams();
  var prng = math.Random();
  List<immaculater_dart.MergeToDoListResponse> tdlAndChecksum =
      List<immaculater_dart.MergeToDoListResponse>.filled(1, null);
  while (true) {
    io.stdout.write("Action to capture in your inbox> ");
    var line = readLine();
    if (line == null) {
      print("\nAll done.");
      io.exit(0);
    }
    line = line.trim();
    if (line.isNotEmpty) {
      String error =
          await addAction(name: line, auth: auth, prng: prng, tdlAndChecksum: tdlAndChecksum);
      if (error.isEmpty) {
        print("Added.");
      } else {
        tdlAndChecksum[0] = null; // Let's read again since the to-do list changed remotely
        print("ERROR: $error");
        print("Please retry.");
      }
    }
  }
}
