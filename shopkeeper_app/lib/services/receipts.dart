import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/repair.dart';

Future<Uint8List> buildReceipt(
  Json t, {
  String? collectionCode,
  bool finalReceipt = false,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  final doc = pw.Document();
  final shop = map(t['shop']), finalData = map(t['final']);
  final green = PdfColor.fromHex('#0B6B57');
  pw.Widget line(String title, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RepairProof',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: green,
            ),
          ),
          pw.Text(
            finalReceipt ? 'FINAL REPAIR RECEIPT' : 'DEVICE HANDOVER RECEIPT',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Divider(color: green),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 15),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Keep this receipt private.',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${c.pageNumber} of ${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (c) => [
        line(
          'Shop',
          '${shop['name']}\n${shop['phone']} · ${shop['address']}\n${shop['hours']}',
        ),
        line('Ticket', t['number'].toString()),
        line('Device', '${t['brand']} ${t['model']}'),
        if (!finalReceipt) ...[
          line('Customer', t['customerName'].toString()),
          line('Received', dateText(t['createdAt'])),
          line('Reported problem', t['problem'].toString()),
          line('Exterior condition', t['condition'].toString()),
          line('Accessories received', t['accessories'].toString()),
          line('Initial estimate', money(t['estimateMinor'])),
          line(
            'Agreed inspection/return charge',
            '${money(t['returnFeeMinor'])}\n${t['returnFeeAgreement']}',
          ),
          line('Expected pickup / agreed check-in', dateText(t['checkInAt'])),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: green)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PRIVATE COLLECTION CODE',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  collectionCode ??
                      'REISSUE REQUIRED — Ask the shop for a new collection receipt.',
                  style: pw.TextStyle(
                    fontSize: collectionCode == null ? 11 : 19,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          line('Intake acknowledgement', t['acknowledgement'].toString()),
          pw.Text(
            'This estimate is not approval for a later quotation. A tracking link does not authorize collection. Bring this receipt, collection code and collector details. If no alternate contact is available, return at the agreed check-in time.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ] else ...[
          line('Outcome', t['outcome'].toString()),
          line('Collected', dateText(finalData['at'])),
          line('Recipient', finalData['collector'].toString()),
          line('Accessories handed over', finalData['accessories'].toString()),
          for (final item in maps(finalData['items']))
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 9),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item['description']}\n${item['quantity']} × ${money(item['unitMinor'])}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    money(
                      (item['quantity'] as num) * (item['unitMinor'] as num),
                    ),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 16),
          line('Final charges', money(finalData['totalMinor'])),
          line('Recorded payments', money(finalData['paidMinor'])),
          line('Outstanding balance', money(finalData['balanceMinor'])),
          for (final p in maps(t['payments']))
            line(
              'Settlement record',
              '${dateText(p['at'])} · ${money(p['amountMinor'])} · ${p['method']}',
            ),
          if (finalData['warranty'] != null) ...[
            line(
              'Shop warranty period',
              '${finalData['warranty']['start']} to ${finalData['warranty']['end']}',
            ),
            line('Covered work', finalData['warranty']['covered']),
            line('Exclusions', finalData['warranty']['exclusions']),
            line('Warranty terms', finalData['warranty']['terms']),
            pw.Text(
              'Warranty is supplied by the repair shop, not guaranteed by RepairProof. The stated dates do not mean every fault is covered.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ] else
            line(
              'Warranty',
              'No new repair warranty recorded for this handover.',
            ),
        ],
      ],
    ),
  );
  return doc.save();
}
