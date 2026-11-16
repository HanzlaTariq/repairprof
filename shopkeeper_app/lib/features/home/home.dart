import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';
import '../../core/theme.dart';
import '../auth/session.dart';
import '../shop/shop_page.dart';

class HomeController extends GetxController {
  final tab = 0.obs,
      busy = false.obs,
      summary = <String, dynamic>{}.obs,
      tickets = <Json>[].obs,
      error = ''.obs,
      total = 0.obs,
      page = 0.obs,
      filter = ''.obs;
  final search = TextEditingController();
  String from = '', to = '';
  @override
  void onInit() {
    super.onInit();
    loadOverview();
  }

  int _request = 0;
  Future<void> loadOverview() async {
    final request = ++_request;
    busy.value = true;
    error.value = '';
    try {
      if (tab.value == 0) {
        summary.assignAll(
          await Get.find<Api>().call('dashboard', {'from': from, 'to': to}),
        );
      }
      final data = await Get.find<Api>().call('list', {
        'query': search.text.trim(),
        'history': tab.value == 2,
        'status': filter.value,
        'page': page.value,
        'from': from,
        'to': to,
      });
      if (request != _request) return;
      tickets.assignAll(maps(data['tickets']));
      total.value = data['total'] ?? 0;
    } catch (e) {
      if (request == _request) error.value = e.toString();
    } finally {
      if (request == _request) busy.value = false;
    }
  }

  void select(int i) {
    tab.value = i;
    page.value = 0;
    filter.value = '';
    search.clear();
    if (i != 3) loadOverview();
  }

  Future<void> open(Json t) async {
    await Get.toNamed('/ticket', arguments: t['id']);
    loadOverview();
  }

  @override
  void onClose() {
    search.dispose();
    super.onClose();
  }
}

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Obx(
    () => Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: primary),
            SizedBox(width: 8),
            Text('RepairProof', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.busy.value ? null : controller.loadOverview,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.tab.value,
        onDestinationSelected: controller.select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tickets',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop',
          ),
        ],
      ),
      floatingActionButton: controller.tab.value == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Get.toNamed('/intake');
                controller.loadOverview();
              },
              icon: const Icon(Icons.add),
              label: const Text('New repair'),
            ),
      body: controller.tab.value == 3
          ? const ShopPage(embedded: true)
          : PageBody(
              child: RefreshIndicator(
                onRefresh: controller.loadOverview,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                    if (controller.tab.value == 0) ...[
                      Text(
                        'Your workshop,\nin one clear view.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: ink),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        Get.find<Session>().profile['name'] ?? 'Your shop',
                        style: const TextStyle(color: primary),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, c) {
                          final width = (c.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              metric(
                                'Open repairs',
                                '${controller.summary['open'] ?? 0}',
                                Icons.build_circle_outlined,
                                width,
                              ),
                              metric(
                                'Ready devices',
                                '${controller.summary['ready'] ?? 0}',
                                Icons.task_alt,
                                width,
                              ),
                              metric(
                                'Handovers',
                                '${controller.summary['delivered'] ?? 0}',
                                Icons.inventory_2_outlined,
                                width,
                              ),
                              metric(
                                'Payments received',
                                money(controller.summary['paidMinor']),
                                Icons.payments_outlined,
                                width,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Repair pipeline',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: map(controller.summary['byStatus']).entries
                            .map(
                              (e) => ActionChip(
                                label: Text('${e.key}  ${e.value}'),
                                onPressed: () {
                                  controller.tab.value = 1;
                                  controller.filter.value = e.key;
                                  controller.loadOverview();
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Recent open repairs',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else ...[
                      Text(
                        controller.tab.value == 2
                            ? 'Delivered history'
                            : 'Repair tickets',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller.search,
                        decoration: InputDecoration(
                          hintText: 'Ticket, customer or device model',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: () {
                              controller.page.value = 0;
                              controller.loadOverview();
                            },
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ),
                        onSubmitted: (_) {
                          controller.page.value = 0;
                          controller.loadOverview();
                        },
                      ),
                      if (controller.tab.value == 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: controller.filter.value,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items:
                                ['', ...statuses.where((s) => s != 'Delivered')]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s.isEmpty ? 'All open statuses' : s,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (s) {
                              controller.filter.value = s ?? '';
                              controller.page.value = 0;
                              controller.loadOverview();
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                            );
                            if (range != null) {
                              controller.from = range.start
                                  .toUtc()
                                  .toIso8601String();
                              controller.to = range.end
                                  .add(const Duration(days: 1))
                                  .subtract(const Duration(milliseconds: 1))
                                  .toUtc()
                                  .toIso8601String();
                              controller.page.value = 0;
                              controller.loadOverview();
                            }
                          },
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            controller.from.isEmpty
                                ? 'All dates'
                                : 'Date filter active',
                          ),
                        ),
                        if (controller.from.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              controller.from = '';
                              controller.to = '';
                              controller.loadOverview();
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    if (controller.busy.value) const LinearProgressIndicator(),
                    if (controller.error.isNotEmpty)
                      notice(controller.error.value, error: true),
                    if (controller.tickets.isEmpty && !controller.busy.value)
                      Section(
                        'No repairs here yet',
                        icon: Icons.inbox_outlined,
                        child: Text(
                          controller.tab.value == 2
                              ? 'Completed handovers appear here.'
                              : 'Create a repair or change your filters.',
                        ),
                      ),
                    for (final t in controller.tickets)
                      TicketTile(t, onTap: () => controller.open(t)),
                    if (controller.total.value > 25)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: controller.page.value > 0
                                ? () {
                                    controller.page.value--;
                                    controller.loadOverview();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            'Page ${controller.page.value + 1} · ${controller.total.value} records',
                          ),
                          IconButton(
                            onPressed:
                                (controller.page.value + 1) * 25 <
                                    controller.total.value
                                ? () {
                                    controller.page.value++;
                                    controller.loadOverview();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    if (controller.tab.value == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'Open/ready: intake date filter. Handovers: collection date. Payments: settlement date. Quotations are not received money.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF697E72),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    ),
  );
  Widget metric(String label, String value, IconData icon, double width) =>
      SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDDEAE3)),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: primary, size: 24),
              const SizedBox(height: 15),
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 11 ? 18 : 27,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF61786A)),
              ),
            ],
          ),
        ),
      );
}
