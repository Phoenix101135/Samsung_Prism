import 'dart:async';
import 'dart:convert';

import 'package:bixby_app/backgroundServices/pdfService.dart';
import 'package:bixby_app/backgroundServices/webpageService.dart';
import 'package:bixby_app/services/audioFocusHandler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_tts/flutter_tts.dart';

void onStart() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("Service started");
  FlutterBackgroundServiceAndroid.registerWith();

  FlutterTts flutterTts = FlutterTts();
  final service = FlutterBackgroundService();
  WebpageService webService = WebpageService(flutterTts);
  PDFService pdfService = PDFService(flutterTts);
  service.onDataReceived.listen((event) {
    print("Event data in service " + event.toString());
    if (event!['action'] == 'disposeAll') {
      print("Dispose!");
      flutterTts.stop();
      webService.dispose();
      pdfService.dispose();
      webService = new WebpageService(flutterTts);
      pdfService = new PDFService(flutterTts);
      return;
    }
    if (event['action'] == "getCurrentActiveSource") {
      if (webService.url != "") {
        print(webService.url);
        service.sendData({
          "action": "currentActiveSourceResponse",
          "source": "webpage",
          "url": webService.url
        });
      } else if (pdfService.path != "") {
        service.sendData({
          "action": "currentActiveSourceResponse",
          "source": "pdf",
          "path": pdfService.path
        });
      } else {
        service.sendData(
            {"action": "currentActiveSourceResponse", "source": "none"});
      }
      return;
    }
    if (event['source'] == "webpage") {
      if (event['action'] == 'downloadHTML') {
        webService.downloadHTML(event['url']);
      } else if (event['action'] == 'read') {
        webService.speakFromGivenFirstSentences(
          url: event['url'],
          firstSentence: event['firstSentence'],
        );
      } else if (event['action'] == 'readSpecific') {
        webService.readSpecificText(
          paraIndex: event['paraIndex'],
          sentenceIndex: event['sentenceIndex'],
        );
      } else if (event['action'] == 'skipText') {
        webService.skipText(
          textType: event['textType'],
          skipBy: event['skipBy'],
        );
      } else if (event['action'] == 'repeatText') {
        webService.repeatText(
          textType: event['textType'],
          repeatBy: event['repeatBy'],
        );
      } else if (event['action'] == "pauseTTS") {
        print("pause tts");
        webService.pauseTTS();
      } else if (event["action"] == "stopService") {
        service.stopBackgroundService();
        // Clear all document info
        webService.dispose();
        webService = WebpageService(flutterTts);
      }
    } else if (event['source'] == "pdf") {
      if (event['action'] == "openPDF") {
        pdfService.openPDF(path: event['path']);
      } else if (event['action'] == 'start') {
        pdfService.startReading(
          pgNo: event['pgNo'],
          sentenceIndex: event['sentenceIndex'],
        );
      } else if (event['action'] == 'readSpecific') {
        pdfService.readSpecificText(
          pgNo: event['pgNo'],
          sentenceIndex: event['sentenceIndex'],
        );
      } else if (event['action'] == "pauseTTS") {
        print("pause tts");
        pdfService.pauseTTS();
      } else if (event['action'] == 'skipText') {
        pdfService.skipText(
          textType: event['textType'],
          skipBy: event['skipBy'],
        );
      } else if (event['action'] == 'getPDFState') {
        pdfService.getPDFState();
      } else if (event['action'] == 'repeatText') {
        pdfService.repeatText(
          textType: event['textType'],
          repeatBy: event['repeatBy'],
        );
      } else if (event['action'] == 'setCurrentState') {
        pdfService.setCurrentState(
          pgNo: event['pgNo'],
          sentenceIndex: event['sentenceIndex'],
        );
      }
    }
  });

  service.setNotificationInfo(
    title: "My App Service",
    content: "Updated at ${DateTime.now()}",
  );
}

Future<void> initializeService() async {
  print("initializing service");
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will executed when app is in foreground or background in separated isolate
      onStart: onStart,
      // auto start service

      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: () => print("Not implemented on iOS"),
      onBackground: () => print("Not implemented on iOS"),
    ),
  );
  print("Service configured");
}
