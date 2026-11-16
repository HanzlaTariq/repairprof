import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../features/auth/auth_page.dart';
import '../features/auth/session.dart';
import '../features/home/home.dart';
import '../features/intake/intake.dart';
import '../features/ticket/ticket_controller.dart';
import '../features/ticket/ticket_page.dart';
import '../features/ticket/quote_page.dart';
import '../features/ticket/collection_page.dart';
import '../features/ticket/receipt_page.dart';
import '../features/shop/shop_page.dart';

class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) =>
      FirebaseAuth.instance.currentUser == null
      ? const RouteSettings(name: '/login')
      : null;
}

final appRoutes = <GetPage>[
  GetPage(name: '/session', page: () => const SessionPage()),
  GetPage(name: '/login', page: () => const AuthPage()),
  GetPage(name: '/register', page: () => const AuthPage(register: true)),
  GetPage(name: '/reset', page: () => const AuthPage(reset: true)),
  GetPage(name: '/privacy', page: () => const PrivacyPage()),
  GetPage(
    name: '/setup',
    page: () => const ShopPage(setup: true),
    middlewares: [AuthGuard()],
  ),
  GetPage(
    name: '/home',
    page: () => const HomePage(),
    middlewares: [AuthGuard()],
    binding: BindingsBuilder(() => Get.lazyPut(() => HomeController())),
  ),
  GetPage(
    name: '/intake',
    page: () => const IntakePage(),
    middlewares: [AuthGuard()],
    binding: BindingsBuilder(() => Get.lazyPut(() => IntakeController())),
  ),
  GetPage(
    name: '/ticket',
    page: () => const TicketPage(),
    middlewares: [AuthGuard()],
    binding: BindingsBuilder(() => Get.lazyPut(() => TicketController())),
  ),
  GetPage(
    name: '/quote',
    page: () => const QuotePage(),
    middlewares: [AuthGuard()],
  ),
  GetPage(
    name: '/collection',
    page: () => const CollectionPage(),
    middlewares: [AuthGuard()],
  ),
  GetPage(
    name: '/receipt',
    page: () => const ReceiptPage(),
    middlewares: [AuthGuard()],
  ),
];
