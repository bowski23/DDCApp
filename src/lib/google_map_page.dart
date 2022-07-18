import 'package:ddcapp/provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'marker.dart';

Widget googleMapUI(BuildContext context, {bool control = true, void Function(LatLng)? onTap}) {
  return Consumer<LocationProvider>(builder: (consumContext, model, child) {
    if (model.locationPosition != null) {
      return Column(
        children: [
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(target: model.locationPosition!, zoom: control ? 18 : 16),
              myLocationEnabled: true,
              myLocationButtonEnabled: control,
              zoomControlsEnabled: control,
              compassEnabled: control,
              scrollGesturesEnabled: control,
              zoomGesturesEnabled: control,
              tiltGesturesEnabled: control,
              rotateGesturesEnabled: control,
              onTap: onTap,
              onMapCreated: (GoogleMapController controller) {
                if (!control) {
                  model.location!.onLocationChanged.listen((event) {
                    controller.moveCamera(CameraUpdate.newLatLng(LatLng(event.latitude!, event.longitude!)));
                  });
                }
              },
              markers: Provider.of<CreateMarker>(context, listen: true).markers,
            ),
          )
        ],
      );
    }
    return const Center(
      child: CircularProgressIndicator(),
    );
  });
}

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({Key? key}) : super(key: key);

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  BitmapDescriptor? customIcon;
  bool _isPinDropEnabled = false;
  int _marker = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).initalization();
      Provider.of<CreateMarker>(context, listen: false).randomFun();
    });
  }

  clearSigns() {
    Provider.of<CreateMarker>(context, listen: false).markers.clear();
    setState(() {});
  }

  toggleMarkerDrop() {
    _isPinDropEnabled = !_isPinDropEnabled;
    setState(() {});
  }

  changeMarker() {
    _marker = (_marker + 1) % 4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text("Google Map Live Tracking"),
          elevation: 0.0,
          backgroundColor: Colors.grey,
          actions: [
            IconButton(onPressed: toggleMarkerDrop, icon: const Icon(Icons.pin_drop_outlined)),
            IconButton(onPressed: changeMarker, icon: const Icon(Icons.change_circle_outlined)),
            IconButton(onPressed: clearSigns, icon: const Icon(Icons.cancel_outlined)),
          ],
        ),
        body: googleMapUI(context, onTap: (value) {
          if (_isPinDropEnabled) {
            Provider.of<CreateMarker>(context, listen: false).createMarker("222 ", _marker.toString(), value);
            setState(() {});
          }
        }));
  }
}
