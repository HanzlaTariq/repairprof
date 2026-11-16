import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../services/api.dart';

class Session extends GetxController {
  final profile = <String, dynamic>{}.obs;
  final error = ''.obs;
  StreamSubscription<User?>? _sub;
  @override
  void onReady() {
    super.onReady();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      profile.clear();
      Get.find<Api>().clear();
      if (user == null) {
        Get.offAllNamed('/login');
      } else {
        load();
      }
    });
  }

  Future<void> load() async {
    error.value = '';
    try {
      final data = await Get.find<Api>().call('getShop');
      profile.assignAll(data);
      Get.offAllNamed('/home');
    } on ApiError catch (e) {
      if (e.status == 404) {
        Get.offAllNamed('/setup');
      } else {
        error.value = e.message;
        Get.offAllNamed('/session');
      }
    } catch (e) {
      error.value = e.toString();
      Get.offAllNamed('/session');
    }
  }

  Future<void> signOut() async {
    profile.clear();
    Get.find<Api>().clear();
    await Clipboard.setData(const ClipboardData(text: ''));
    await FirebaseAuth.instance.signOut();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

class SessionPage extends GetView<Session> {
  const SessionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Obx(
          () => controller.error.isEmpty
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.error.value, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: controller.load,
                      child: const Text('Retry connection'),
                    ),
                    TextButton(
                      onPressed: controller.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
