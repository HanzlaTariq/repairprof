import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});
  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  late Json ticket;
  final diagnosis = TextEditingController();
  final lines = <QuoteLine>[];
  final form = GlobalKey<FormState>();
  bool busy = false;
  Json? submitted;
  @override
  void initState() {
    super.initState();
    ticket = map(Get.arguments);
    final old = maps(ticket['quotes']);
    if (old.isNotEmpty) {
      diagnosis.text = old.last['diagnosis'];
      for (final item in maps(old.last['items'])) {
        lines.add(QuoteLine(item));
      }
    } else {
      lines.add(QuoteLine());
    }
  }

  @override
  void dispose() {
    diagnosis.dispose();
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      submitted ??= {
        'ticketId': ticket['id'],
        'diagnosis': diagnosis.text.trim(),
        'items': lines.map((l) => l.json()).toList(),
      };
      await Get.find<Api>().command('issueQuote', submitted!);
      Get.back(result: true);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Issue quotation')),
    body: PageBody(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            notice(
              'Version ${maps(ticket['quotes']).length + 1} · This puts the repair in Awaiting Approval. Existing quote versions and decisions remain in history.',
            ),
            AbsorbPointer(
              absorbing: submitted != null,
              child: Column(
                children: [
                  field(diagnosis, 'Diagnosis', max: 1200, lines: 3),
                  for (var i = 0; i < lines.length; i++)
                    Section(
                      'Line item ${i + 1}',
                      child: Column(
                        children: [
                          field(lines[i].description, 'Description', max: 180),
                          DropdownButtonFormField<String>(
                            initialValue: lines[i].kind,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'parts',
                                child: Text('Parts'),
                              ),
                              DropdownMenuItem(
                                value: 'labour',
                                child: Text('Labour'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => lines[i].kind = v ?? 'parts'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: field(
                                  lines[i].quantity,
                                  'Quantity',
                                  max: 3,
                                  keyboard: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: field(
                                  lines[i].price,
                                  'Unit price · PKR',
                                  max: 11,
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (lines.length > 1)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                lines.removeAt(i).dispose();
                              }),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('Remove line'),
                            ),
                        ],
                      ),
                    ),
                  if (lines.length < 30)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => lines.add(QuoteLine())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add part / labour'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? 'Saving…'
                    : submitted == null
                    ? 'Issue quote for customer decision'
                    : 'Retry same quotation',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class QuoteLine {
  final description = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      price = TextEditingController(text: '0');
  String kind = 'parts';
  QuoteLine([Json? item]) {
    if (item != null) {
      description.text = item['description'];
      quantity.text = '${item['quantity']}';
      price.text = ((item['unitMinor'] as num) / 100).toStringAsFixed(2);
      kind = item['kind'];
    }
  }
  Json json() {
    final q = int.tryParse(quantity.text);
    if (q == null || q < 1 || q > 100) {
      throw const FormatException('Quantity must be 1–100.');
    }
    return {
      'description': description.text.trim(),
      'kind': kind,
      'quantity': q,
      'unitMinor': minor(price.text),
    };
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}
