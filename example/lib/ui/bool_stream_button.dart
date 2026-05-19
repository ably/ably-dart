import 'package:flutter/material.dart';
import 'package:stream_transform/stream_transform.dart';

/// [BoolStreamButton] makes sure that all Stream<bool> passed to it
/// has a true value before enabling the button. If any stream has a false
/// value, it will be disabled.
class BoolStreamButton extends StatelessWidget {
  final Stream<bool>? stream;
  final List<Stream<bool>>? streams;
  final VoidCallback onPressed;
  final Widget child;

  BoolStreamButton({
    required this.onPressed,
    required this.child,
    this.stream,
    this.streams,
    super.key,
  }) {
    if (stream != null && streams != null) {
      throw Exception('Use either streams or stream argument, not both');
    }
  }

  Stream<bool> combineStreams(List<Stream<bool>> streams) {
    final first = streams.first;
    final others = <Stream<bool>>[...streams.skip(1)];
    return first
        .combineLatestAll(others)
        .map((boolList) => !boolList.contains(false));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: (streams != null) ? combineStreams(streams!) : stream,
        builder: (context, snapshot) => TextButton(
          onPressed:
              (snapshot.hasData && snapshot.data == true) ? onPressed : null,
          child: child,
        ),
      );
}
