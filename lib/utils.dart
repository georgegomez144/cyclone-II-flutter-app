import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_device_type/flutter_device_type.dart';

bool isTablet = Device.get().isTablet;
bool isPhone = Device.get().isPhone;
bool isNarrowScreen(BuildContext context) =>
    MediaQuery.of(context).size.width < 800;
bool isLandscape(BuildContext context) =>
    MediaQuery.of(context).size.height < 620;

// Platform helpers
bool get isWeb => kIsWeb;
bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
bool get isMacOrWeb => kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;
