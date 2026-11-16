import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../models/repair.dart';

class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageBody({super.key, required this.child, this.maxWidth = 850});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  const Section(this.title, {super.key, required this.child, this.icon});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: primary, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final waiting = status == 'Awaiting Approval';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: waiting ? const Color(0xFFFFF3DC) : mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: waiting ? const Color(0xFF79530B) : primary,
        ),
      ),
    );
  }
}

Widget field(
  TextEditingController controller,
  String label, {
  bool required = true,
  int lines = 1,
  int max = 200,
  TextInputType? keyboard,
  bool obscure = false,
  String? hint,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: TextFormField(
    controller: controller,
    obscureText: obscure,
    maxLines: lines,
    maxLength: max,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
    ),
    validator: (v) =>
        required && (v == null || v.trim().isEmpty) ? 'Required' : null,
  ),
);
Widget info(String title, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 11, color: Color(0xFF697E72)),
      ),
      const SizedBox(height: 3),
      SelectableText(
        value.isEmpty ? '—' : value,
        style: const TextStyle(fontSize: 14, color: ink),
      ),
    ],
  ),
);
Widget notice(String text, {bool error = false}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.symmetric(vertical: 10),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: error ? const Color(0xFFFFEEEE) : mint,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: error ? Colors.red.shade900 : primary,
      fontSize: 13,
    ),
  ),
);
void showError(Object e) => Get.snackbar(
  'Action not confirmed',
  e.toString(),
  snackPosition: SnackPosition.BOTTOM,
  duration: const Duration(seconds: 6),
  backgroundColor: const Color(0xFFFFECEC),
  margin: const EdgeInsets.all(16),
);

class TicketTile extends StatelessWidget {
  final Json ticket;
  final VoidCallback onTap;
  const TicketTile(this.ticket, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket['customerName'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ticket['device'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF61786A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: primary),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  ticket['number'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                StatusPill(ticket['status'] ?? ''),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
