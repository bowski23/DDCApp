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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Graphs")),
        body: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [
          Expanded(
            flex: 1,
            child: Column(children: _texts()),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: _charts(),
            ),
          )
        ]));
  }

  @override
  void dispose() {
    for (var element in _streamSubscriptions) {
      element.cancel();
    }
    super.dispose();
  }

  List<Widget> _charts() {
    return [
      SizedBox(
        width: 300,
        height: 300,
        child: ThreeDimDataLineChart(eventStream: accelerometerEvents),
      )
    ];
  }

  List<Widget> _texts() {
    return [
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
    ];
  }
}

class ThreeDimDataLineChart extends StatefulWidget {
  final Stream eventStream;

  const ThreeDimDataLineChart({Key? key, required this.eventStream}) : super(key: key);

  @override
  State<ThreeDimDataLineChart> createState() => _ThreeDimDataLineChartState();
}

class _ThreeDimDataLineChartState extends State<ThreeDimDataLineChart> {
  List<_EventWrapper> data = [];
  Series<_EventWrapper, DateTime>? displayedX;
  Series<_EventWrapper, DateTime>? displayedY;
  Series<_EventWrapper, DateTime>? displayedZ;
  StreamSubscription? _subscription;

  Timer? periodicUpdater;

  static const int dataPointLimit = 200;

  _ThreeDimDataLineChartState();

  @override
  initState() {
    super.initState();

    displayedX =
        Series(id: "x", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.x);
    displayedY =
        Series(id: "y", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.y);
    displayedZ =
        Series(id: "z", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.z);

    _subscription = widget.eventStream.listen(
      (event) => updateData(event),
    );

    //update every 16ms so that we get ~60 fps
    periodicUpdater = Timer.periodic(const Duration(milliseconds: 16), (timer) => setState(() {}));
  }

  updateData(event) {
    if (data.length > dataPointLimit) data.removeAt(0);

    data.add(_EventWrapper(event, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    if (displayedX == null || displayedY == null || displayedZ == null) {
      return const Text("loading");
    }
    return TimeSeriesChart(
      [displayedX!, displayedY!, displayedZ!],
      animate: false,
    );
  }

  @override
  void dispose() {
    if (periodicUpdater != null) {
      periodicUpdater!.cancel();
    }
    if (_subscription != null) {
      _subscription!.cancel();
    }
    super.dispose();
  }
}

class _EventWrapper<T> {
  T event;
  DateTime time;

  _EventWrapper(this.event, this.time);

  double get x => (event as AccelerometerEvent).x;

  double get y => (event as AccelerometerEvent).y;

  double get z => (event as AccelerometerEvent).z;
}
