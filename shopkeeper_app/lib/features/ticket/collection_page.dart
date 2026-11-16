import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Json ticket;
  final code = TextEditingController(),
      recovery = TextEditingController(),
      collector = TextEditingController(),
      accessories = TextEditingController(),
      paid = TextEditingController(text: '0'),
      days = TextEditingController(text: '30'),
      covered = TextEditingController(),
      excluded = TextEditingController(
        text: 'Impact, liquid damage and unrelated faults.',
      );
  final form = GlobalKey<FormState>();
  int step = 0;
  bool device = false,
      accessory = false,
      physical = false,
      manual = false,
      warranty = false,
      busy = false;
  String method = 'unpaid';
  Json? submitted;
  bool get repaired => ticket['status'] == 'Ready for Pickup';
  int get total => repaired
      ? (maps(ticket['quotes']).last['totalMinor'] as num).toInt()
      : (ticket['returnFeeMinor'] as num).toInt();
  @override
  void initState() {
    super.initState();
    ticket = map(Get.arguments);
    accessories.text = ticket['accessories'] ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      code,
      recovery,
      collector,
      accessories,
      paid,
      days,
      covered,
      excluded,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || !physical) {
      showError('Confirm physical handover after all checks.');
      return;
    }
    setState(() => busy = true);
    try {
      final start = DateTime.now().toUtc().add(const Duration(hours: 5));
      final n = int.tryParse(days.text) ?? 0;
      if (warranty && (n < 1 || n > 730)) {
        throw const FormatException('Warranty duration must be 1–730 days.');
      }
      submitted ??= {
        'ticketId': ticket['id'],
        'code': manual ? '' : code.text.trim(),
        'recoveryNote': manual ? recovery.text.trim() : '',
        'collector': collector.text.trim(),
        'deviceMatched': device,
        'accessoriesChecked': accessory,
        'physicalHandover': physical,
        'accessories': accessories.text.trim(),
        'paidMinor': minor(paid.text),
        'paymentMethod': method,
        'warranty': repaired && warranty
            ? {
                'start': start.toIso8601String().substring(0, 10),
                'end': start
                    .add(Duration(days: n))
                    .toIso8601String()
                    .substring(0, 10),
                'covered': covered.text.trim(),
                'exclusions': excluded.text.trim(),
              }
            : null,
      };
      await Get.find<Api>().command('handover', submitted!);
      Get.back(result: true);
    } catch (e) {
      if (e is ApiError && e.status >= 400 && e.status < 500) {
        submitted = null;
      }
      showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Collect & close repair')),
      body: PageBody(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              StatusPill(ticket['status']),
              const SizedBox(height: 15),
              Text(
                [
                  '1 · Verify the handover',
                  '2 · Settlement & warranty',
                  '3 · Confirm physical release',
                ][step],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              if (step == 0) ...[
                info(
                  'Device',
                  '${ticket['number']} · ${ticket['brand']} ${ticket['model']}',
                ),
                info('Customer', ticket['customerName']),
                field(collector, 'Collector name', max: 100),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: manual,
                  onChanged: (v) => setState(() => manual = v),
                  title: const Text('Lost receipt: manual resolution'),
                ),
                if (manual) ...[
                  notice(
                    'Stop and resolve ownership with the customer. Document the evidence checked and why release is authorized. A family status link is not proof.',
                    error: true,
                  ),
                  field(
                    recovery,
                    'Detailed manual verification record',
                    max: 500,
                    lines: 4,
                  ),
                ] else
                  field(code, 'Private collection code', max: 80),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: device,
                  onChanged: (v) => setState(() => device = v ?? false),
                  title: const Text('Device matches this repair record'),
                ),
                field(
                  accessories,
                  'Accessories being returned',
                  required: false,
                  max: 400,
                  lines: 2,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accessory,
                  onChanged: (v) => setState(() => accessory = v ?? false),
                  title: const Text('Accessories checked with the collector'),
                ),
              ],
              if (step == 1) ...[
                info(
                  'Final outcome',
                  repaired ? 'Repaired' : 'Returned unrepaired',
                ),
                info('Final agreed charges', money(total)),
                field(
                  paid,
                  'Actual amount received now · PKR',
                  max: 11,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Settlement method',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank transfer',
                      child: Text('Bank transfer (record only)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'unpaid'),
                ),
                const SizedBox(height: 16),
                if (repaired) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: warranty,
                    onChanged: (v) => setState(() => warranty = v),
                    title: const Text('Record shop warranty'),
                  ),
                  if (warranty) ...[
                    field(
                      days,
                      'Warranty days',
                      max: 3,
                      keyboard: TextInputType.number,
                    ),
                    field(covered, 'Covered work', max: 500, lines: 2),
                    field(excluded, 'Exclusions', max: 500, lines: 2),
                  ],
                ] else
                  notice(
                    'Returned unrepaired: no new repair warranty. Only the previously agreed return charge applies.',
                  ),
              ],
              if (step == 2) ...[
                Section(
                  'Final review',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info('Collector', collector.text),
                      info('Final charges', money(total)),
                      info('Received payment', money(minor(paid.text))),
                      info('Balance', money(total - minor(paid.text))),
                      info(
                        'Warranty',
                        warranty && repaired
                            ? '${days.text} days · ${covered.text}'
                            : 'No new repair warranty',
                      ),
                    ],
                  ),
                ),
                notice(
                  'Press confirm only when you are physically handing over this device. The backend will check proof and save the final receipt together.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: physical,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => physical = v ?? false),
                  title: const Text(
                    'I confirm the physical device is being handed to this collector.',
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  if (step > 0 && submitted == null) ...[
                    OutlinedButton(
                      onPressed: busy ? null : () => setState(() => step--),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : step == 2
                          ? submit
                          : () {
                              if (!form.currentState!.validate()) return;
                              if (step == 0 &&
                                  (!device ||
                                      !accessory ||
                                      (manual &&
                                          recovery.text.trim().length < 30))) {
                                showError(
                                  'Complete device/accessory checks and record adequate verification.',
                                );
                                return;
                              }
                              if (step == 1) {
                                try {
                                  final amount = minor(paid.text);
                                  if (amount > total ||
                                      (amount > 0 && method == 'unpaid')) {
                                    throw const FormatException(
                                      'Check payment amount and method.',
                                    );
                                  }
                                } catch (e) {
                                  showError(e);
                                  return;
                                }
                              }
                              setState(() => step++);
                            },
                      child: Text(
                        busy
                            ? 'Confirming…'
                            : step == 2
                            ? (submitted == null
                                  ? 'Confirm handover'
                                  : 'Retry same handover')
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
