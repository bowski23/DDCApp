import 'dart:io';

import 'package:cpu_reader/cpuinfo.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cpu_reader/cpu_reader.dart';

class SensorHelper {
  late SensorData _latest;

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
      CpuReader.cpuStream(16).listen((event) => _latest.cpuInfo = event);
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
    }
    SensorHelper()._latest = SensorData(
        accel: ThreeDimDataWrapper.fromAccelerometer(accel),
        magnet: ThreeDimDataWrapper.fromMagnetometer(magnet),
        gyro: ThreeDimDataWrapper.fromGyroscope(gyro),
        batteryLevel: batterylevel,
        cpuInfo: cpuInfo);
    SensorHelper().init();
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
    return "$accel, $magnet, $gyro,$batteryLevel,$cpu";
  }

  String get header {
    String cpu = "";
    if (cpuInfo != null) {
      cpu += ", cpuTemp";
      if (cpuInfo!.numberOfCores != null) {
        for (int i = 0; i < cpuInfo!.numberOfCores!; i++) {
          cpu += ", cpu${i}_freq, cpu${i}_max_freq, cpu${i}_min_freq";
        }
      }
    }
    return "accel_x, accel_y, accel_z, magnet_x, magnet_y, magnet_z, gyro_x, gyro_y, gyro_z, battery_level$cpu";
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
