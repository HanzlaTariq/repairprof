import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';
import 'ticket_controller.dart';

class TicketPage extends GetView<TicketController> {
  const TicketPage({super.key});
  Future<String?> note(
    String title, {
    String label = 'Note',
    String description = '',
  }) async {
    final c = TextEditingController();
    final result = await Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.isNotEmpty) ...[
                Text(description),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: c,
                maxLength: 400,
                maxLines: 3,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Back')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) Get.back(result: c.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  Future<void> transition(String to) async {
    final n = await note(
      to,
      description: to == 'Ready for Pickup'
          ? 'Confirm the approved repair is complete and the device has been checked. Describe the check below.'
          : 'Record the reason or work note.',
    );
    if (n == null) return;
    await controller.command('transition', {
      'to': to,
      'note': n,
      'completed': to == 'Ready for Pickup',
      'checked': to == 'Ready for Pickup',
    });
  }

  Future<void> manualDecision() async {
    final q = controller.latestQuote;
    if (q == null) return;
    String decision = 'approved', channel = 'in_person';
    final verification = TextEditingController();
    final data = await Get.dialog<Json>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('Decision on quote v${q['version']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${money(q['totalMinor'])} · Record the customer’s actual decision. This note is not independent identity verification.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  items: const [
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Customer approved'),
                    ),
                    DropdownMenuItem(
                      value: 'declined',
                      child: Text('Customer declined'),
                    ),
                  ],
                  onChanged: (v) => decision = v ?? 'approved',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  items: [
                    const DropdownMenuItem(
                      value: 'in_person',
                      child: Text('In person'),
                    ),
                    if (map(controller.ticket['contact'])['kind'] != 'C')
                      const DropdownMenuItem(
                        value: 'phone',
                        child: Text('Verified call with customer'),
                      ),
                  ],
                  onChanged: (v) => channel = v ?? 'in_person',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: verification,
                  maxLength: 400,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'How was the customer verified?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Back')),
            FilledButton(
              onPressed: () {
                if (verification.text.trim().isNotEmpty) {
                  Get.back(
                    result: {
                      'version': q['version'],
                      'value': decision,
                      'channel': channel,
                      'verification': verification.text.trim(),
                    },
                  );
                }
              },
              child: const Text('Record decision'),
            ),
          ],
        ),
      ),
    );
    verification.dispose();
    if (data != null) await controller.command('decision', data);
  }

  Future<void> access(String scope) async {
    final expiry = TextEditingController(text: '30');
    bool permission =
        scope == 'family' || map(controller.ticket['contact'])['kind'] == 'A';
    final approved = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('Issue $scope link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scope == 'family'
                      ? 'Only status and pickup/check-in details are shown.'
                      : 'Anyone holding this link can view customer repair information and decide the current quotation. Share only with the customer.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: expiry,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  decoration: const InputDecoration(
                    labelText: 'Valid days · 1 to 365',
                  ),
                ),
                if (scope == 'customer' &&
                    map(controller.ticket['contact'])['kind'] != 'A')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: permission,
                    onChanged: (v) => set(() => permission = v ?? false),
                    title: const Text(
                      'Customer separately permitted this access',
                    ),
                  ),
                notice('Issuing a link replaces earlier links of this scope.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: permission ? () => Get.back(result: true) : null,
              child: const Text('Issue private link'),
            ),
          ],
        ),
      ),
    );
    final days = int.tryParse(expiry.text) ?? 0;
    expiry.dispose();
    if (approved != true) return;
    final result = await controller.command('issueAccess', {
      'scope': scope,
      'days': days,
      'customerPermission': permission,
    });
    if (result == null) return;
    if (result['token'] == null) {
      showError(
        'The earlier issuance succeeded, but secrets are not stored for replay. Issue a new link to replace it.',
      );
      return;
    }
    final link = '${AppConfig.tracking}/#t=${result['token']}';
    await Get.dialog(
      AlertDialog(
        title: Text('$scope access'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Expires ${dateText(result['expiresAt'])}',
                style: const TextStyle(fontSize: 12),
              ),
              notice(
                'Opening Share does not confirm delivery. Record the real outcome in the communication log.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      Get.snackbar(
                        'Copied',
                        'Private link copied. Share with the permitted recipient only.',
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await SharePlus.instance.share(
                          ShareParams(
                            text: scope == 'family'
                                ? 'Repair status and next check-in from ${controller.ticket['shop']['name']}: $link'
                                : 'Your private repair record from ${controller.ticket['shop']['name']}: $link',
                          ),
                        );
                      } catch (_) {
                        showError(
                          'Sharing could not be opened. Use Copy link.',
                        );
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share link'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> logContact() async {
    String channel = 'call', outcome = 'outcome unknown';
    final text = TextEditingController();
    final data = await Get.dialog<Json>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Record contact attempt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Record what actually happened. A dialer or share sheet does not prove delivery.',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  items: ['call', 'manual_share', 'in_person']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => channel = v ?? 'call',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  isExpanded: true,
                  items:
                      [
                            'no answer',
                            'spoke to customer',
                            'message passed through family',
                            'outcome unknown',
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => outcome = v ?? 'outcome unknown',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: text,
                  maxLines: 3,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Back')),
            FilledButton(
              onPressed: () => Get.back(
                result: {
                  'channel': channel,
                  'outcome': outcome,
                  'note': text.text.trim(),
                },
              ),
              child: const Text('Save attempt'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (data != null) await controller.command('communication', data);
  }

  Future<void> editContact() async {
    final current = map(controller.ticket['contact']);
    String kind = current['kind'];
    bool permission = false;
    final number = TextEditingController(text: current['number']),
        recipient = TextEditingController(text: current['recipient']),
        purpose = TextEditingController(text: current['purpose']),
        verification = TextEditingController();
    final data = await Get.dialog<Json>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Change contact route'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  items: const [
                    DropdownMenuItem(
                      value: 'A',
                      child: Text('A · Personal alternate'),
                    ),
                    DropdownMenuItem(
                      value: 'B',
                      child: Text('B · Permitted family'),
                    ),
                    DropdownMenuItem(
                      value: 'C',
                      child: Text('C · No alternate contact'),
                    ),
                  ],
                  onChanged: (v) => set(() => kind = v ?? 'C'),
                ),
                const SizedBox(height: 14),
                if (kind != 'C')
                  field(
                    number,
                    'Reachable number',
                    max: 24,
                    keyboard: TextInputType.phone,
                  ),
                if (kind == 'B') ...[
                  field(recipient, 'Recipient name', max: 100),
                  field(purpose, 'Permitted purpose', max: 160),
                ],
                field(
                  verification,
                  'Customer permission / verification note',
                  max: 400,
                  lines: 3,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: permission,
                  onChanged: (v) => set(() => permission = v ?? false),
                  title: const Text('Customer permitted this change'),
                ),
                notice(
                  'All earlier customer and family tracking links will be revoked.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Back')),
            FilledButton(
              onPressed: permission
                  ? () => Get.back(
                      result: {
                        'contact': {
                          'kind': kind,
                          'number': kind == 'C' ? '' : number.text.trim(),
                          'recipient': kind == 'B' ? recipient.text.trim() : '',
                          'purpose': kind == 'B' ? purpose.text.trim() : '',
                          'permission': kind == 'B',
                        },
                        'verification': verification.text.trim(),
                        'permission': true,
                      },
                    )
                  : null,
              child: const Text('Save change'),
            ),
          ],
        ),
      ),
    );
    for (final c in [number, recipient, purpose, verification]) {
      c.dispose();
    }
    if (data != null) await controller.command('contact', data);
  }

  Future<void> receipt(bool finalReceipt) async {
    if (!finalReceipt && controller.claim == null) {
      final reason = await note(
        'Reissue collection receipt',
        description:
            'A new private collection code replaces the old one. Verify the customer before reissuing.',
        label: 'Reason and verification',
      );
      if (reason == null) return;
      final result = await controller.command('reissueClaim', {
        'reason': reason,
      });
      if (result == null) return;
      controller.claim = result['collectionCode'];
      if (controller.claim == null) {
        showError(
          'Prior reissue was saved. Reissue again to obtain a fresh printable code.',
        );
        return;
      }
    }
    await Get.toNamed(
      '/receipt',
      arguments: {
        'ticket': Map<String, dynamic>.from(controller.ticket),
        'code': controller.claim,
        'final': finalReceipt,
      },
    );
  }

  Future<void> photo(int slot) async {
    try {
      final data = await Get.find<Api>().call('photo', {
        'ticketId': controller.id,
        'slot': slot,
      });
      await Get.dialog(
        Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Image.memory(base64Decode(data['base64']))),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      showError(e);
    }
  }

  Future<void> payment() async {
    final amount = TextEditingController();
    String method = 'cash';
    final data = await Get.dialog<Json>(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Record balance payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Outstanding: ${money(controller.ticket['final']['balanceMinor'])}',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Actual amount received · PKR',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'bank transfer',
                    child: Text('Bank transfer'),
                  ),
                ],
                onChanged: (v) => method = v ?? 'cash',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Back')),
            FilledButton(
              onPressed: () {
                try {
                  Get.back(
                    result: {
                      'amountMinor': minor(amount.text),
                      'method': method,
                    },
                  );
                } catch (e) {
                  showError(e);
                }
              },
              child: const Text('Record payment'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    if (data != null) await controller.command('payment', data);
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => Scaffold(
      appBar: AppBar(
        title: Text(controller.ticket['number'] ?? 'Repair record'),
        actions: [
          IconButton(
            onPressed: controller.busy.value ? null : controller.load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: PageBody(
        child: controller.ticket.isEmpty
            ? Center(
                child: controller.error.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(controller.error.value),
                          TextButton(
                            onPressed: controller.load,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              )
            : AbsorbPointer(
                absorbing: controller.busy.value,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (controller.busy.value) const LinearProgressIndicator(),
                    if (controller.error.isNotEmpty)
                      notice(controller.error.value, error: true),
                    Section(
                      '${controller.ticket['brand']} ${controller.ticket['model']}',
                      icon: Icons.phone_android_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.ticket['customerName'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          StatusPill(controller.ticket['status']),
                          const SizedBox(height: 16),
                          info(
                            'Reported problem',
                            controller.ticket['problem'],
                          ),
                          info(
                            'Condition & accessories',
                            '${controller.ticket['condition']}\n${controller.ticket['accessories']}',
                          ),
                          info(
                            'Initial estimate',
                            money(controller.ticket['estimateMinor']),
                          ),
                          info(
                            'Expected pickup / next check-in',
                            dateText(controller.ticket['checkInAt']),
                          ),
                          if ((controller.ticket['photoPaths'] as List)
                              .isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: List.generate(
                                (controller.ticket['photoPaths'] as List)
                                    .length,
                                (i) => OutlinedButton.icon(
                                  onPressed: () => photo(i),
                                  icon: const Icon(Icons.image_outlined),
                                  label: Text('Photo ${i + 1}'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    actions(),
                    contactSection(),
                    quotes(),
                    if (controller.ticket['status'] == 'Delivered')
                      Section(
                        'Final receipt & settlement',
                        icon: Icons.receipt_long_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            info('Outcome', controller.ticket['outcome']),
                            info(
                              'Charges',
                              money(controller.ticket['final']['totalMinor']),
                            ),
                            info(
                              'Paid / balance',
                              '${money(controller.ticket['final']['paidMinor'])} / ${money(controller.ticket['final']['balanceMinor'])}',
                            ),
                            FilledButton.icon(
                              onPressed: () => receipt(true),
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('View / print final receipt'),
                            ),
                            if ((controller.ticket['final']['balanceMinor']
                                    as num) >
                                0)
                              TextButton(
                                onPressed: payment,
                                child: const Text('Record remaining payment'),
                              ),
                          ],
                        ),
                      ),
                    Section(
                      'Audit timeline',
                      icon: Icons.history,
                      child: Column(
                        children: maps(controller.ticket['events']).reversed
                            .map(
                              (e) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: primary,
                                ),
                                title: Text(
                                  e['note'],
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${e['from']} → ${e['to']}\n${dateText(e['at'])}\nRecorded by: ${e['actor']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
      ),
    ),
  );
  Widget actions() {
    final status = controller.ticket['status'];
    final quote = controller.latestQuote;
    return Section(
      'Next action',
      icon: Icons.playlist_add_check,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == 'Received')
            FilledButton(
              onPressed: () => transition('Checking'),
              child: const Text('Start checking'),
            ),
          if (['Checking', 'Repairing', 'Awaiting Approval'].contains(status))
            FilledButton.icon(
              onPressed: () async {
                await Get.toNamed(
                  '/quote',
                  arguments: Map<String, dynamic>.from(controller.ticket),
                );
                controller.load();
              },
              icon: const Icon(Icons.request_quote_outlined),
              label: Text(
                quote == null ? 'Create quotation' : 'Issue revised quotation',
              ),
            ),
          if (status == 'Awaiting Approval') ...[
            const SizedBox(height: 10),
            if (quote?['decision'] == null)
              OutlinedButton(
                onPressed: manualDecision,
                child: const Text('Record customer decision'),
              )
            else if (quote?['decision']['value'] == 'approved')
              OutlinedButton(
                onPressed: () => transition('Repairing'),
                child: const Text('Start / resume approved repair'),
              ),
            if (quote?['decision'] == null)
              notice(
                'No response means waiting. Initial intake is not quotation approval.',
              ),
          ],
          if (status == 'Repairing') ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => transition('Ready for Pickup'),
              child: const Text('Repair complete & device checked'),
            ),
          ],
          if (['Checking', 'Repairing'].contains(status))
            TextButton(
              onPressed: () => transition('Ready for Return'),
              child: const Text('Cannot repair · prepare return'),
            ),
          if (['Ready for Pickup', 'Ready for Return'].contains(status))
            FilledButton.icon(
              onPressed: () async {
                await Get.toNamed(
                  '/collection',
                  arguments: Map<String, dynamic>.from(controller.ticket),
                );
                controller.load();
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verify collection & hand over'),
            ),
          if (status != 'Delivered')
            TextButton.icon(
              onPressed: () => receipt(false),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                controller.claim == null
                    ? 'Reissue / print handover receipt'
                    : 'Print handover receipt',
              ),
            ),
          if (status == 'Delivered')
            const Text('Physical handover completed. This repair is closed.'),
        ],
      ),
    );
  }

  Widget contactSection() {
    final c = map(controller.ticket['contact']);
    return Section(
      'Contact & private access',
      icon: Icons.perm_contact_calendar_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info('Contact route', 'Case ${c['kind']}'),
          if (c['kind'] != 'C') ...[
            info(
              'Reachable recipient',
              '${c['kind'] == 'B' ? c['recipient'] : controller.ticket['customerName']} · ${c['number']}',
            ),
            if (c['kind'] == 'B')
              info(
                'Customer permission',
                '${c['purpose']}\n${dateText(c['permissionAt'])}',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      if (!await launchUrl(
                        Uri(scheme: 'tel', path: c['number']),
                        mode: LaunchMode.externalApplication,
                      )) {
                        showError(
                          'Dialer unavailable. Call the displayed number manually.',
                        );
                      }
                    } catch (_) {
                      showError('Dialer unavailable.');
                    }
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Open dialer'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      access(c['kind'] == 'B' ? 'family' : 'customer'),
                  child: Text(
                    c['kind'] == 'B'
                        ? 'Family status link'
                        : 'Customer tracking link',
                  ),
                ),
                OutlinedButton(
                  onPressed: logContact,
                  child: const Text('Log actual contact outcome'),
                ),
              ],
            ),
          ] else
            notice(
              'Use the printed receipt. Agreed check-in: ${dateText(controller.ticket['checkInAt'])}. No call or update is promised.',
            ),
          if (c['kind'] != 'A')
            TextButton(
              onPressed: () => access('customer'),
              child: const Text('Issue separately permitted customer access'),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  final n = await note('Revoke all customer links');
                  if (n != null) {
                    await controller.command('revokeAccess', {
                      'scope': 'customer',
                    });
                  }
                },
                child: const Text('Revoke customer links'),
              ),
              if (c['kind'] == 'B')
                TextButton(
                  onPressed: () async {
                    final n = await note('Revoke all family links');
                    if (n != null) {
                      await controller.command('revokeAccess', {
                        'scope': 'family',
                      });
                    }
                  },
                  child: const Text('Revoke family links'),
                ),
            ],
          ),
          if (controller.ticket['status'] != 'Delivered')
            TextButton(
              onPressed: editContact,
              child: const Text('Change route with customer permission'),
            ),
          for (final log in maps(controller.ticket['communications']).reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${log['channel']} · ${log['outcome']}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${log['recipient']} · ${dateText(log['at'])}\n${log['note']}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget quotes() => Section(
    'Quotation history',
    icon: Icons.request_quote_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maps(controller.ticket['quotes']).isEmpty)
          const Text('No quotation issued yet.'),
        for (final q in maps(controller.ticket['quotes']).reversed)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Version ${q['version']} · ${money(q['totalMinor'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              q['decision'] == null ? 'No decision' : q['decision']['value'],
            ),
            children: [
              info('Diagnosis', q['diagnosis']),
              for (final item in maps(q['items']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['description']),
                  subtitle: Text(
                    '${item['quantity']} × ${money(item['unitMinor'])}',
                  ),
                ),
              if (q['decision'] != null)
                info(
                  'Decision evidence',
                  '${q['decision']['channel']} · ${dateText(q['decision']['at'])}\n${q['decision']['verification']}',
                ),
            ],
          ),
      ],
    ),
  );
}
