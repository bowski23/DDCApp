import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera_home_page.dart';
import 'helpers/settings.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.ensureInitialized();

  cameras = await availableCameras();
  print(cameras);

  runApp(MaterialApp(home: const CameraHomePage()));
}
