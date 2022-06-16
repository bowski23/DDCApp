import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  final Battery _battery = Battery();
  final Sensors _sensors = Sensors();

  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  initState() {
    super.initState();
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
            builder: ((context, AsyncSnapshot<BatteryState> snapshot) => Text("Battery state: ${snapshot.data?.name}")),
            future: _battery.batteryState,
          ),
          FutureBuilder(
            builder: ((context, AsyncSnapshot<int> snapshot) => Text("Battery level: ${snapshot.data}")),
            future: _battery.batteryLevel,
          ),
          const Text(
            "Sensors:",
            textScaleFactor: 1.5,
          ),
          StreamBuilder(
              builder: ((context, AsyncSnapshot<MagnetometerEvent> snapshot) =>
                  Text("Magnetometer: ${snapshot.data?.x}, ${snapshot.data?.y}, ${snapshot.data?.z}")),
              stream: _sensors.magnetometerEvents),
          StreamBuilder(
              builder: ((context, AsyncSnapshot<AccelerometerEvent> snapshot) =>
                  Text("AccelerometerEvents: ${snapshot.data?.x}, ${snapshot.data?.y}, ${snapshot.data?.z}")),
              stream: _sensors.accelerometerEvents),
          Row(
            children: [],
          )
        ]));
  }
}
