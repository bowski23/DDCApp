import 'package:camera/camera.dart';
import 'package:ddcapp/provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_home_page.dart';
import 'google_map_page.dart';
import 'helpers/settings.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.ensureInitialized();

  cameras = await availableCameras();
  print(cameras);

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(
      create: (context) => LocationProvider(),
      child: GoogleMapPage(),
    )
  ], child: MaterialApp(home: const CameraHomePage())));
}
