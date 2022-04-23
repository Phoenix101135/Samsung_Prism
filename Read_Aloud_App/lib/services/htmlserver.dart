import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_assets_server/local_assets_server.dart';

class HTMLServer {
  var server;

  HTMLServer() {
    initServer();
  }
  initServer() async {
    final server = new LocalAssetsServer(
      address: InternetAddress.loopbackIPv4,
      port: 8080,
      assetsBasePath: 'assets',
      logger: DebugLogger(),
    );
    final address = await server.serve();
    print(address.address);
    print("Listening on port " + server.port.toString());
  }
}
