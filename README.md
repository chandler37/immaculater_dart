# immaculater_dart
Dart-language code encapsulating
[Immaculater's](https://github.com/chandler37/immaculater) mergeprotobufs API
for reading and writing personal to-do lists with actions, contexts, projects,
folders, and notes.

One future direction is to use this library in a new Immaculater Flutter
app. Instead of dealing with little bits of data, you'll be sending back and
forth the entire to-do list since they're typically small enough for that to be
performant in the asynchronous world of Flutter (it is just for one person,
after all).

Users can then have their choice of the
[Immaculater](https://github.com/chandler37/immaculater) classic web
application or a Flutter mobile/desktop/web app. They will be able to
simultaneously use a Flutter iOS app and a Flutter desktop app thanks to
mergeprotobufs' ability to synchronize various clients.

To understand this library you must understand the mergeprotobufs API which is
documented in the
[source](https://github.com/chandler37/immaculater/blob/master/todo/views.py)
(search for `def mergeprotobufs(request):`).

In short, though, mergeprotobufs is the way to read and to write. A write is
also a read, sometimes, if another device has changed the to-do list in the
interim.


## Is it any good?

Not yet. The backend has no ability to merge just yet, for one thing, but much
more testing is necessary before data loss is unlikely.

Authentication will change away from username plus password to JSON Web Tokens
(JWTs) or something similar before 1.0.0.


## Staying up to date with Immaculater's protocol

[Immaculater](https://github.com/chandler37/immaculater) generates Dart
protocol buffers as a matter of course. Just copy them here with
`pyatdl.proto`.


## What to type

If you're using this library, watch this space for
instructions. TODO(chandler37): Give instructions beyond "Call merge()".

If you're developing this library, type this:

`make lint fmt test`

Which will only work if you have the Dart SDK installed. (I used the Dart SDK
via [Homebrew](https://brew.sh/), not the Dart inside of Flutter's SDK.)


## How does it work under the hood?

We use a mix of JSON (for errors returned), HTTP 204 NO CONTENT, and [protocol
buffers](https://developers.google.com/protocol-buffers/docs/darttutorial) for
the input and output of mergeprotobufs. It is not gRPC.

To make progress, learn how `immaculater_dart_test.dart` works. There is a
skipped test that can be used to make the test suite hit a live backend. Record
that interaction in a "cassette". The tests should not require network access.


## Credit where credit is due

Created from templates made available by Stagehand under a BSD-style
[license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
