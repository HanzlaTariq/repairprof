import 'package:get/get.dart';

import '../../models/repair.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';

class TicketController extends GetxController {
  final ticket = <String, dynamic>{}.obs, busy = false.obs, error = ''.obs;
  late final String id;
  String? claim;
  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is String) {
      id = args;
    } else {
      id = args['id'];
      claim = args['collectionCode'];
    }
    load();
  }

  Future<void> load() async {
    busy.value = true;
    error.value = '';
    try {
      ticket.assignAll(await Get.find<Api>().call('detail', {'ticketId': id}));
    } catch (e) {
      error.value = e.toString();
    } finally {
      busy.value = false;
    }
  }

  Future<Json?> command(String op, Json data) async {
    busy.value = true;
    try {
      final result = await Get.find<Api>().command(op, {
        'ticketId': id,
        ...data,
      });
      await load();
      return result;
    } catch (e) {
      showError(e);
      return null;
    } finally {
      busy.value = false;
    }
  }

  Json? get latestQuote {
    final q = maps(ticket['quotes']);
    return q.isEmpty ? null : q.last;
  }
}
