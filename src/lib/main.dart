import 'package:camera/camera.dart';
import 'package:ddcapp/camera_view.dart';
import 'package:ddcapp/helpers/sensor_singelton.dart';
import 'package:ddcapp/provider/location_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'marker.dart';
import 'google_map_page.dart';
import 'helpers/settings.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.ensureInitialized();
  await SensorHelper.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  cameras = await availableCameras();
  if (kDebugMode) {
    print(cameras);
  }

  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => LocationProvider(),
          child: const GoogleMapPage(),
        ),
        ChangeNotifierProvider(
          create: (_) => CreateMarker(),
        )
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        debugShowMaterialGrid: false,
        home: const CameraView(
          title: 'Camera',
        ),
        theme: ThemeData(iconTheme: const IconThemeData(color: Colors.grey)),
        themeMode: ThemeMode.dark,
      )));
}
