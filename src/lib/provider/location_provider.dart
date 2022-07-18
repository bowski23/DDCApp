import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class LocationProvider with ChangeNotifier {
  Location? _location = Location();
  Location? get location => _location;
  LatLng? _locationPosition;
  LatLng? get locationPosition => _locationPosition;

  bool locationServiceActive = true;

  locationProvider() {
    _location = Location();
  }

  initalization() async {
    await getUserLocation();
  }

  getUserLocation() async {
    bool serviceEnabled;

    serviceEnabled = await location!.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location!.requestService();

      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionGranted = await location!.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location!.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    location!.onLocationChanged.listen((LocationData currentLocation) {
      _locationPosition = LatLng(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );
      if (kDebugMode) {
        print(_locationPosition);
      }
      notifyListeners();
    });
  }
}
