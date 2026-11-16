import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../models/repair.dart';
import '../../services/receipts.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = map(Get.arguments);
    final ticket = map(args['ticket']);
    return Scaffold(
      appBar: AppBar(title: Text('${ticket['number']} · Receipt')),
      body: PdfPreview(
        pdfFileName:
            '${ticket['number']}_${args['final'] == true ? 'final' : 'handover'}.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        build: (_) => buildReceipt(
          ticket,
          collectionCode: args['code'],
          finalReceipt: args['final'] == true,
        ),
      ),
    );
  }
}
