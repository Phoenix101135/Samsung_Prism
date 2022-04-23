import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:bixby_app/services/audioFocusHandler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdf_text/pdf_text.dart';

class PDFService {
  late FlutterTts flutterTts;
  PDFDoc? _pdfDoc;
  int curPgNo = 1;
  int curSentenceIndex = 0;
  List<String> sentences = [];
  int pgnos = 0;
  String path = "";
  bool shouldStopReading = false;
  PDFService(FlutterTts flutterTts) {
    this.flutterTts = flutterTts;
    listenToAudioFocus();
  }

  Future<void> openPDF({String? path}) async {
    if (path == null) {
      return;
    }
    print("called me");
    this._pdfDoc = await PDFDoc.fromPath(path);
    this.pgnos = this._pdfDoc!.pages.length;
    this.path = path;
    print(path);
    print("pdf doc is ready");
  }

  void getPDFState() {
    print("sending current state information");
    if (this.path != "") {
      // Send current state only if the the pdf is loaded
      FlutterBackgroundService().sendData({
        "action": "PDFStateResponse",
        "source": "pdf",
        "path": this.path,
        "pgNo": this.curPgNo,
        "sentenceIndex": this.curSentenceIndex
      });
    }
  }

  void startReading({int? pgNo, int? sentenceIndex}) async {
    if (this._pdfDoc == null) {
      await parseText(pgNo ?? 1);
      // return;
    }
    await pauseTTS();
    readSpecificText(pgNo: (pgNo ?? 1), sentenceIndex: sentenceIndex);
  }

  void readSpecificText({
    int? pgNo,
    int? sentenceIndex,
  }) async {
    this.shouldStopReading = false;
    await flutterTts.stop();
    print("Sentences length " + this.sentences.length.toString());
    if (pgNo == null) {
      pgNo = this.curPgNo;
    }
    if (this.sentences.length == 0 || pgNo != this.curPgNo) {
      await parseText(pgNo);
    }

    if (sentenceIndex == null) {
      sentenceIndex = 0;
    }
    if (pgNo < 0 || sentenceIndex < 0) return;

    print("Read specific text " +
        pgNo.toString() +
        " " +
        sentenceIndex.toString());
    this.shouldStopReading = false;
    this.curPgNo = pgNo;
    this.curSentenceIndex = sentenceIndex;
    readSentenceFromPage(pgNo, sentenceIndex);
  }

  void readSentenceFromPage(int pageNo, int sentenceIndex) async {
    try {
      while (true) {
        if (this.shouldStopReading) return;

        print("Sentences " + this.sentences.length.toString());
        if (this.curSentenceIndex >= this.sentences.length) return;
        print(this.curSentenceIndex);

        String curSentenceText = this.sentences[this.curSentenceIndex];
        print(curSentenceText);
        await _speak(curSentenceText);

        if (this.curSentenceIndex == this.sentences.length - 1) {
          // Go to next page
          await parseText(this.curPgNo + 1);
          this.curPgNo = (this.curPgNo + 1);
          this.curSentenceIndex = 0;
        } else if (this.curSentenceIndex < this.sentences.length - 1) {
          // Go to next sentence
          this.curPgNo = this.curPgNo;
          this.curSentenceIndex = this.curSentenceIndex + 1;
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> parseText(int pgNo) async {
    // seperate text into sentences
    if (this._pdfDoc == null) {
      await openPDF(path: path);
    }
    if (pgNo > this.pgnos) {
      throw Exception("Page number is out of range");
    }
    this.shouldStopReading = true;
    print("Page no " + pgNo.toString());
    this.sentences = await getSentences(pgNo);

    print("Sentences temp length " + this.sentences.length.toString());
    this.shouldStopReading = false;
    // this.sentences = sentences;
  }

  Future<List<String>> getSentences(pgNo) async {
    List<String> sentences = [];
    String text = await _pdfDoc!.pageAt(pgNo).text;
    print(text);
    String sentence = "";
    sentences.clear();
    // List<String> sentences = [];
    List<String> tempSentences = [];
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '.') {
        sentence += text[i];
        tempSentences.add(sentence);
        if (tempSentences.join().length >= 40) {
          sentences.add(tempSentences.join().replaceAll('\n', ''));
          tempSentences.clear();
        }
        sentence = "";
      } else {
        sentence += text[i];
      }
    }
    if (sentence != "") {
      sentences.add(sentence);
    }
    return sentences;
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

  Future<void> _speak(String text) async {
    if (this.path != "") {
      FlutterBackgroundService().sendData({
        "action": "curStateResponse",
        "pgNo": this.curPgNo,
        "sentenceIndex": this.curSentenceIndex,
        "source": "pdf"
      });
    }
    text = jsonEncode(text);
    text = text.replaceAll('\\u0000', '');
    text = text.replaceAll('\\n', ' ');

    print(text);
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(text);
  }

  void skipText({String? textType, int? skipBy}) async {
    this.shouldStopReading = false;
    // print("Page no " + this.curPgNo.toString());
    if (sentences.length == 0) {
      await parseText(this.curPgNo);
    }
    if (skipBy == null) {
      skipBy = 1;
    }
    if (textType == "PAGE") {
      if (this.curPgNo + skipBy < this.pgnos) {
        this.curPgNo += skipBy;
        this.curSentenceIndex = 0;
        await parseText(this.curPgNo);
        readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
      }
    } else if (textType == "SENTENCE") {
      while (skipBy! > 0) {
        if (this.curSentenceIndex + skipBy < this.sentences.length) {
          this.curSentenceIndex += skipBy;
          skipBy = 0;
        } else {
          skipBy -= (this.sentences.length - this.curSentenceIndex);
          this.curPgNo++;
          await parseText(this.curPgNo);
          this.curSentenceIndex = 0;
        }
      }

      readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
    } else if (textType == "CHAPTER" || textType == "SECTION") {
      String type = "Chapter";
      if (textType == "SECTION") {
        type = "Section";
      }
      List chPosition = await getCurChapterPosition(type);
      int chPage = chPosition[0];
      int chSentenceIndex = chPosition[1];
      List relativeChPosition = await getRelativeChapterPosition(
          chPage, chSentenceIndex, skipBy, type);
      int relativeChPage = relativeChPosition[0];
      int relativeChSentenceIndex = relativeChPosition[1];
      this.curPgNo = relativeChPage;
      this.curSentenceIndex = relativeChSentenceIndex;
      await parseText(this.curPgNo);
      readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
    }
  }

  Future<List> getCurChapterPosition(String type) async {
    int chPgno = 1;
    String chName = "";
    for (int i = 0; i < _pdfDoc!.docMap.length; i++) {
      int pgNo = _pdfDoc!.docMap[i]['pgNo'];
      if (pgNo <= this.curPgNo && _pdfDoc!.docMap[i]['title'].contains(type)) {
        chPgno = pgNo;
        chName = _pdfDoc!.docMap[i]['title'];
      }
    }
    int chSentenceIndex = 0;
    List<String> chSentences = await getSentences(chPgno);
    for (int i = 0; i < chSentences.length; i++) {
      if (chSentences[i].contains(chName)) {
        chSentenceIndex = i;
        break;
      }
    }
    if (chSentenceIndex > this.curSentenceIndex) {
      // the section/chapter is in the previous pages
      for (int i = 0; i < _pdfDoc!.docMap.length; i++) {
        int pgNo = _pdfDoc!.docMap[i]['pgNo'];
        if (pgNo < this.curPgNo && _pdfDoc!.docMap[i]['title'].contains(type)) {
          chPgno = pgNo;
          chName = _pdfDoc!.docMap[i]['title'];
        }
      }
      chSentenceIndex = 0;
      List<String> chSentences = await getSentences(chPgno);
      for (int i = 0; i < chSentences.length; i++) {
        if (chSentences[i].contains(chName)) {
          chSentenceIndex = i;
          break;
        }
      }
    }
    return [chPgno, chSentenceIndex];
  }

  Future<List> getRelativeChapterPosition(
      int pgNo, int sentenceIndex, int relativeIndex, String type) async {
    int relativeChPgNo = pgNo;
    int relativeChSentenceIndex = sentenceIndex;
    String chName = "";
    if (relativeIndex < 0) {
      int i = 0;
      for (i = 0; i < _pdfDoc!.docMap.length; i++) {
        if (_pdfDoc!.docMap[i]['pgNo'] == pgNo &&
            _pdfDoc!.docMap[i]['title'].contains(type)) {
          break;
        }
      }

      for (; i >= 0 && relativeIndex <= 0; i--) {
        pgNo = _pdfDoc!.docMap[i]['pgNo'];
        if (_pdfDoc!.docMap[i]['title'].contains(type)) {
          relativeIndex++;
          relativeChPgNo = pgNo;
          chName = _pdfDoc!.docMap[i]['title'];
        }
      }
      List<String> chSentences = await getSentences(relativeChPgNo);
      for (int i = 0; i < chSentences.length; i++) {
        if (chSentences[i].contains(chName)) {
          relativeChSentenceIndex = i;
          break;
        }
      }
      return [relativeChPgNo, relativeChSentenceIndex];
    } else if (relativeIndex > 0) {
      int i = 0;
      for (i = 0; i < _pdfDoc!.docMap.length; i++) {
        if (_pdfDoc!.docMap[i]['pgNo'] == pgNo) {
          break;
        }
      }

      for (; i < _pdfDoc!.docMap.length && relativeIndex >= 0; i++) {
        pgNo = _pdfDoc!.docMap[i]['pgNo'];
        if (_pdfDoc!.docMap[i]['title'].contains(type) &&
            _pdfDoc!.docMap[i]['title'].contains(type)) {
          relativeIndex--;
          relativeChPgNo = pgNo;
          chName = _pdfDoc!.docMap[i]['title'];
        }
      }
      List<String> chSentences = await getSentences(relativeChPgNo);
      for (int i = 0; i < chSentences.length; i++) {
        if (chSentences[i].contains(chName)) {
          relativeChSentenceIndex = i;
          break;
        }
      }
      return [relativeChPgNo, relativeChSentenceIndex];
    } else {
      return [pgNo, sentenceIndex];
    }
  }

  void repeatText({String? textType, int? repeatBy}) async {
    shouldStopReading = true;
    if (repeatBy == null) {
      repeatBy = 0;
    }
    if (textType == "PAGE") {
      this.curPgNo -= repeatBy;
      this.curPgNo = max(1, this.curPgNo);
      await parseText(this.curPgNo);
      this.curSentenceIndex = 0;
      shouldStopReading = false;
      readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
    } else if (textType == "SENTENCE") {
      while (repeatBy! > 0) {
        if (this.curSentenceIndex - repeatBy >= 0) {
          this.curSentenceIndex -= repeatBy;
          repeatBy = 0;
        } else {
          this.curPgNo--;
          repeatBy -= (this.curSentenceIndex + 1);
          await parseText(this.curPgNo);
          this.curSentenceIndex = this.sentences.length - 1;
        }
      }
      shouldStopReading = false;
      readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
    } else if (textType == "CHAPTER" || textType == "SECTION") {
      String type = "Chapter";
      if (textType == "SECTION") {
        type = "Section";
      }
      List chPosition = await getCurChapterPosition(type);
      int chPage = chPosition[0];
      int chSentenceIndex = chPosition[1];
      List relativeChPosition = await getRelativeChapterPosition(
          chPage, chSentenceIndex, -repeatBy, type);
      int relativeChPage = relativeChPosition[0];
      int relativeChSentenceIndex = relativeChPosition[1];
      this.curPgNo = relativeChPage;
      this.curSentenceIndex = relativeChSentenceIndex;
      await parseText(this.curPgNo);
      shouldStopReading = false;
      readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
    }
  }

  void setCurrentState({int? pgNo, int? sentenceIndex}) {
    if (pgNo != null) {
      this.curPgNo = pgNo;
    }
    if (sentenceIndex != null) {
      this.curSentenceIndex = sentenceIndex;
    }
    parseText(this.curPgNo);
  }

  Future<void> pauseTTS() async {
    print("Pause TTS");
    shouldStopReading = true;
    await flutterTts.stop();
  }

  void dispose() async {
    flutterTts.stop();
    shouldStopReading = true;
    _pdfDoc = null;
    sentences.clear();
  }

  Future<void> stop() async {
    shouldStopReading = true;

    await flutterTts.stop();
  }
}
