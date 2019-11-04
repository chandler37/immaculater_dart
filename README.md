# immaculater_dart
Dart-language code encapsulating
[Immaculater's](https://github.com/chandler37/immaculater) mergeprotobuf API
and pyatdl.ToDoList protocol

One future direction is to use this library in a new Immaculater Flutter
app. Instead of dealing with little bits of data, you'll be sending back and
forth the entire to-do list since they're typically small enough for that to be
performant in the very asynchronous world of Flutter.

## Staying up to date with Immaculater's protocol

[Immaculater's](https://github.com/chandler37/immaculater) generates Dart
protocol buffers as a matter of course. Just copy them here with
`pyatdl.proto`.

## What to type

`make lint fmt test`

Which will only work if you have the Dart SDK installed. (I used the Dart SDK,
not the Dart inside of Flutter's SDK.)

# Credit where credit is due

Created from templates made available by Stagehand under a BSD-style
[license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
