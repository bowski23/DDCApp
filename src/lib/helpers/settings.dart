// Copyright 2022 Jan Golebiowski jan.golebiowski(at)web.de || github: @bowski23
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that
// the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the
//    following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
//    the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or
//    promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
// AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  //all settings should be defined here
  Setting<int> chosenCamera = Setting("chosenCamera", 0);
  Setting<bool> useMachineLearning = Setting("useMachineLearning", false);

  //below is the actual class definition
  static Settings? _instance;
  static Settings get instance {
    return _instance ?? _createInstance();
  }

  static Settings _createInstance() {
    _instance = Settings._();
    return _instance!;
  }

  static bool ensureInitialized() {
    // ignore: unnecessary_null_comparison
    if (instance != null) return true;
    return false;
  }

  Settings._();
}

class Setting<T> {
  final String _key;
  T? _value;
  final T _defaultValue;
  SharedPreferences? _prefs;
  final List<T>? _enumValues;
  ValueNotifier<T> notifier;

  //as generic enums aren't easily handable in flutter we use as a workaround the passing of the enum values at definition as a parameter.
  Setting(this._key, this._defaultValue, {List<T>? enumValues})
      : _enumValues = enumValues,
        notifier = ValueNotifier<T>(_defaultValue) {
    _init();
  }

  _init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs == null) throw Exception("Shared Preferences couldn't be loaded");

    if (!_prefs!.containsKey(_key)) {
      _value = _defaultValue;
    } else {
      switch (T) {
        case String:
          _value = _prefs!.getString(_key) as T;
          break;
        case int:
          _value = _prefs!.getInt(_key) as T;
          break;
        case double:
          _value = _prefs!.getDouble(_key) as T;
          break;
        case bool:
          _value = _prefs!.getBool(_key) as T;
          break;
        default:
          if (_defaultValue is Enum && _enumValues != null) {
            var index = _prefs!.getInt(_key);
            _value = index != null ? _enumValues![index] : null;
            break;
          }
          throw Exception("Setting of type $T with key ${_key}is not viable");
      }
    }

    notifier.value = value;
  }

  T get value {
    if (_value != null) {
      return _value!;
    } else {
      return _defaultValue;
    }
  }

  set value(T? val) {
    if (val == null) {
      _value = null;
      _prefs!.remove(_key);
      notifier.value = value;
      return;
    } else {
      _value = val;
      notifier.value = value;
    }

    switch (T) {
      case String:
        _prefs!.setString(_key, _value! as String);
        break;
      case int:
        _prefs!.setInt(_key, _value! as int);
        break;
      case double:
        _prefs!.setDouble(_key, _value! as double);
        break;
      case bool:
        _prefs!.setBool(_key, _value! as bool);
        break;
      default:
        if (val is Enum) {
          _prefs!.setInt(_key, (_value as Enum).index);
          break;
        }
        assert(false, "Setting of type $T with key ${_key}is not viable");
    }
  }

  bool get isUsingDefaultValue {
    return _value == null;
  }

  List<T>? get enumValues {
    if (T is Enum) {
      return _enumValues;
    } else {
      return null;
    }
  }
}
