import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:bixby_app/services/audioFocusHandler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;

import 'package:audio_session/audio_session.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

class WebpageService {
  late FlutterTts flutterTts;
  Document? document;
  int curParaIndex = 0;
  int curSentenceIndex = 0;
  List<List<String>> paras = [];
  String? url = "";
  bool shouldStopReading = false;

  WebpageService(FlutterTts flutterTts) {
    this.flutterTts = flutterTts;
    print("WebpageService initialized");
    listenToAudioFocus();
  }

  void listenToAudioFocus() {
    AudioFocusHandler audioFocusHandler = AudioFocusHandler();
    audioFocusHandler.startAudioSession();
    audioFocusHandler.audioFocusStream!.stream.listen((event) {
      print("from website" + event);
      if (event == 'INTERRUPT') {
        // When bixby is launched / phone call is received
        pauseTTS();
      } else if (event == 'RESUME') {
        // When bixby is closed and audio focus is gained
      }
    });
  }

  Future<void> downloadHTML(String? url) async {
    try {
      this.url = url;
      print("downloading webpage");
      final response = await http.get(Uri.parse(url ?? ""));
      this.document = parse(response.body, generateSpans: true);
      List<Element> elements =
          this.document!.body!.querySelectorAll("h1,h2,h3,h4,h5,h6,title,p");
      /**
       * paras{
       * [ [],[] ],
       * [ [],[] ]
       * }
       * 
       */
      for (Element e in elements) {
        if (e.text.trim().length != 0) {
          this.paras.add(splitParaNodeIntoSentences(e));
        }
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> speakFromGivenFirstSentences(
      {String? url, String? firstSentence}) async {
    shouldStopReading = true;
    if (this.document == null) {
      await downloadHTML(url);
    }
    // int paraIndex = 0;
    print("paragraphs length " + paras.length.toString());
    print("firstSentence " + (firstSentence ?? ""));
    print(paras[1]);
    bool found = false;
    for (int paraIndex = 0; paraIndex < paras.length; paraIndex++) {
      for (String text in paras[paraIndex]) {
        if (text.contains(firstSentence!)) {
          await pauseTTS();
          shouldStopReading = false;
          readSentenceFromParagraph(paraIndex, 0);
          found = true;
          break;
        }
      }
      if (found) break;
    }
  }

  List<String> splitParaNodeIntoSentences(Element? paraNode) {
    List<String> sentenceNodes = [];
    String text = paraNode!.text;
    // print(text);
    List<String> result = text.split('.');
    if (result.length == 0) {
      result = [text];
    }
    for (int i = 0; i < result.length; i++) {
      if (result[i].trim().length != 0) sentenceNodes.add(result[i] + ".");
    }

    return sentenceNodes;
  }

  Future<void> readSentenceFromParagraph(
      int paraIndex, int sentenceIndex) async {
    if (paraIndex < 0 || paraIndex >= paras.length) return;
    print(paraIndex);
    // List<String> sentenceNodes =
    // splitParaNodeIntoSentences(elements[paraIndex]);
    if (shouldStopReading) return;
    String curSentenceText = paras[paraIndex][sentenceIndex];
    this.curParaIndex = paraIndex;
    this.curSentenceIndex = sentenceIndex;
    await _speak(curSentenceText);

    if (sentenceIndex == paras[paraIndex].length - 1) {
      // Go to next paragraphs
      readSentenceFromParagraph(paraIndex + 1, 0);
    } else if (sentenceIndex < paras[paraIndex].length - 1) {
      // Go to next sentence
      readSentenceFromParagraph(paraIndex, sentenceIndex + 1);
    }
    return;
  }

  void readSpecificText({
    int? paraIndex,
    int? sentenceIndex,
    textType,
  }) async {
    this.shouldStopReading = true;
    print("Paras length " + paras.length.toString());
    if (this.paras.length == 0) {
      await downloadHTML(this.url);
    }
    if (paraIndex == null) {
      paraIndex = this.curParaIndex;
    }
    if (sentenceIndex == null) {
      sentenceIndex = 0;
    }
    if (paraIndex < 0 || paraIndex >= this.paras.length || sentenceIndex < 0)
      return;

    print("Read specific text " +
        paraIndex.toString() +
        " " +
        sentenceIndex.toString());
    this.shouldStopReading = false;
    readSentenceFromParagraph(paraIndex, sentenceIndex);
  }

  void skipText({String? textType, int? skipBy}) async {
    shouldStopReading = false;
    // while (true) {
    if (shouldStopReading) return;
    if (textType == "PARAGRAPH") {
      if (skipBy == null) {
        skipBy = 1;
      }
      if (this.curParaIndex + skipBy < this.paras.length) {
        this.curParaIndex += skipBy;
        this.curSentenceIndex = 0;

        await readSentenceFromParagraph(
            this.curParaIndex, this.curSentenceIndex);
        // break;
      }
    } else if (textType == "SENTENCE") {
      if (skipBy == null) {
        skipBy = 1;
      }
      while (skipBy! > 0) {
        if (this.curSentenceIndex + skipBy <
            this.paras[this.curParaIndex].length) {
          this.curSentenceIndex += skipBy;
          skipBy = 0;
        } else {
          skipBy -=
              (this.paras[this.curParaIndex].length - this.curSentenceIndex);
          this.curParaIndex++;
          this.curSentenceIndex = 0;
        }
      }

      // if (this.curSentenceIndex + skipBy <
      //     this.paras[this.curParaIndex].length) {
      //   this.curSentenceIndex += skipBy;

      await readSentenceFromParagraph(this.curParaIndex, this.curSentenceIndex);
      // break;
      // } else {
      //   this.curParaIndex++;
      //   skipBy = skipBy -
      //       (this.paras[this.curParaIndex].length - this.curSentenceIndex);
      //   this.curSentenceIndex = 0;
      // textType = "SENTENCE";
      // skipText(
      //     textType: "SENTENCE",
      //     skipBy: skipBy -
      //         (this.paras[this.curParaIndex].length -
      //             this.curSentenceIndex));

    }
    // }
  }

  void repeatText({String? textType, int? repeatBy}) {
    shouldStopReading = true;
    if (textType == "PARAGRAPH") {
      if (repeatBy == null) {
        repeatBy = 1;
      }

      this.curParaIndex -= repeatBy;
      this.curParaIndex = max(0, this.curParaIndex);
      this.curSentenceIndex = 0;
      shouldStopReading = false;
      readSentenceFromParagraph(this.curParaIndex, this.curSentenceIndex);
    } else if (textType == "SENTENCE") {
      if (repeatBy == null) {
        repeatBy = 1;
      }

      while (repeatBy! > 0) {
        if (this.curSentenceIndex - repeatBy >= 0) {
          this.curSentenceIndex -= repeatBy;
          repeatBy = 0;
        } else {
          this.curParaIndex--;
          repeatBy -= (this.curSentenceIndex + 1);
          this.curSentenceIndex = this.paras[this.curParaIndex].length - 1;
        }
      }
      print(this.curParaIndex.toString() +
          " " +
          this.curSentenceIndex.toString());
      this.curSentenceIndex = max(0, this.curSentenceIndex);
      shouldStopReading = false;
      readSentenceFromParagraph(this.curParaIndex, this.curSentenceIndex);
    }
  }

  Future<void> _speak(String text) async {
    String temp = text.substring(0, text.length - 1);
    FlutterBackgroundService().sendData(
        {"action": "response", "text": jsonEncode(temp), "source": "webpage"});
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(text);
  }

  Future<void> pauseTTS() async {
    shouldStopReading = true;
    print("Pause TTS");
    await flutterTts.stop();
  }

  Future<void> stop() async {
    await flutterTts.stop();
  }

  void dispose() async {
    this.shouldStopReading = true;
    await flutterTts.stop();
    paras.clear();
  }
}
