import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

class CreateMarker extends ChangeNotifier {
  //Markers
  Set<Marker> markers = {};
  BitmapDescriptor? speedIcon;
  BitmapDescriptor? turnRightIcon;
  BitmapDescriptor? attentionIcon;
  BitmapDescriptor? stopIcon;

  static Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void randomFun() {
    getBytesFromAsset('assets/images/tempo30.png', 64).then((onValue) {
      speedIcon = BitmapDescriptor.fromBytes(onValue);
    });

    getBytesFromAsset('assets/images/turnRight.png', 64).then((onValue) {
      turnRightIcon = BitmapDescriptor.fromBytes(onValue);
    });

    getBytesFromAsset('assets/images/attention.png', 64).then((onValue) {
      attentionIcon = BitmapDescriptor.fromBytes(onValue);
    });

    getBytesFromAsset('assets/images/stop.png', 64).then((onValue) {
      stopIcon = BitmapDescriptor.fromBytes(onValue);
    });
  }
  //UUID
  //Nanoid

  void createMarker(String name, String type, LatLng pos) {
    if (speedIcon == null) randomFun();
    if (type == "0") {
      //stopshield
      markers.add(Marker(
        //add first marker
        markerId: MarkerId(DateTime.now().toString()),
        position: pos, //position of marker
        infoWindow: InfoWindow(title: name),
        icon: speedIcon!, //Icon for Marker
      ));
    } else if (type == "1") {
      markers.add(Marker(
        //add first marker
        markerId: MarkerId(DateTime.now().toString()),
        position: pos, //position of marker
        infoWindow: InfoWindow(title: name),
        icon: turnRightIcon!, //Icon for Marker
      ));
    } else if (type == "2") {
      markers.add(Marker(
        //add first marker
        markerId: MarkerId(DateTime.now().toString()),
        position: pos, //position of marker
        infoWindow: InfoWindow(title: name),
        icon: attentionIcon!, //Icon for Marker
      ));
    } else if (type == "3") {
      markers.add(Marker(
        //add first marker
        markerId: MarkerId(DateTime.now().toString()),
        position: pos, //position of marker
        infoWindow: InfoWindow(title: name),
        icon: stopIcon!, //Icon for Marker
      ));
    }
    notifyListeners();
  }
}
