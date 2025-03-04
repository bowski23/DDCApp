import 'dart:ffi';
import 'package:ddcapp/yolo/classifier_yolov4.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imagelib;
import 'package:tflite_flutter/tflite_flutter.dart';

typedef ConvertFunc = Pointer<Uint32> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef Convert = Pointer<Uint32> Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String debugName = "InferenceIsolate";

  // ignore: unused_field
  late Isolate _isolate;
  final ReceivePort _receivePort = ReceivePort();
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  static final DynamicLibrary convertImageLib =
      Platform.isAndroid ? DynamicLibrary.open("libconvertImage.so") : DynamicLibrary.process();

  static Convert? _conv;
  static Convert get conv {
    _conv ??= convertImageLib.lookup<NativeFunction<ConvertFunc>>('convertImage').asFunction<Convert>();
    return _conv!;
  }

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: debugName,
    );
    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();

    sendPort.send(port.sendPort);

    await for (final IsolateData isolateData in port) {
      Classifier classifier =
          Classifier(interpreter: Interpreter.fromAddress(isolateData.interpreterAddress), labels: isolateData.labels);
      //imageLib.Image image =
      //   ImageUtils.convertImagetoPng(isolateData.cameraImage);
      imagelib.Image image;
      if (Platform.isAndroid) {
        // Allocate memory for the 3 planes of the image
        Pointer<Uint8> p = ffi.calloc.allocate(isolateData.cameraImage.planes[0].bytes.length);
        Pointer<Uint8> p1 = ffi.calloc.allocate(isolateData.cameraImage.planes[1].bytes.length);
        Pointer<Uint8> p2 = ffi.calloc.allocate(isolateData.cameraImage.planes[2].bytes.length);

        // Assign the planes data to the pointers of the image
        Uint8List pointerList = p.asTypedList(isolateData.cameraImage.planes[0].bytes.length);
        Uint8List pointerList1 = p1.asTypedList(isolateData.cameraImage.planes[1].bytes.length);
        Uint8List pointerList2 = p2.asTypedList(isolateData.cameraImage.planes[2].bytes.length);
        pointerList.setRange(
            0, isolateData.cameraImage.planes[0].bytes.length, isolateData.cameraImage.planes[0].bytes);
        pointerList1.setRange(
            0, isolateData.cameraImage.planes[1].bytes.length, isolateData.cameraImage.planes[1].bytes);
        pointerList2.setRange(
            0, isolateData.cameraImage.planes[2].bytes.length, isolateData.cameraImage.planes[2].bytes);

        // Call the convertImage function and convert the YUV to RGB
        Pointer<Uint32> imgP = conv(
            p,
            p1,
            p2,
            isolateData.cameraImage.planes[1].bytesPerRow,
            isolateData.cameraImage.planes[1].bytesPerPixel!,
            isolateData.cameraImage.planes[0].bytesPerRow,
            isolateData.cameraImage.height);

        // Get the pointer of the data returned from the function to a List
        List<int> imgData =
            imgP.asTypedList((isolateData.cameraImage.planes[0].bytesPerRow * isolateData.cameraImage.height));
        // Generate image from the converted data
        image = imagelib.Image.fromBytes(isolateData.cameraImage.height, isolateData.cameraImage.width, imgData);

        // Free the memory space allocated
        // from the planes and the converted data
        ffi.calloc.free(p);
        ffi.calloc.free(p1);
        ffi.calloc.free(p2);
        ffi.calloc.free(imgP);
      } else {
        image = imagelib.Image.fromBytes(
          isolateData.cameraImage.planes[0].bytesPerRow,
          isolateData.cameraImage.height,
          isolateData.cameraImage.planes[0].bytes,
          format: imagelib.Format.bgra,
        );
      }
      Map<String, dynamic> results = classifier.predict(image, isolateData.imageRotation);

      isolateData.responsePort.send(results);
    }
  }
}

/// Bundles data to pass between Isolate
class IsolateData {
  CameraImage cameraImage;
  late SendPort responsePort;
  int interpreterAddress;
  List<String> labels;
  int imageRotation;

  IsolateData(this.cameraImage, this.interpreterAddress, this.labels, this.imageRotation);
}
