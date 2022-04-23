import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class PDFPageView extends StatefulWidget {
  Function getCurPageText;
  Function setCurrentPage;
  Function setCurrentSentenceIndex;
  int pgNo;
  int sentenceIndex;
  PDFPageView(
      {required this.getCurPageText,
      required this.setCurrentPage,
      required this.sentenceIndex,
      required this.setCurrentSentenceIndex,
      required this.pgNo});
  @override
  _PDFPageViewState createState() => _PDFPageViewState();
}

class _PDFPageViewState extends State<PDFPageView> {
  int curSentenceIndex = 0;
  int curPgNo = 1;
  List<String> sentences = [];
  late AutoScrollController? controller;
  bool isPlaying = false;
  StreamSubscription? pdfServiceSubscription;
  int bottomNavBarIndex = 0;
  bool pageLoading = false;
  // Function? setCurrentPage ;
  @override
  void initState() {
    super.initState();
    // initCurrentState();
    curPgNo = widget.pgNo;
    // setCurrentPage =  widget.setCurrentPage;
    _loadPage(widget.pgNo, widget.sentenceIndex, false);
    listenToPDFService();
    curSentenceIndex = widget.sentenceIndex;
    controller = AutoScrollController(
        viewportBoundaryGetter: () =>
            Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
        axis: Axis.vertical);
  }

  // void initCurrentState() {
  // widget.setCurrentState(
  //   pgNo: widget.pgNo,
  //   sentenceIndex: widget.sentenceIndex,
  // );
  // }

  void _loadPage(int pgno, int sentenceIndex, bool nextPage) async {
    setState(() {
      pageLoading = true;
    });
    try {
      widget.setCurrentPage(pgno);
      widget.setCurrentSentenceIndex(sentenceIndex);
      String text = await widget.getCurPageText(pgno);
      // if (nextPage) this.curSentenceIndex = 0;
      this.curPgNo = pgno;
      this.curSentenceIndex = sentenceIndex;
      setState(() {});
      // widget.setCurrentState(
      // pgNo: this.curPgNo,
      //   sentenceIndex: this.curSentenceIndex,
      // );

      parseText(text);
      scroll(sentenceIndex);
    } catch (e) {
      setState(() {
        pageLoading = false;
      });
      _alertEndOfPage(pgno);
    }
  }

  void listenToPDFService() {
    pdfServiceSubscription =
        FlutterBackgroundService().onDataReceived.listen((event) async {
      if (event!['action'] == 'curStateResponse' && event['source'] == 'pdf') {
        if (event['pgNo'] == this.curPgNo) {
          // same page
          this.curSentenceIndex = event['sentenceIndex'];
          if (sentences.length != 0 &&
              this.curSentenceIndex >= sentences.length) {
            _alertEndOfPage(this.curPgNo);
          }
          widget.setCurrentSentenceIndex(
            this.curSentenceIndex,
          );
          scroll(this.curSentenceIndex);
          setState(() {});
          // readSentenceFromPage(this.curPgNo, this.curSentenceIndex);
        } else {
          // new page
          _loadPage(event['pgNo'], event['sentenceIndex'], true);
        }
      }
    });
  }

  void parseText(text) {
    // seperate text into sentences
    // print(text.toString());
    String sentence = "";
    sentences.clear();
    List<String> tempSentences = [];
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '.') {
        sentence += text[i];
        tempSentences.add(sentence);
        if (tempSentences.join().length >= 40) {
          this.sentences.add(tempSentences.join().replaceAll('\n', ''));
          tempSentences.clear();
        }
        sentence = "";
      } else {
        sentence += text[i];
      }
    }
    if (sentence != "") {
      sentence = sentence.replaceAll('\n', '');

      sentences.add(sentence);
    }

    for (int i = 0; i < sentences.length; i++) {
      print(sentences[i]);
    }

    pageLoading = false;
    setState(() {});
  }

  void scroll(index) {
    controller?.scrollToIndex(index,
        preferPosition: AutoScrollPosition.begin,
        duration: Duration(milliseconds: 500));
  }

  _alertEndOfPage(i) async {
    print("End of PDF");
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("End of PDF"),
            content: Text("No more pages"),
            actions: <Widget>[
              ElevatedButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            ],
          );
        });
    print(e);
  }

  _pauseTTS() {
    FlutterBackgroundService()
        .sendData({"action": "pauseTTS", "source": "pdf"});
  }

  // Future _speak() async {
  //   print(this.curPgNo);
  //   print(this.curSentenceIndex);
  //   // widget.setCurrentState(
  //   //   pgNo: this.curPgNo,
  //   //   sentenceIndex: this.curSentenceIndex,
  //   // );
  //   FlutterBackgroundService().sendData({
  //     'action': 'readSpecific',
  //     'source': "pdf",
  //     'sentenceIndex': this.curSentenceIndex,
  //     'pgNo': this.curPgNo
  //   });
  // }

  @override
  void dispose() {
    pdfServiceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Page " + curPgNo.toString()),
          actions: [
            Container(
              child: pageLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : null,
              height: 10,
              width: 56,
              padding: EdgeInsets.all(15),
            ),
            // Icon(Icons.refresh)
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: bottomNavBarIndex,
          onTap: (index) async {
            if (index == 0) {
              _loadPage(curPgNo - 1, 0, true);

              // } else if (index == 1) {
              // _speak();
            } else if (index == 1) {
              _pauseTTS();
            } else {
              _loadPage(curPgNo + 1, 0, true);
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.arrow_left),
              label: 'Previous Page',
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.play_arrow),
            //   label: 'Start',
            // ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stop),
              label: 'Stop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.arrow_right),
              label: 'Next Page',
            ),
          ],
        ),
        body: sentences.length == 0
            ? CircularProgressIndicator()
            : ListView.builder(
                controller: controller,
                itemBuilder: (context, index) {
                  return AutoScrollTag(
                    key: ValueKey(index),
                    controller: controller!,
                    index: index,
                    child: ListTile(
                      onLongPress: () async {
                        // var result = await flutterTts.stop();
                      },
                      tileColor: curSentenceIndex == index
                          ? Colors.lightBlueAccent.withOpacity(0.1)
                          : null,
                      // leading: Text(index.toString()),
                      title: Text(this.sentences[index]),
                      onTap: () {
                        setState(() {
                          curSentenceIndex = index;
                        });
                        widget.setCurrentSentenceIndex(
                          this.curSentenceIndex,
                        );
                      },
                    ),
                    highlightColor: Colors.black.withOpacity(0.1),
                  );
                },
                itemCount: this.sentences.length,
              ));
  }
}
