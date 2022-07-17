import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:ddcapp/object_detector_view.dart';
import 'package:ddcapp/provider/location_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'google_map_page.dart';
import 'helpers/settings.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.ensureInitialized();

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
      ],
      child: MaterialApp(
        home: ObjectDetectorView(),
        theme: ThemeData(iconTheme: const IconThemeData(color: Colors.grey)),
        themeMode: ThemeMode.dark,
      )));
}
