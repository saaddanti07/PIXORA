import 'package:flutter/widgets.dart';
import 'package:pixora/app/app.dart';
import 'package:pixora/app/bootstrap.dart';

/// PIXORA entry point.
///
/// Everything PIXORA needs is created in [PixoraBootstrap] (a composition
/// root) before the first frame, so the very first frame already renders with
/// the user's saved theme and language — no flash of the wrong appearance.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PixoraBootstrap bootstrap = await PixoraBootstrap.create();
  runApp(PixoraApp(bootstrap: bootstrap));
}
