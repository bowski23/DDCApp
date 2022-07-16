import 'dart:io' as io;

import 'package:camera/camera.dart';
import 'package:ddcapp/helpers/settings.dart';
import 'package:ddcapp/yolo/classifierYolov4.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_view.dart';
import 'painters/object_detector_painter.dart';
import 'settings_page.dart';
import 'package:image/image.dart' as imagelib;

class ObjectDetectorView extends StatefulWidget {
  @override
  _ObjectDetectorView createState() => _ObjectDetectorView();
}

class _ObjectDetectorView extends State<ObjectDetectorView> {
  // late ObjectDetector _objectDetector;
  late Classifier _classifier;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  @override
  void initState() {
    super.initState();

    _initializeDetector();
  }

  @override
  void dispose() {
    _canProcess = false;
    // _objectDetector.close();
    // TODO: check if we need to destroy Isolate
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraView(
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      title: 'DashCam Home',
      customPaint: _customPaint,
      text: _text,
      onImage: (inputImage) {
        processImage(inputImage);
      },
      initialDirection: CameraLensDirection.back,
    );
  }

  void _initializeDetector() async {
    // uncomment next lines if you want to use the default model
    // final options =
    //     ObjectDetectorOptions(classifyObjects: true, multipleObjects: true);
    // _objectDetector = ObjectDetector(options: options);

    // uncomment next lines if you want to use a local model
    // make sure to add tflite model to assets/ml
    // final path = 'assets/ml/object_labeler.tflite';
    // final modelPath = await _getModel(path);
    // final options = LocalObjectDetectorOptions(
    //     modelPath: modelPath, classifyObjects: true, multipleObjects: true, mode: DetectionMode.stream);
    // _objectDetector = ObjectDetector(options: options);


    _classifier = Classifier();




    // uncomment next lines if you want to use a remote model
    // make sure to add model to firebase
    // final modelName = 'bird-classifier';
    // final response =
    //     await FirebaseObjectDetectorModelManager().downloadModel(modelName);
    // print('Downloaded: $response');
    // final options = FirebaseObjectDetectorOptions(
    //   modelName: modelName,
    //   classifyObjects: true,
    //   multipleObjects: true,
    // );
    // _objectDetector = ObjectDetector(options: options);

    _canProcess = true;
  }

  Future<void> processImage(imagelib.Image inputImage) async {
    if (!_canProcess) return;
    if (!Settings.instance.useMachineLearning.value) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });



    Map<String, dynamic> results = _classifier.predict(inputImage);
    print('furkan');
    print(results);







    // final objects = await _objectDetector.processImage(inputImage);
    // if (inputImage.inputImageData?.size != null && inputImage.inputImageData?.imageRotation != null) {
    //   final painter =
    //       ObjectDetectorPainter(objects, inputImage.inputImageData!.imageRotation, inputImage.inputImageData!.size);
    //   _customPaint = CustomPaint(painter: painter);
    // } else {
    //   String text = 'Objects found: ${objects.length}\n\n';
    //   for (final object in objects) {
    //     text += 'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
    //   }
    //   _text = text;
    //   // TODO: set _customPaint to draw boundingRect on top of image
    //   _customPaint = null;
    // }




    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getModel(String assetPath) async {
    if (io.Platform.isAndroid) {
      return 'flutter_assets/$assetPath';
    }
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }
}
