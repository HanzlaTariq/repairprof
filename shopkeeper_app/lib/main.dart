import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'services/api.dart';
import 'features/auth/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppConfig.validate();
    await Firebase.initializeApp(options: AppConfig.firebase);
    if (AppConfig.emulators) {
      await FirebaseAuth.instance.useAuthEmulator(
        kIsWeb ? '127.0.0.1' : AppConfig.host,
        9099,
      );
    }
    runApp(const RepairProofApp());
  } catch (e) {
    runApp(
      MaterialApp(
        theme: repairTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_outlined, size: 48, color: primary),
                  const SizedBox(height: 18),
                  const Text(
                    'RepairProof setup needs attention',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  SelectableText('$e'),
                  const SizedBox(height: 14),
                  const Text(
                    'See SETUP_ROMAN_URDU.md for local Firebase and production configuration.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RepairProofApp extends StatelessWidget {
  const RepairProofApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'RepairProof',
    debugShowCheckedModeBanner: false,
    theme: repairTheme(),
    initialRoute: '/session',
    getPages: appRoutes,
    defaultTransition: Transition.fadeIn,
    initialBinding: BindingsBuilder(() {
      Get.put(Api(), permanent: true);
      Get.put(Session(), permanent: true);
    }),
  );
}
