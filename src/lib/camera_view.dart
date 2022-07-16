import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:ddcapp/google_map_page.dart';
import 'package:ddcapp/graph_page.dart';
import 'package:ddcapp/helpers/settings.dart';
import 'package:ddcapp/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as imageLib;

import 'helpers/isolate_utils.dart';
import 'main.dart';
import 'provider/location_provider.dart';

enum ScreenMode { liveFeed, gallery }

class CameraView extends StatefulWidget {
  const CameraView(
      {Key? key,
      required this.title,
      required this.customPaint,
      this.text,
      required this.onImage,
      this.initialDirection = CameraLensDirection.back})
      : super(key: key);

  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  ScreenMode _mode = ScreenMode.liveFeed;
  CameraController? _controller;
  File? _image;
  String? _path;
  ImagePicker? _imagePicker;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  bool _changingCameraLens = false;
  bool _recording = false;
  late IsolateUtils isolateUtils;

  @override
  void initState() {
    super.initState();

    isolateUtils = IsolateUtils();
    isolateUtils.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).initalization();
    });

    _imagePicker = ImagePicker();
    _cameraIndex = Settings.instance.chosenCamera.value;

    Settings.instance.chosenCamera.notifier.addListener(() {
      _cameraIndex = Settings.instance.chosenCamera.value;
      _stopLiveFeed();
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
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    return Stack(children: [
      Flex(direction: isHorizontal ? Axis.horizontal : Axis.vertical, children: [
        Expanded(
          flex: 7,
          child: Stack(
            fit: StackFit.loose,
            children: <Widget>[
              Center(
                child: _changingCameraLens
                    ? const Center(
                        child: Text('Changing camera lens'),
                      )
                    : CameraPreview(_controller!),
              ),
              if (widget.customPaint != null) widget.customPaint!,
            ],
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
            child: googleMapUI(
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
                _recording = !_recording;
              });
            },
          )),
      //placeholder
      const Expanded(flex: 2, child: Card())
    ];
  }

  Widget _portraitBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: _changingCameraLens
                  ? const Center(
                      child: Text('Changing camera lens'),
                    )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
        ],
      ),
    );
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
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
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _processCameraImage(CameraImage image) async {
    var uiThreadTimeStart = DateTime.now().millisecondsSinceEpoch;

    // Data to be passed to inference isolate
    var isolateData = IsolateData(image);

    // We could have simply used the compute method as well however
    // it would be as in-efficient as we need to continuously passing data
    // to another isolate.

    /// perform inference in separate isolate
    imageLib.Image inferenceResults = await inference(isolateData);

    var uiThreadInferenceElapsedTime = DateTime.now().millisecondsSinceEpoch - uiThreadTimeStart;

    //widget.onImage(inputImage);
  }

  /// Runs inference in another isolate
  Future<imageLib.Image> inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils.sendPort.send(isolateData..responsePort = responsePort.sendPort);
    var results = await responsePort.first;
    return results;
  }
}
