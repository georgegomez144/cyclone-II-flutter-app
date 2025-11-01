import 'package:flutter/material.dart';
import 'package:flutter_device_type/flutter_device_type.dart';

bool isTablet = Device.get().isTablet;
bool isPhone = Device.get().isPhone;
bool isNarrowScreen(context) => MediaQuery.of(context).size.width < 800;
