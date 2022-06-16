import 'package:camera/camera.dart';
import 'package:ddcapp/settings_page.dart';
import 'package:flutter/material.dart';
import 'helpers/settings.dart';
import 'main.dart';
import 'graph_page.dart';

// CameraApp is the Main Application.
class CameraHomePage extends StatefulWidget {
  /// Default Constructor
  const CameraHomePage({Key? key}) : super(key: key);

  @override
  State<CameraHomePage> createState() => _CameraHomePageState();
}

class _CameraHomePageState extends State<CameraHomePage> {
  late CameraController controller;

  @override
  void initState() {
    super.initState();
    setCamera(Settings.instance.chosenCamera.value);
    Settings.instance.chosenCamera.notifier.addListener(() {
      setCamera(Settings.instance.chosenCamera.value);
    });
  }

  setCamera(int index) {
    controller = CameraController(cameras[index], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Column(children: [
      CameraPreview(controller),
      Container(
        margin: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(child: Text("Map"), onPressed: () => print("pressed")),
            Column(
              children: [
                ElevatedButton(child: Text("Picture"), onPressed: () => print("pressed")),
                ElevatedButton(
                    child: Text("Settings"),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()))),
              ],
            ),
            Container(
                child: ElevatedButton(
              child: Text("Graph"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GraphPage())),
            ))
          ],
        ),
      )
    ]);
  }
}
