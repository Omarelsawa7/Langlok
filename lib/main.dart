import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be called before any Player/VideoController is constructed.
  // Registers the native libmpv-backed engine (hardware-accelerated
  // decoding for MKV/MP4/AVI/WEBM) for this platform.
  MediaKit.ensureInitialized();

  runApp(const LangTokApp());
}
