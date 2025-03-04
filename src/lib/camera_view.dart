import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:ddcapp/google_map_page.dart';
import 'package:ddcapp/graph_page.dart';
import 'package:ddcapp/helpers/sensor_singelton.dart';
import 'package:ddcapp/helpers/settings.dart';
import 'package:ddcapp/painters/object_detector_painter.dart';
import 'package:ddcapp/settings_page.dart';

import 'package:ddcapp/yolo/classifier_yolov4.dart';
import 'package:ddcapp/yolo/recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';
import 'dart:ui' as ui;

import 'helpers/isolate_utils.dart';
import 'main.dart';
import 'provider/location_provider.dart';

enum ScreenMode { liveFeed, gallery }

class CameraView extends StatefulWidget {
  const CameraView({Key? key, required this.title, this.text, this.initialDirection = CameraLensDirection.back})
      : super(key: key);

  final String title;

  final String? text;
  final CameraLensDirection initialDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  bool _recording = false;
  String _filename = "";
  late IsolateUtils isolateUtils;

  late Classifier classifier;
  bool predicting = false;
  CustomPaint? customPaint;
  late bool isStreaming = false;
  bool _isHorizontal = false;

  @override
  void initState() {
    super.initState();

    classifier = Classifier();

    isolateUtils = IsolateUtils();
    isolateUtils.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).initalization();
    });

    _cameraIndex = Settings.instance.chosenCamera.value;

    Settings.instance.chosenCamera.notifier.addListener(() async {
      _cameraIndex = Settings.instance.chosenCamera.value;
      await _stopLiveFeed();
      _startLiveFeed();
    });

    Settings.instance.useMachineLearning.notifier.addListener(() async {
      await _stopLiveFeed();
      _startLiveFeed();
    });

    _startLiveFeed();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return _body(context, isHorizontal: false);
        } else {
          return _body(context, isHorizontal: true);
        }
      }),
    );
  }

  Widget _body(BuildContext context, {bool isHorizontal = true}) {
    _isHorizontal = isHorizontal;
    if (_controller == null || _controller!.value.isInitialized == false) {
      return Container();
    }
    double aspectRatio = Settings.instance.useMachineLearning.value ? 3.0 / 2.0 : 16.0 / 9.0;
    if (!isHorizontal) {
      aspectRatio = 1 / aspectRatio;
    }

    return Stack(children: [
      Flex(direction: isHorizontal ? Axis.horizontal : Axis.vertical, children: [
        Expanded(
          flex: 7,
          child: Center(
            child: Stack(
              fit: StackFit.loose,
              children: <Widget>[
                AspectRatio(aspectRatio: aspectRatio, child: CameraPreview(_controller!)),
                // AspectRatio is there so the size variable of the painter gets set correctly,
                // it has nothing to do with AspectRation itself, should be improved
                if (customPaint != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: customPaint!,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Flex(
            direction: !isHorizontal ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: isHorizontal ? _menuItems(context) : _menuItems(context).reversed.toList(),
          ),
        )
      ]),
      Align(
        alignment: isHorizontal ? Alignment.bottomRight : Alignment.bottomLeft,
        child: FractionallySizedBox(
          widthFactor: isHorizontal ? 0.33 : 0.4,
          heightFactor: isHorizontal ? 0.4 : 0.33,
          child: Card(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            clipBehavior: Clip.hardEdge,
            child: googleMapUI(context,
                control: false,
                onTap: (lat) =>
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const GoogleMapPage()))),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _menuItems(BuildContext context) {
    return [
      Expanded(
          flex: 1,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.settings_outlined),
            color: Colors.white,
            iconSize: 30,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          )),
      Expanded(
          flex: 1,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.stacked_line_chart_outlined),
            color: Colors.white,
            iconSize: 30,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GraphPage())),
          )),
      Expanded(
          flex: 1,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 60,
            icon: Stack(children: [
              const Center(child: Icon(Icons.circle_outlined, size: 60)),
              Center(
                child: Icon(
                  Icons.circle,
                  size: 40,
                  color: _recording ? Colors.red : Colors.grey,
                ),
              )
            ]),
            color: Colors.white,
            onPressed: () {
              setState(() {
                toggleRecording();
              });
            },
          )),
      //placeholder
      const Expanded(flex: 2, child: Card())
    ];
  }

  void toggleRecording() {
    if (_controller == null) return;
    if (_recording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  void stopRecording() {
    var filename = _filename;
    if (!Settings.instance.useMachineLearning.value) {
      _controller!.stopVideoRecording().then((vid) {
        var dir = Platform.isAndroid ? getExternalStorageDirectory() : getApplicationDocumentsDirectory();
        dir.then((dir) async {
          dir ??= await getApplicationDocumentsDirectory();
          if (kDebugMode) {
            print("${dir.path}/$filename");
          }
          return vid.saveTo("${dir.path}/$filename.mp4");
        });
      });
    }
    SensorHelper().stopRecordingData();
    _recording = false;
  }

  void startRecording() {
    _filename = DateTime.now().toIso8601String();
    if (!Settings.instance.useMachineLearning.value) {
      _controller!.startVideoRecording();
      SensorHelper().startRecordingData(_filename, automatic: true);
    } else {
      SensorHelper().startRecordingData(_filename, automatic: false);
    }
    _recording = true;
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      Settings.instance.useMachineLearning.value ? ResolutionPreset.medium : ResolutionPreset.max,
      enableAudio: false,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller!.prepareForVideoRecording();
      if (Settings.instance.useMachineLearning.value) {
        _controller?.startImageStream(_processCameraImage);
        isStreaming = true;
      }
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    if (_controller == null) return;
    if (isStreaming) {
      await _controller?.stopImageStream();
      isStreaming = false;
    }
    if (_recording) {
      await _controller?.stopVideoRecording();
    }
    await _controller?.dispose();
    _controller = null;
    customPaint = null;
  }

  Future _processCameraImage(CameraImage inputImage) async {
    if (_controller == null || !Settings.instance.useMachineLearning.value) return;

    // ignore: unnecessary_null_comparison
    if (isolateUtils.sendPort == null) {
      return;
    }

    if (classifier.interpreter != null && classifier.labels != null) {
      // If previous inference has not completed then return
      if (predicting) {
        return;
      }
      setState(() {
        predicting = true;
      });

      // Data to be passed to inference isolate
      //TODO: adjust orientation
      var isolateData = IsolateData(
          inputImage, classifier.interpreter!.address, classifier.labels!, cameras[_cameraIndex].sensorOrientation);

      // perform inference in separate isolate
      Map<String, dynamic> rawResults = await inference(isolateData);

      // The received objects locations have a weird shape: not LTRB but TLBR,
      // also the horizontal axis is reversed
      List<DetectedObject> processedObjects = [];

      if (rawResults['recognitions'] != null) {
        List<Recognition> recognitions = rawResults['recognitions'];
        for (Recognition recognition in recognitions) {
          Rect loc = recognition.location;
          processedObjects.add(DetectedObject(
              // For explanation see comments above
              boundingBox: Rect.fromLTRB(
                  (loc.top - inputImage.width).abs(), loc.left, (loc.bottom - inputImage.width).abs(), loc.right),
              labels: [Label(confidence: 99, index: 2, text: "something")],
              trackingId: 0));
        }

        final painter = ObjectDetectorPainter(
            processedObjects, ui.Size(inputImage.width * 1.0, inputImage.height * 1.0), rawResults['stats']);

        customPaint = CustomPaint(painter: painter);
      }
    }

    setState(() {
      predicting = false;
    });
  }

  /// Runs inference in another isolate
  Future<Map<String, dynamic>> inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils.sendPort.send(isolateData..responsePort = responsePort.sendPort);

    var results = await responsePort.first;
    return results;
  }
}
