import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  final Battery _battery = Battery();
  final Sensors _sensors = Sensors();
  MagnetometerEvent _magnetState = MagnetometerEvent(0, 0, 0);
  AccelerometerEvent _accelState = AccelerometerEvent(0, 0, 0);
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  initState() {
    super.initState();
    _streamSubscriptions.add(_sensors.magnetometerEvents.listen((event) {
      setState(() {
        _magnetState = event;
      });
    }));

    _streamSubscriptions.add(_sensors.accelerometerEvents.listen((event) {
      setState(() {
        _accelState = event;
        print("anything");
      });
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Graphs")),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Battery:",
            textScaleFactor: 1.5,
          ),
          FutureBuilder(
            builder: ((context, AsyncSnapshot<BatteryState> snapshot) =>
                Text("Battery state: " + snapshot.data.toString())),
            future: _battery.batteryState,
          ),
          FutureBuilder(
            builder: ((context, AsyncSnapshot<int> snapshot) => Text("Battery level: " + snapshot.data.toString())),
            future: _battery.batteryLevel,
          ),
          const Text(
            "Sensors:",
            textScaleFactor: 1.5,
          ),
          Text("Magnetometer: ${_magnetState.x}, ${_magnetState.y}, ${_magnetState.z}"),
          Text("Accelerometer: ${_accelState.x}, ${_accelState.y}, ${_accelState.z}"),
        ]));
  }
}
