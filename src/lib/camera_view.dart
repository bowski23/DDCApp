import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ddcapp/google_map_page.dart';
import 'package:ddcapp/graph_page.dart';
import 'package:ddcapp/helpers/settings.dart';
import 'package:ddcapp/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';

enum ScreenMode { liveFeed, gallery }

class CameraView extends StatefulWidget {
  CameraView(
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
  final bool _allowPicker = true;
  bool _changingCameraLens = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();

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
          return _portraitBody();
        } else {
          return _landscapeBody(context);
        }
      }),
    );
  }

  Widget? _floatingActionButton() {
    if (_mode == ScreenMode.gallery) return null;
    if (cameras.length == 1) return null;
    return SizedBox(
        height: 70.0,
        width: 70.0,
        child: FloatingActionButton(
          onPressed: _switchLiveCamera,
          child: Icon(
            Platform.isIOS ? Icons.flip_camera_ios_outlined : Icons.flip_camera_android_outlined,
            size: 40,
          ),
        ));
  }

  Widget _landscapeBody(BuildContext context) {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    return Row(children: [
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: _menuItems(context),
        ),
      )
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
      Expanded(
        flex: 2,
        child: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoogleMapPage())),
          child: const Card(
            child: Text("Really Big Map that flows over the camera screen"),
          ),
        ),
      )
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
                  ? Center(
                      child: const Text('Changing camera lens'),
                    )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
        ],
      ),
    );
  }

  Future _getImage(ImageSource source) async {
    setState(() {
      _image = null;
      _path = null;
    });
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processPickedFile(pickedFile);
    }
    setState(() {});
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
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

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  Future _processPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      return;
    }
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    widget.onImage(inputImage);
  }

  Future _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final camera = cameras[_cameraIndex];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    widget.onImage(inputImage);
  }
}
