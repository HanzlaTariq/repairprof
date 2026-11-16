import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';
import '../auth/session.dart';

class ShopPage extends StatefulWidget {
  final bool setup, embedded;
  const ShopPage({super.key, this.setup = false, this.embedded = false});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String message = '';
  @override
  void initState() {
    super.initState();
    final p = Get.find<Session>().profile;
    for (final key in ['name', 'phone', 'address', 'hours', 'warrantyTerms']) {
      fields[key] = TextEditingController(
        text:
            p[key] ??
            (key == 'warrantyTerms'
                ? 'Warranty covers only the recorded work. Impact, liquid damage and unrelated faults are excluded.'
                : ''),
      );
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final data = <String, dynamic>{
        for (final e in fields.entries) e.key: e.value.text.trim(),
        'timezone': 'Asia/Karachi',
      };
      await Get.find<Api>().command(
        widget.setup ? 'onboard' : 'updateShop',
        data,
      );
      Get.find<Session>().profile.assignAll(data);
      if (widget.setup) {
        Get.offAllNamed('/home');
      } else {
        setState(
          () => message =
              'Shop saved. Existing ticket terms keep their original version.',
        );
      }
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final password = TextEditingController();
    bool accepted = false;
    final ok = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Delete account & shop?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Download receipts first. All shop records, photos and links will be deleted within 7–8 days. Shop access stops immediately.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  onChanged: (v) => set(() => accepted = v ?? false),
                  title: const Text('Delete my entire shop'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Keep account'),
            ),
            FilledButton(
              onPressed: accepted ? () => Get.back(result: true) : null,
              child: const Text('Request deletion'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      password.dispose();
      return;
    }
    setState(() => busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: password.text,
        ),
      );
      await Get.find<Api>().command('deleteAccount', {
        'confirmation': 'DELETE MY ACCOUNT',
      });
      await Get.find<Session>().signOut();
    } catch (e) {
      showError(e);
    } finally {
      password.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.setup ? 'Set up your shop' : 'Your shop',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Clear details build customer confidence.'),
          const SizedBox(height: 18),
          Form(
            key: form,
            child: Section(
              'Shop details',
              icon: Icons.storefront_outlined,
              child: Column(
                children: [
                  field(fields['name']!, 'Shop name', max: 100),
                  field(
                    fields['phone']!,
                    'Shop contact number',
                    max: 24,
                    keyboard: TextInputType.phone,
                  ),
                  field(fields['address']!, 'Address', max: 240, lines: 2),
                  field(fields['hours']!, 'Opening hours', max: 120),
                  field(
                    fields['warrantyTerms']!,
                    'Default warranty terms',
                    max: 1200,
                    lines: 4,
                  ),
                  notice(
                    'Dates are shown in Pakistan time (Asia/Karachi). Editing defaults does not change terms already saved on tickets.',
                  ),
                  if (message.isNotEmpty) notice(message),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(
                        busy
                            ? 'Saving…'
                            : widget.setup
                            ? 'Open my workshop'
                            : 'Save shop details',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!widget.setup)
            Section(
              'Account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(FirebaseAuth.instance.currentUser?.email ?? ''),
                  TextButton.icon(
                    onPressed: () => Get.toNamed('/privacy'),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacy & deletion information'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : Get.find<Session>().signOut,
                    child: const Text('Sign out'),
                  ),
                  TextButton(
                    onPressed: busy ? null : delete,
                    child: const Text(
                      'Delete account and all shop data',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(
              title: const Text('RepairProof'),
              actions: [
                if (widget.setup)
                  TextButton(
                    onPressed: Get.find<Session>().signOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
            body: body,
          );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & your choices')),
    body: PageBody(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Section(
            'What RepairProof stores',
            child: Text(
              'Your shop account, permitted customer contacts, device descriptions, exterior-condition photos, quotations, decisions, repair events and receipts are stored in Firebase. Do not collect unlock PINs, passwords, CNIC numbers or personal gallery content.',
            ),
          ),
          const Section(
            'Private customer access',
            child: Text(
              'Tracking links work without a customer account. Anyone holding a customer link can view that record and decide on its current quote. Family links provide limited status information only. Collection requires separate proof. The app includes no advertising or analytics SDK.',
            ),
          ),
          const Section(
            'Deletion and retention',
            child: Text(
              'Shop owners can request account deletion in Shop settings or on the public deletion page. Access stops immediately; associated shop records, photos, links and the account are deleted within 7–8 days by scheduled maintenance. Failed uploads are cleaned after 24 hours. Customer data requests should be directed to the shop. Exported receipts and independently managed backups are outside the app.',
            ),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await launchUrl(
                Uri.parse('${AppConfig.tracking}/privacy'),
                mode: LaunchMode.externalApplication,
              );
              if (!ok) showError('Could not open the privacy page.');
            },
            child: const Text('Open published privacy page'),
          ),
        ],
      ),
    ),
  );
}
