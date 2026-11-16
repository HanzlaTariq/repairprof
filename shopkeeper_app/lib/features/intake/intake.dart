import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';

class IntakeController extends GetxController {
  final step = 0.obs,
      kind = 'A'.obs,
      permission = false.obs,
      ack = false.obs,
      busy = false.obs,
      error = ''.obs,
      progress = ''.obs;
  final fields = <String, TextEditingController>{
    for (final key in [
      'customerName',
      'number',
      'recipient',
      'purpose',
      'brand',
      'model',
      'problem',
      'condition',
      'accessories',
      'estimate',
      'returnFee',
      'returnAgreement',
    ])
      key: TextEditingController(),
  };
  final forms = List.generate(3, (_) => GlobalKey<FormState>());
  final photos = <Uint8List>[].obs;
  final checkIn = DateTime.now().add(const Duration(days: 2)).obs;
  final requestId = const Uuid().v4();
  Json? submitted;
  @override
  void onInit() {
    super.onInit();
    fields['estimate']!.text = '0';
    fields['returnFee']!.text = '0';
    fields['purpose']!.text = 'Repair status and pickup information only';
    recoverPhoto();
  }

  Future<void> recoverPhoto() async {
    if (kIsWeb) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) return;
      if (response.files != null && response.files!.isNotEmpty) {
        final use = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Recover interrupted photo?'),
            content: const Text(
              'A photo capture was interrupted. Add the recovered exterior-condition photo only if it belongs to this customer intake.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Add photo'),
              ),
            ],
          ),
        );
        if (use == true) {
          final data = await response.files!.first.readAsBytes();
          if (data.length <= 3 * 1024 * 1024) photos.add(data);
        }
      } else if (response.exception != null) {
        error.value = 'Camera was interrupted. Please take the photo again.';
      }
    } catch (_) {
      error.value =
          'Could not recover the interrupted photo. You can take it again.';
    }
  }

  Future<void> pick(ImageSource source) async {
    if (photos.length >= 4) {
      error.value = 'Maximum 4 photos.';
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final data = await file.readAsBytes();
      if (data.length > 3 * 1024 * 1024) {
        error.value = 'Photo exceeds 3 MB. Choose a smaller image.';
        return;
      }
      photos.add(data);
      error.value = '';
    } catch (_) {
      error.value =
          'Camera or photo access was denied/unavailable. Allow access in device settings or use another photo.';
    }
  }

  Json contact() => {
    'kind': kind.value,
    'number': kind.value == 'C' ? '' : fields['number']!.text.trim(),
    'recipient': kind.value == 'B' ? fields['recipient']!.text.trim() : '',
    'permission': kind.value == 'B' && permission.value,
    'purpose': kind.value == 'B' ? fields['purpose']!.text.trim() : '',
  };
  void next() {
    error.value = '';
    if (step.value < 3 && !forms[step.value].currentState!.validate()) return;
    if (step.value == 0 && kind.value == 'B' && !permission.value) {
      error.value = 'Record customer permission for the family contact.';
      return;
    }
    if (step.value == 2) {
      try {
        minor(fields['estimate']!.text);
        final fee = minor(fields['returnFee']!.text);
        if (fee > 0 && fields['returnAgreement']!.text.trim().isEmpty) {
          throw const FormatException(
            'Record prior agreement for the return charge.',
          );
        }
      } catch (e) {
        error.value = e.toString();
        return;
      }
    }
    step.value++;
  }

  Future<void> save() async {
    if (!ack.value) {
      error.value = 'Record the customer’s intake acknowledgement.';
      return;
    }
    busy.value = true;
    error.value = '';
    try {
      submitted ??= {
        'requestId': requestId,
        for (final key in [
          'customerName',
          'brand',
          'model',
          'problem',
          'condition',
          'accessories',
        ])
          key: fields[key]!.text.trim(),
        'contact': contact(),
        'estimateMinor': minor(fields['estimate']!.text),
        'returnFeeMinor': minor(fields['returnFee']!.text),
        'returnFeeAgreement': fields['returnAgreement']!.text.trim(),
        'checkInAt': checkIn.value.toUtc().toIso8601String(),
        'acknowledgement':
            'Customer acknowledged recorded condition, accessories, initial estimate, any agreed return charge and next check-in.',
        'photoSlots': List.generate(photos.length, (i) => i),
      };
      for (var i = 0; i < photos.length; i++) {
        progress.value = 'Saving condition photo ${i + 1} of ${photos.length}';
        await Get.find<Api>().call('upload', {
          'requestId': requestId,
          'slot': i,
          'base64': base64Encode(photos[i]),
        });
      }
      progress.value = 'Confirming shared repair record';
      final result = await Get.find<Api>().call('createTicket', submitted!);
      Get.offNamed(
        '/ticket',
        arguments: {
          'id': result['ticketId'],
          'collectionCode': result['collectionCode'],
          'receipt': true,
        },
      );
    } catch (e) {
      error.value =
          '$e\nYour submitted details are kept for an identical retry. Check Tickets before starting a separate intake.';
    } finally {
      busy.value = false;
      progress.value = '';
    }
  }

  @override
  void onClose() {
    for (final c in fields.values) {
      c.dispose();
    }
    photos.clear();
    super.onClose();
  }
}

class IntakePage extends GetView<IntakeController> {
  const IntakePage({super.key});
  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !controller.busy.value,
      child: Scaffold(
        appBar: AppBar(title: const Text('New repair')),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'STEP ${controller.step.value + 1} OF 4',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (controller.step.value + 1) / 4,
                borderRadius: BorderRadius.circular(6),
                minHeight: 5,
              ),
              const SizedBox(height: 23),
              Text(
                [
                  'Customer & contact',
                  'Device & condition',
                  'Estimate & check-in',
                  'Review the handover',
                ][controller.step.value],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              if (controller.step.value == 0) customerForm(),
              if (controller.step.value == 1) deviceForm(),
              if (controller.step.value == 2) termsForm(context),
              if (controller.step.value == 3) review(),
              if (controller.error.isNotEmpty)
                notice(controller.error.value, error: true),
              if (controller.busy.value) notice(controller.progress.value),
              const SizedBox(height: 15),
              Row(
                children: [
                  if (controller.step.value > 0 &&
                      controller.submitted == null) ...[
                    OutlinedButton(
                      onPressed: controller.busy.value
                          ? null
                          : () => controller.step.value--,
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.busy.value
                          ? null
                          : controller.step.value == 3
                          ? controller.save
                          : controller.next,
                      child: Text(
                        controller.busy.value
                            ? 'Saving…'
                            : controller.step.value == 3
                            ? (controller.submitted == null
                                  ? 'Save repair & receipt'
                                  : 'Retry the same save')
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
  Widget customerForm() => Form(
    key: controller.forms[0],
    child: Column(
      children: [
        field(controller.fields['customerName']!, 'Customer name', max: 100),
        DropdownButtonFormField<String>(
          initialValue: controller.kind.value,
          decoration: const InputDecoration(
            labelText: 'Reachable contact route',
          ),
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'A',
              child: Text('A · Another personal phone'),
            ),
            DropdownMenuItem(
              value: 'B',
              child: Text('B · Permitted family contact'),
            ),
            DropdownMenuItem(
              value: 'C',
              child: Text('C · No alternate contact'),
            ),
          ],
          onChanged: (v) => controller.kind.value = v ?? 'A',
        ),
        const SizedBox(height: 18),
        if (controller.kind.value != 'C')
          field(
            controller.fields['number']!,
            'Reachable alternate number',
            max: 24,
            keyboard: TextInputType.phone,
            hint: 'Not the SIM inside the repair phone',
          ),
        if (controller.kind.value == 'B') ...[
          field(
            controller.fields['recipient']!,
            'Family recipient name',
            max: 100,
          ),
          field(controller.fields['purpose']!, 'Permitted purpose', max: 160),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.permission.value,
            onChanged: (v) => controller.permission.value = v ?? false,
            title: const Text('Customer permits this family contact'),
          ),
          notice(
            'Family receives status/pickup information only. The customer still decides quotations and authorizes collection.',
          ),
        ],
        if (controller.kind.value == 'C')
          notice(
            'No phone number is needed. Print the receipt and agree when the customer will return. Do not promise live updates.',
          ),
      ],
    ),
  );
  Widget deviceForm() => Form(
    key: controller.forms[1],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(controller.fields['brand']!, 'Device brand', max: 60),
        field(controller.fields['model']!, 'Device model', max: 80),
        field(
          controller.fields['problem']!,
          'Reported problem',
          max: 1200,
          lines: 3,
        ),
        field(
          controller.fields['condition']!,
          'Exterior condition',
          max: 800,
          lines: 3,
        ),
        field(
          controller.fields['accessories']!,
          'Received accessories',
          max: 400,
          lines: 2,
          required: false,
        ),
        notice(
          'Photograph exterior condition and accessories only. Never record unlock codes, passwords, CNIC or personal gallery content.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < controller.photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      controller.photos[i],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filled(
                      tooltip: 'Remove photo',
                      onPressed: () => controller.photos.removeAt(i),
                      icon: const Icon(Icons.close, size: 15),
                    ),
                  ),
                ],
              ),
            if (controller.photos.length < 4) ...[
              OutlinedButton.icon(
                onPressed: () => controller.pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('Photo picker'),
              ),
            ],
          ],
        ),
      ],
    ),
  );
  Widget termsForm(BuildContext context) => Form(
    key: controller.forms[2],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          controller.fields['estimate']!,
          'Initial estimate · PKR',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          max: 11,
        ),
        field(
          controller.fields['returnFee']!,
          'Previously agreed inspection/return charge · PKR',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          max: 11,
        ),
        field(
          controller.fields['returnAgreement']!,
          'Prior agreement for any return charge',
          required: false,
          max: 300,
          lines: 2,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined, color: primary),
          title: const Text('Expected pickup / next check-in'),
          subtitle: Text(
            dateText(controller.checkIn.value.toUtc().toIso8601String()),
          ),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: controller.checkIn.value,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(controller.checkIn.value),
            );
            if (time != null) {
              controller.checkIn.value = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            }
          },
        ),
        notice(
          'An initial estimate and intake acknowledgement do not approve a later quotation.',
        ),
      ],
    ),
  );
  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Section(
        'Handover summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info('Customer', controller.fields['customerName']!.text),
            info(
              'Contact route',
              'Case ${controller.kind.value}${controller.kind.value == 'C' ? ' · paper receipt / in-person check-in' : ' · ${controller.fields['number']!.text}'}',
            ),
            info(
              'Device',
              '${controller.fields['brand']!.text} ${controller.fields['model']!.text}',
            ),
            info('Problem', controller.fields['problem']!.text),
            info('Condition', controller.fields['condition']!.text),
            info('Accessories', controller.fields['accessories']!.text),
            info(
              'Initial estimate',
              money(minor(controller.fields['estimate']!.text)),
            ),
            info(
              'Check-in',
              dateText(controller.checkIn.value.toUtc().toIso8601String()),
            ),
            Text('${controller.photos.length} condition photos'),
          ],
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: controller.ack.value,
        onChanged: controller.busy.value
            ? null
            : (v) => controller.ack.value = v ?? false,
        title: const Text(
          'Customer acknowledged the intake details and check-in arrangement.',
        ),
      ),
      notice(
        'A receipt is issued only after the shared save is confirmed. Keep the collection code private.',
      ),
    ],
  );
}
