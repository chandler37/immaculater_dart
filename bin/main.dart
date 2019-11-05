import 'dart:math' as math;

import 'package:immaculater_dart/immaculater_dart.dart' as immaculater_dart;

// TODO(chandler37): turn this into a quick capture app that creates actions in
// the Inbox.
void main(List<String> arguments) {
  print('How random is the following number N such that -2**63 <= N < 0 or 0 < N < 2**63?');
  print('${immaculater_dart.randomUid(math.Random())}');
}
