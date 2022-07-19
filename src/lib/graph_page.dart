import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ddcapp/helpers/sensor_singelton.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;

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
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: OrientationBuilder(builder: (context, orientation) {
            return Flex(
              direction: orientation == Orientation.landscape ? Axis.horizontal : Axis.vertical,
              children: [
                Expanded(
                  flex: 1,
                  child: CarouselSlider(
                    items: _charts(),
                    options: CarouselOptions(
                        enlargeCenterPage: true,
                        viewportFraction: 0.35,
                        scrollDirection: orientation == Orientation.landscape ? Axis.horizontal : Axis.vertical),
                  ),
                ),
              ],
            );
          }),
        ));
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
      ThreeDimDataLineChart(
        eventStream: userAccelerometerEvents,
        title: "Acceleration",
      ),
      ThreeDimDataLineChart(
        eventStream: magnetometerEvents,
        title: "Magnetic Field",
      ),
      ThreeDimDataLineChart(eventStream: gyroscopeEvents, title: "Gyroscope"),
      const CPUFrequencyChart(),
      const CPUTempChart(),
    ];
  }
}

class CPUTempChart extends StatefulWidget {
  const CPUTempChart({Key? key}) : super(key: key);

  @override
  State<CPUTempChart> createState() => _CPUTempChartState();
}

class _CPUTempChartState extends State<CPUTempChart> {
  late charts.Series<double, int> temperatureSeries;
  List<double> data = [];
  late Timer periodicUpdater;
  static const int dataPointLimit = 200;

  _CPUTempChartState() {
    temperatureSeries = charts.Series(
        id: "Temperature in °C",
        data: SensorHelper().cpuTemps,
        domainFn: (event, index) => index!,
        measureFn: (event, index) => event);
    periodicUpdater = Timer.periodic(const Duration(milliseconds: 50), (timer) => updateValue());
  }

  updateValue() {
    setState(() {});
  }

  @override
  dispose() {
    periodicUpdater.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: charts.LineChart(
        [temperatureSeries],
        behaviors: [
          charts.SeriesLegend(
              position: charts.BehaviorPosition.bottom,
              outsideJustification: charts.OutsideJustification.startDrawArea),
          charts.ChartTitle("CPU Temperature")
        ],
        animate: false,
      ),
    );
  }
}

class CPUFrequencyChart extends StatefulWidget {
  const CPUFrequencyChart({Key? key}) : super(key: key);

  @override
  State<CPUFrequencyChart> createState() => _CPUFrequencyChartState();
}

class _CPUFrequencyChartState extends State<CPUFrequencyChart> {
  List<charts.Series<int, int>> cpuSeries = [];
  late Timer periodicUpdater;
  static const int dataPointLimit = 200;

  _CPUFrequencyChartState() {
    var cpu = SensorHelper.latestData.cpuInfo;
    if (cpu != null) {
      if (cpu.numberOfCores != null) {
        for (int i = 0; i < cpu.numberOfCores!; i++) {
          cpuSeries.add(charts.Series(
              id: "cpu$i",
              data: SensorHelper().cpuFreqs[i],
              domainFn: (event, index) => index!,
              measureFn: (event, index) => event));
        }
      }
    }

    periodicUpdater = Timer.periodic(const Duration(milliseconds: 50), (timer) => updateValues());
  }

  @override
  dispose() {
    periodicUpdater.cancel();
    super.dispose();
  }

  updateValues() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: charts.LineChart(
        [...cpuSeries],
        behaviors: [
          charts.SeriesLegend(
            cellPadding: const EdgeInsets.all(2.0),
            position: charts.BehaviorPosition.bottom,
            outsideJustification: charts.OutsideJustification.start,
          ),
          charts.ChartTitle("CPU frequencies")
        ],
        animate: false,
      ),
    );
  }
}

class ThreeDimDataLineChart extends StatefulWidget {
  final Stream eventStream;
  final String? title;

  const ThreeDimDataLineChart({Key? key, required this.eventStream, this.title}) : super(key: key);

  @override
  State<ThreeDimDataLineChart> createState() => _ThreeDimDataLineChartState();
}

class _ThreeDimDataLineChartState extends State<ThreeDimDataLineChart> {
  List<_EventWrapper> data = [];
  charts.Series<_EventWrapper, DateTime>? displayedX;
  charts.Series<_EventWrapper, DateTime>? displayedY;
  charts.Series<_EventWrapper, DateTime>? displayedZ;
  StreamSubscription? _subscription;

  Timer? periodicUpdater;

  static const int dataPointLimit = 200;

  _ThreeDimDataLineChartState();

  @override
  initState() {
    super.initState();

    displayedX = charts.Series(
        id: "x", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.x);
    displayedY = charts.Series(
        id: "y", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.y);
    displayedZ = charts.Series(
        id: "z", data: data, domainFn: (event, index) => event.time, measureFn: (event, index) => event.z);

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

    return Card(
        child: charts.TimeSeriesChart(
      [displayedX!, displayedY!, displayedZ!],
      behaviors: [
        charts.SeriesLegend(
            position: charts.BehaviorPosition.bottom, outsideJustification: charts.OutsideJustification.startDrawArea),
        if (widget.title != null) charts.ChartTitle(widget.title!)
      ],
      animate: false,
    ));
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
  double x = 0;
  double y = 0;
  double z = 0;

  DateTime time;

  _EventWrapper(T event, this.time) {
    dynamic t;
    switch (event.runtimeType) {
      case AccelerometerEvent:
        t = event as AccelerometerEvent;
        break;
      case GyroscopeEvent:
        t = event as GyroscopeEvent;

        break;
      case UserAccelerometerEvent:
        t = event as UserAccelerometerEvent;

        break;
      case MagnetometerEvent:
        t = event as MagnetometerEvent;

        break;
      default:
        throw Exception("Wrong event type used for EventWrapper");
    }
    x = t.x;
    y = t.y;
    z = t.z;
  }
}
