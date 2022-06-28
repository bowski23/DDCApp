import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';

import 'helpers/settings.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<DropdownMenuItem<int>> cameraDropdownItems = [];

  _SettingsPageState() {
    for (int i = 0; i < cameras.length; i++) {
      var camera = cameras[i];
      cameraDropdownItems.add(DropdownMenuItem(
        child: Text("${camera.name} - ${camera.lensDirection.name}"),
        value: i,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Row(children: [Icon(Icons.settings), Text("Settings")])),
        body: Column(
          children: [
            DropDownSettingWidget<int>(
              Settings.instance.chosenCamera,
              cameraDropdownItems,
              onChanged: () => setState(() {}),
              description: "Choose which camera you would like to use.",
              icon: Icons.camera_alt_outlined,
            ),
            BooleanSettingWidget(
              Settings.instance.useMachineLearning,
              description: "Use machine learning?",
              icon: Icons.smart_toy_outlined,
            )
          ],
        ));
  }
}

class SettingWidget<T> extends StatelessWidget {
  Setting<T> _setting;
  String description;
  IconData? icon;
  Widget child;

  SettingWidget(this._setting, {required this.child, this.description = '', this.icon}) {
    if (description.isEmpty) {
      description = _setting.value.runtimeType.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        margin: EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
        child: Row(
          children: [
            Container(
              child: SizedBox(width: 50, height: 40, child: icon != null ? Icon(icon) : null),
              margin: EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withAlpha(128)))),
            ),
            Flexible(
              child: Text(
                description,
                overflow: TextOverflow.fade,
                maxLines: 3,
              ),
            ),
            Container(constraints: BoxConstraints(minWidth: 100), child: child, margin: EdgeInsets.only(left: 10))
          ],
        ));
  }
}

class BooleanSettingWidget extends StatelessWidget {
  Setting<bool> setting;
  BooleanSettingWidget(this.setting, {this.description = '', this.icon, this.onChanged});
  String description;
  IconData? icon;
  VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingWidget<bool>(
      setting,
      child: Switch(value: setting.value, onChanged: (val) => setting.value = val),
      description: description,
      icon: icon,
    );
  }
}

class DropDownSettingWidget<T> extends StatelessWidget {
  List<DropdownMenuItem<T>> items;
  Setting<T> setting;
  String description;
  IconData? icon;
  VoidCallback? onChanged;

  DropDownSettingWidget(this.setting, this.items, {this.description = '', this.icon, this.onChanged});

  void valueChanged(T? newValue) {
    if (newValue == null) return;
    setting.value = newValue;
    if (onChanged != null) onChanged!.call();
  }

  @override
  Widget build(BuildContext context) {
    return SettingWidget<T>(
      setting,
      child: DropdownButton<T>(
        items: items,
        onChanged: valueChanged,
        value: setting.value,
      ),
      description: description,
      icon: icon,
    );
  }
}
