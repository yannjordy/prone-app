import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/deep_link/deep_links.dart';
import 'core/local/local_backend.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize local backend and seed data
  final backend = LocalBackend();
  await backend.seedData();

  // Recupere un potentiel prone://join/... avant le premier rendu.
  await DeepLinks.instance.start();

  runApp(const ConnectFlowApp());
}
