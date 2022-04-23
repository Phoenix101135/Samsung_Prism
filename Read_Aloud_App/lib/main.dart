import 'package:bixby_app/backgroundServices/readAloudService.dart';
import 'package:bixby_app/backgroundServices/webpageService.dart';
import 'package:bixby_app/pdf/pdfIndexView.dart';
import 'package:bixby_app/services/audioFocusHandler.dart';
import 'package:bixby_app/services/htmlserver.dart';
import 'package:bixby_app/services/intentService.dart';
import 'package:bixby_app/webpage/webpageView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_it/get_it.dart';
import 'dart:async';
import 'dart:io';
import 'dart:async';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'package:uni_links/uni_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeService();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bixby Read Aloud',
      theme: ThemeData(),
      home: MyHomePage(title: 'Bixby Read Aloud'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String webpageURL = "https://bixbysamplewebsite.vercel.app/";
  @override
  void initState() {
    // initDeepLink();
    getCurrentActivePage();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  getCurrentActivePage() {
    FlutterBackgroundService().sendData({"action": "getCurrentActiveSource"});
  }

  navigateToCurrentActivePage({source, webpageUrl}) async {
    String? deepLink = await getInitialLink();
    if (source == "webpage") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebpageView(
            url: webpageUrl,
            deepLink: deepLink ?? "",
          ),
        ),
      );
    } else if (source == "pdf") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFIndexView(deepLink: deepLink ?? ""),
        ),
      );
    }
  }
  // initDeepLink() async {
  //   SharedPreferences sp = await SharedPreferences.getInstance();
  //   String? lastUsedSource = sp.getString('lastUsedSource');
  // String? initialUrl = await getInitialLink();
  //   if (initialUrl != null) {
  //     if (lastUsedSource == null) {
  //       lastUsedSource = "webpage";
  //     }
  //     print(lastUsedSource);
  //     print("initialUrl: $initialUrl");
  //     if (lastUsedSource == "webpage") {
  //       Navigator.push(context, new MaterialPageRoute(builder: (context) {
  //         return new WebpageView(url: webpageURL, deepLink: initialUrl);
  //       }));
  //     } else if (lastUsedSource == "pdf") {
  //       Navigator.push(context, new MaterialPageRoute(builder: (context) {
  //         return new PDFIndexView(
  //           deepLink: initialUrl,
  //         );
  //       }));
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bixby Read Aloud"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (context) => PDFIndexView())),
                child: Text("Import Pdf")),
            ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WebpageView(
                              url: webpageURL,
                            ))),
                child: Text("Import Webpage")),
            ElevatedButton(
                onPressed: () {
                  FlutterBackgroundService().stopBackgroundService();
                  // FlutterBackgroundService()
                  //     .sendData({"action": "pauseTTS", "source": "webpage"});

                  // FlutterBackgroundService()
                  //     .sendData({"action": "pauseTTS", "source": "pdf"});
                },
                child: Text("Stop Service")),
            StreamBuilder(
                stream: FlutterBackgroundService().onDataReceived,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    var event = snapshot.data as Map;
                    if (event["action"] == "currentActiveSourceResponse") {
                      navigateToCurrentActivePage(
                        source: event["source"],
                        webpageUrl: event["url"] ?? "",
                      );
                    }
                  }
                  return Text(snapshot.hasData ? snapshot.data.toString() : "");
                }),
          ],
        ),
      ),
    );
  }
}
