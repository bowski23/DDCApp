import 'provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

Widget googleMapUI({bool control = true, void Function(LatLng)? onTap}) {
  return Consumer<LocationProvider>(builder: (consumContext, model, child) {
    if (model.locationPosition != null) {
      return Column(
        children: [
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(target: model.locationPosition!, zoom: control ? 18 : 14),
              myLocationEnabled: true,
              myLocationButtonEnabled: control,
              zoomControlsEnabled: control,
              compassEnabled: control,
              scrollGesturesEnabled: control,
              zoomGesturesEnabled: control,
              tiltGesturesEnabled: control,
              rotateGesturesEnabled: control,
              onTap: onTap,
              onMapCreated: (GoogleMapController controller) {},
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).initalization();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Google Map Live Tracking"),
        ),
        body: googleMapUI());
  }
}
