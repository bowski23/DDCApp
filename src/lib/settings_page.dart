import 'package:flutter/material.dart';

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
        value: i,
        child: Text("${camera.name} - ${camera.lensDirection.name}"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Row(children: const [Icon(Icons.settings), Text("Settings")])),
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
  final Setting<T> _setting;
  final String description;
  final IconData? icon;
  final Widget child;

  SettingWidget(this._setting, {Key? key, required this.child, String description = '', this.icon})
      : description = description.isEmpty ? _setting.value.runtimeType.toString() : description,
        super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        margin: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withAlpha(128)))),
              child: SizedBox(width: 50, height: 40, child: icon != null ? Icon(icon) : null),
            ),
            Flexible(
              child: Text(
                description,
                overflow: TextOverflow.fade,
                maxLines: 3,
              ),
            ),
            Container(
                constraints: const BoxConstraints(minWidth: 100), margin: const EdgeInsets.only(left: 10), child: child)
          ],
        ));
  }
}

class BooleanSettingWidget extends StatefulWidget {
  final Setting<bool> setting;
  final String description;
  final IconData? icon;
  final VoidCallback? onChanged;

  const BooleanSettingWidget(this.setting, {Key? key, this.description = '', this.icon, this.onChanged})
      : super(key: key);

  @override
  State<BooleanSettingWidget> createState() => _BooleanSettingWidgetState();
}

class _BooleanSettingWidgetState extends State<BooleanSettingWidget> {
  @override
  Widget build(BuildContext context) {
    return SettingWidget<bool>(
      widget.setting,
      description: widget.description,
      icon: widget.icon,
      child: Switch(
          value: widget.setting.value,
          onChanged: (val) => setState(() {
                widget.setting.value = val;
              })),
    );
  }
}

class DropDownSettingWidget<T> extends StatefulWidget {
  final List<DropdownMenuItem<T>> items;
  final Setting<T> setting;
  final String description;
  final IconData? icon;
  final VoidCallback? onChanged;

  const DropDownSettingWidget(this.setting, this.items, {Key? key, this.description = '', this.icon, this.onChanged})
      : super(key: key);

  @override
  State<DropDownSettingWidget<T>> createState() => _DropDownSettingWidgetState<T>();
}

class _DropDownSettingWidgetState<T> extends State<DropDownSettingWidget<T>> {
  void valueChanged(T? newValue) {
    if (newValue == null) return;
    setState(() {
      widget.setting.value = newValue;
    });
    if (widget.onChanged != null) widget.onChanged!.call();
  }

  @override
  Widget build(BuildContext context) {
    return SettingWidget<T>(
      widget.setting,
      description: widget.description,
      icon: widget.icon,
      child: DropdownButton<T>(
        items: widget.items,
        onChanged: valueChanged,
        value: widget.setting.value,
      ),
    );
  }
}
