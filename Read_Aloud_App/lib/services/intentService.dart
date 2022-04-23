import 'dart:async';
import 'dart:convert';
import 'package:uni_links/uni_links.dart';

class IntentService {
  Stream<Uri?>? bixbyIntentStream;

  IntentService() {
    initUniLinks();
  }
  Future<void> initUniLinks() async {
    bixbyIntentStream = uriLinkStream.asBroadcastStream();
    bixbyIntentStream?.listen((uri) {
      print('IntentService: $uri');

      String? json = uri?.queryParameters['data'] ?? "{}";
      var data = jsonDecode(json);
      // showDialog(context: context, builder: builder)
      print(data);
    });
  }

  cancelStream() {}
}
