import 'dart:io';

import 'package:cpu_reader/cpuinfo.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cpu_reader/cpu_reader.dart';
import 'package:path_provider/path_provider.dart';

class SensorHelper {
  late SensorData _latest;
  List<double> cpuTemps = [];
  List<List<int>> cpuFreqs = [];
  bool _isRecording = false;
  File? _file;
  int _start = 0;

  static const int maxTemps = 400;
  static const int maxFreqs = 200;

  SensorHelper._();

  factory SensorHelper() => _instance ??= SensorHelper._();

  static SensorHelper? _instance;

  static SensorData get latestData {
    return SensorHelper()._latest;
  }

  init() {
    Sensors().accelerometerEvents.listen((event) => _latest.accel = ThreeDimDataWrapper.fromAccelerometer(event));
    Sensors().magnetometerEvents.listen((event) => _latest.magnet = ThreeDimDataWrapper.fromMagnetometer(event));
    Sensors().gyroscopeEvents.listen((event) => _latest.gyro = ThreeDimDataWrapper.fromGyroscope(event));
    Battery().batteryLevel.asStream().listen((event) => _latest.batteryLevel = event);

    if (Platform.isAndroid) {
      CpuReader.cpuStream(50).listen((event) {
        _latest.cpuInfo = event;

        if (cpuTemps.length > maxTemps) cpuTemps.removeAt(0);
        cpuTemps.add(event.cpuTemperature ?? 0);

        for (int i = 0; i < cpuFreqs.length; i++) {
          var list = cpuFreqs[i];
          if (list.length > maxTemps) list.removeAt(0);
          list.add(event.currentFrequencies![i]!);
        }
      });
    }
  }

  static Future<void> ensureInitialized() async {
    var accel = await Sensors().accelerometerEvents.first;
    var magnet = await Sensors().magnetometerEvents.first;
    var gyro = await Sensors().gyroscopeEvents.first;
    var batterylevel = await Battery().batteryLevel;
    CpuInfo? cpuInfo;
    if (Platform.isAndroid) {
      cpuInfo = await CpuReader.cpuInfo;
      for (int i = 0; i < cpuInfo.numberOfCores!; i++) {
        SensorHelper().cpuFreqs.add([]);
      }
    }
    SensorHelper()._latest = SensorData(
        accel: ThreeDimDataWrapper.fromAccelerometer(accel),
        magnet: ThreeDimDataWrapper.fromMagnetometer(magnet),
        gyro: ThreeDimDataWrapper.fromGyroscope(gyro),
        batteryLevel: batterylevel,
        cpuInfo: cpuInfo);

    SensorHelper().init();
  }

  //filename withouth file type extension, all files are saved .csv
  //
  void startRecordingData(String filename, {bool automatic = false, int intervall = 33}) async {
    if (_isRecording) throw const FileSystemException("SensorData is already being recorded");
    var dir = await (Platform.isAndroid ? getExternalStorageDirectory() : getApplicationDocumentsDirectory());
    dir ??= await getApplicationDocumentsDirectory();
    _file = File("${dir.path}/$filename.csv");
    if (kDebugMode) {
      print("${dir.path}/$filename");
    }
    await _file!.writeAsString(_latest.csvHeader, mode: FileMode.append);
    _isRecording = true;
    _start = DateTime.now().millisecondsSinceEpoch;
    if (automatic) {
      _recordNext(intervall);
    }
  }

  //call for each frame you want to record, it's a noop if the recording hasn't been started or it is stopped
  //timestamp can be used also as sequential frame number
  Future<void> recordStep(int timestamp) async {
    if (!_isRecording || _file == null) return;
    await _file!.writeAsString(_latest.stringWithTimestamp(timestamp), mode: FileMode.append);
  }

  //delay in ms
  void _recordNext(int delay) async {
    if (!_isRecording) return;
    await recordStep(DateTime.now().millisecondsSinceEpoch - _start);
    Future.delayed(Duration(milliseconds: delay), () => _recordNext(delay));
  }

  File stopRecordingData() {
    if (!_isRecording || _file == null) throw Exception("Recording has to be started to end it!");
    _isRecording = false;
    var temp = _file!;
    _file = null;
    return temp;
  }
}

class SensorData {
  ThreeDimDataWrapper accel;
  ThreeDimDataWrapper magnet;
  ThreeDimDataWrapper gyro;
  int batteryLevel;
  CpuInfo? cpuInfo;

  SensorData({required this.accel, required this.magnet, required this.gyro, required this.batteryLevel, this.cpuInfo});

  @override
  String toString() {
    String cpu = "";
    if (cpuInfo != null) {
      cpu += ", ${cpuInfo!.cpuTemperature}";
      if (cpuInfo!.numberOfCores != null) {
        for (int i = 0; i < cpuInfo!.numberOfCores!; i++) {
          cpu +=
              ", ${cpuInfo!.currentFrequencies![i]}, ${cpuInfo!.minMaxFrequencies![i]!.max}, ${cpuInfo!.minMaxFrequencies![i]!.min}";
        }
      }
    }
    return "${DateTime.now().toUtc().millisecondsSinceEpoch}, $accel, $magnet, $gyro,$batteryLevel,$cpu";
  }

  String stringWithTimestamp(int timestamp) {
    String cpu = "";
    if (cpuInfo != null) {
      cpu += ", ${cpuInfo!.cpuTemperature}";
      if (cpuInfo!.numberOfCores != null) {
        for (int i = 0; i < cpuInfo!.numberOfCores!; i++) {
          cpu +=
              ", ${cpuInfo!.currentFrequencies![i]}, ${cpuInfo!.minMaxFrequencies![i]!.max}, ${cpuInfo!.minMaxFrequencies![i]!.min}";
        }
      }
    }
    return "$timestamp, $accel, $magnet, $gyro,$batteryLevel,$cpu\n";
  }

  String get csvHeader {
    String cpu = "";
    if (cpuInfo != null) {
      cpu += ", cpuTemp";
      if (cpuInfo!.numberOfCores != null) {
        for (int i = 0; i < cpuInfo!.numberOfCores!; i++) {
          cpu += ", cpu${i}_freq, cpu${i}_max_freq, cpu${i}_min_freq";
        }
      }
    }
    return "timestamp, accel_x, accel_y, accel_z, magnet_x, magnet_y, magnet_z, gyro_x, gyro_y, gyro_z, battery_level$cpu\n";
  }
}

class ThreeDimDataWrapper {
  double x, y, z;

  ThreeDimDataWrapper(this.x, this.y, this.z);
  ThreeDimDataWrapper.fromAccelerometer(AccelerometerEvent e)
      : x = e.x,
        y = e.y,
        z = e.z;
  ThreeDimDataWrapper.fromMagnetometer(MagnetometerEvent e)
      : x = e.x,
        y = e.y,
        z = e.z;
  ThreeDimDataWrapper.fromGyroscope(GyroscopeEvent e)
      : x = e.x,
        y = e.y,
        z = e.z;

  @override
  String toString() {
    return "$x, $y, $z";
  }
}
