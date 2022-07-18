import 'dart:math';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:ddcapp/yolo/recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import 'stats.dart';

/// Classifier
class Classifier {
  /// Instance of Interpreter
  Interpreter? _interpreter;

  //Interpreter Options (Settings)
  final int numThreads = 4;
  final bool isNNAPI = false;
  final bool isGPU = true;

  /// Labels file loaded as list
  List<String>? _labels;
  static const String modelFileName = "yolov4-rebite-fp16.tflite";
  static const String labelFileName = "obj.txt";

  /// Input size of image (heixght = width = 300)
  static const int inputSize = 416;

  /// Confidence Probabilty score threshold
  static const double threshold = 0.5;

  /// Non-maximum suppression threshold
  static double mNmsThresh = 0.6;

  /// [ImageProcessor] used to pre-process the image
  ImageProcessor? imageProcessor;

  /// Padding the image to transform into square
  int? padSize;

  /// Shapes of output tensors
  List<List<int>>? _outputShapes;

  /// Types of output tensors
  List<TfLiteType>? _outputTypes;

  /// Number of results to show
  static const int numResults = 10;

  Classifier({
    Interpreter? interpreter,
    List<String>? labels,
  }) {
    loadModel(interpreter: interpreter);
    loadLabels(labels: labels);
  }

  /// Loads interpreter from asset
  void loadModel({Interpreter? interpreter}) async {
    try {
      //Still working on it
      /*InterpreterOptions myOptions = new InterpreterOptions();
      myOptions.threads = numThreads;
      if (isNNAPI) {
        NnApiDelegate nnApiDelegate;
        bool androidApiThresholdMet = true;
        if (androidApiThresholdMet) {
          nnApiDelegate = new NnApiDelegate();
          myOptions.addDelegate(nnApiDelegate);
          myOptions.useNnApiForAndroid = true;
        }
      }
      if (isGPU) {
        GpuDelegateV2 gpuDelegateV2 = new GpuDelegateV2();
        myOptions.addDelegate(gpuDelegateV2);
      }*/

      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            modelFileName,
            options: InterpreterOptions()..threads = numThreads, //myOptions,
          );

      // WidgetsFlutterBinding.ensureInitialized();

      var outputTensors = _interpreter!.getOutputTensors();
      //print("the length of the ouput Tensors is ${outputTensors.length}");
      _outputShapes = [];
      _outputTypes = [];
      for (var tensor in outputTensors) {
        //print(tensor.toString());
        _outputShapes!.add(tensor.shape);
        _outputTypes!.add(tensor.type);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error while creating interpreter: $e");
      }
    }
  }

  /// Loads labels from assets
  void loadLabels({List<String>? labels}) async {
    try {
      _labels = labels ?? await FileUtil.loadLabels("assets/$labelFileName");
    } catch (e) {
      if (kDebugMode) {
        print("Error while loading labels: $e");
      }
    }
  }

  /// Pre-process the image
  /// Only does something to the image if it doesn't meet the specified input sizes.
  TensorImage getProcessedImage(TensorImage inputImage, int imageRotation) {
    padSize = max(inputImage.height, inputImage.width);
    imageProcessor ??= ImageProcessorBuilder()
        .add(Rot90Op(3))
        .add(ResizeWithCropOrPadOp(padSize!, padSize!))
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255))
        .build();
    inputImage = imageProcessor!.process(inputImage);
    return inputImage;
  }

  // non-maximum suppression
  List<Recognition> nms(List<Recognition> list) // Turned from Java's ArrayList to Dart's List.
  {
    List<Recognition> nmsList = [];

    if (_labels == null) {
      return [];
    }

    for (int k = 0; k < _labels!.length; k++) {
      // 1.find max confidence per class
      PriorityQueue<Recognition> pq = HeapPriorityQueue<Recognition>();
      for (int i = 0; i < list.length; ++i) {
        if (list[i].label == _labels![k]) {
          // Changed from comparing #th class to class to string to string
          pq.add(list[i]);
        }
      }

      // 2.do non maximum suppression
      while (pq.length > 0) {
        // insert detection with max confidence
        List<Recognition> detections = pq.toList(); //In Java: pq.toArray(a)
        Recognition max = detections[0];
        nmsList.add(max);
        pq.clear();
        for (int j = 1; j < detections.length; j++) {
          Recognition detection = detections[j];
          Rect b = detection.location;
          if (boxIou(max.location, b) < mNmsThresh) {
            pq.add(detection);
          }
        }
      }
    }

    return nmsList;
  }

  double boxIou(Rect a, Rect b) {
    return boxIntersection(a, b) / boxUnion(a, b);
  }

  double boxIntersection(Rect a, Rect b) {
    double w = overlap((a.left + a.right) / 2, a.right - a.left, (b.left + b.right) / 2, b.right - b.left);
    double h = overlap((a.top + a.bottom) / 2, a.bottom - a.top, (b.top + b.bottom) / 2, b.bottom - b.top);
    if ((w < 0) || (h < 0)) {
      return 0;
    }
    double area = (w * h);
    return area;
  }

  double boxUnion(Rect a, Rect b) {
    double i = boxIntersection(a, b);
    double u = ((((a.right - a.left) * (a.bottom - a.top)) + ((b.right - b.left) * (b.bottom - b.top))) - i);
    return u;
  }

  double overlap(double x1, double w1, double x2, double w2) {
    double l1 = (x1 - (w1 / 2));
    double l2 = (x2 - (w2 / 2));
    double left = ((l1 > l2) ? l1 : l2);
    double r1 = (x1 + (w1 / 2));
    double r2 = (x2 + (w2 / 2));
    double right = ((r1 < r2) ? r1 : r2);
    return right - left;
  }

  /// Runs object detection on the input image
  Map<String, dynamic> predict(image_lib.Image image, int imageRotation) {
    var predictStartTime = DateTime.now().millisecondsSinceEpoch;

    if (_interpreter == null || _outputShapes == null || _labels == null) {
      if (kDebugMode) {
        if (_interpreter == null) {
          print('_interpreter == null');
        }
        if (_outputShapes == null) {
          print('_outputShapes == null');
        }
        if (_labels == null) {
          print('_labels == null');
        }
      }
      return {
        "recognitions": [],
        "stats": Stats(totalPredictTime: 0, inferenceTime: 0, preProcessingTime: 0, totalElapsedTime: 0)
      };
    }
    var preProcessStart = DateTime.now().millisecondsSinceEpoch;

    // Initliazing TensorImage as the needed model input type
    // of TfLiteType.float32. Then, creating TensorImage from image
    TensorImage inputImage = TensorImage(TfLiteType.float32);
    inputImage.loadImage(image);
    TensorImage original = TensorImage(TfLiteType.float32);
    original.loadImage(image);
    // Do not use static methods, fromImage(Image) or fromFile(File),
    // of TensorImage unless the desired input TfLiteDataType is Uint8.
    // Create TensorImage from image
    //TensorImage inputImage = TensorImage.fromImage(image);

    // Pre-process TensorImage
    inputImage = getProcessedImage(inputImage, imageRotation);
    //getProcessedImage(inputImage);

    var preProcessElapsedTime = DateTime.now().millisecondsSinceEpoch - preProcessStart;

    // TensorBuffers for output tensors
    TensorBuffer outputLocations = TensorBufferFloat(_outputShapes![0]); // The location of each detected object

    List<List<List<double>>> outputClassScores = List.generate(_outputShapes![1][0],
        (_) => List.generate(_outputShapes![1][1], (_) => List.filled(_outputShapes![1][2], 0.0), growable: false),
        growable: false);

    // Inputs object for runForMultipleInputs
    // Use [TensorImage.buffer] or [TensorBuffer.buffer] to pass by reference
    List<Object> inputs = [inputImage.buffer];

    // Outputs map
    Map<int, Object> outputs = {
      0: outputLocations.buffer,
      1: outputClassScores,
    };

    var inferenceTimeStart = DateTime.now().millisecondsSinceEpoch;

    // run inference
    _interpreter!.runForMultipleInputs(inputs, outputs);

    var inferenceTimeElapsed = DateTime.now().millisecondsSinceEpoch - inferenceTimeStart;

    // Using bounding box utils for easy conversion of tensorbuffer to List<Rect>
    List<Rect> locations = BoundingBoxUtils.convert(
      tensor: outputLocations,
      // valueIndex: [1, 0, 3, 2], //Commented out because default order is needed.
      boundingBoxAxis: 2,
      boundingBoxType: BoundingBoxType.CENTER,
      coordinateType: CoordinateType.PIXEL,
      height: inputSize,
      width: inputSize,
    );

    //print(locations.length);

    List<Recognition> recognitions = [];

    var gridWidth = _outputShapes![0][1];
    //print("gridWidth = $gridWidth");

    for (int i = 0; i < gridWidth; i++) {
      // Since we are given a list of scores for each class for
      // each detected Object, we are interested in finding the class
      // with the highest output score

      var maxClassScore = 0.00;
      var labelIndex = -1;

      for (int c = 0; c < _labels!.length; c++) {
        // output[0][i][c] is the confidence score of c class
        if (outputClassScores[0][i][c] > maxClassScore) {
          labelIndex = c;
          maxClassScore = outputClassScores[0][i][c];
        }
      }
      // Prediction score
      var score = maxClassScore;

      String label;
      if (labelIndex != -1) {
        // Label string
        label = _labels!.elementAt(labelIndex);
      } else {
        label = "";
      }
      // Makes sure the confidence is above the
      // minimum threshold score for each object.
      if (score > threshold) {
        // inverse of rect
        // [locations] corresponds to the image size 300 X 300
        // inverseTransformRect transforms it our [inputImage]

        Rect rectAti = Rect.fromLTRB(max(0, locations[i].left), max(0, locations[i].top),
            min(inputSize + 0.0, locations[i].right), min(inputSize + 0.0, locations[i].bottom));

        // Gets the coordinates based on the original image if anything was done to it.
        Rect transformedRect = imageProcessor!.inverseTransformRect(rectAti, image.height, image.width);

        recognitions.add(
          Recognition(i, label, score, transformedRect),
        );
      }
    } // End of for loop and added all recognitions
    List<Recognition> recognitionsNMS = nms(recognitions);
    var predictElapsedTime = DateTime.now().millisecondsSinceEpoch - predictStartTime;

    var temp = {
      "recognitions": recognitionsNMS,
      "stats": Stats(
          totalPredictTime: predictElapsedTime,
          inferenceTime: inferenceTimeElapsed,
          preProcessingTime: preProcessElapsedTime,
          totalElapsedTime: 0)
    };

    return temp;
  }

  /// Gets the interpreter instance
  Interpreter? get interpreter => _interpreter;

  /// Gets the loaded labels
  List<String>? get labels => _labels;
}
