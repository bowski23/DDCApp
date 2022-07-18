import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../helpers/coordinates_translator.dart';
import '../yolo/stats.dart';

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this._objects, this.absoluteSize, this.stats);

  final List<DetectedObject> _objects;
  final Size absoluteSize;
  final Stats stats;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightGreenAccent;

    final Paint background = Paint()..color = Color(0x99000000);

    for (final DetectedObject detectedObject in _objects) {
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(textAlign: TextAlign.left, fontSize: 16, textDirection: TextDirection.ltr),
      );
      builder.pushStyle(ui.TextStyle(color: Colors.lightGreenAccent, background: background));

      for (final Label label in detectedObject.labels) {
        builder.addText('${label.text} ${label.confidence}\n');
      }

      builder.pop();

      // Convert Image (absoluteSize) coordinates to Painter (size) coordinates
      final left = detectedObject.boundingBox.left * (size.width/absoluteSize.width);
      final top = detectedObject.boundingBox.top * (size.height/absoluteSize.height);
      final right = detectedObject.boundingBox.right * (size.width/absoluteSize.width);
      final bottom = detectedObject.boundingBox.bottom * (size.height/absoluteSize.height);


      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      // draw information text
      final ParagraphBuilder builderT = ParagraphBuilder(
        ParagraphStyle(
          // textAlign: TextAlign.left,
            fontSize: 10,
            textDirection: TextDirection.ltr),
      );
      builderT.addText("totalPredTime: \n ${stats.totalPredictTime} ms\n\n"
          "inferenceTime: \n ${stats.inferenceTime} ms\n\n"
          "preProcTime: \n ${stats.preProcessingTime} ms");
      builderT.pushStyle(
          ui.TextStyle(color: Colors.lightGreenAccent, background: background));

      canvas.drawParagraph(
          builderT.build()
            ..layout(const ParagraphConstraints(width: double.infinity)),
          const Offset(0, 0));

      // canvas.drawParagraph(
      //   builder.build()
      //     ..layout(ParagraphConstraints(
      //       width: right - left,
      //     )),
      //   Offset(left, top),
      // );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
