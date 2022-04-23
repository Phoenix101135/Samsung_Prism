import 'dart:convert';
import 'dart:math';
import 'package:bixby_app/loadingDialog.dart';
import 'package:bixby_app/pdf/pdfPageView.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uni_links/uni_links.dart';

import 'package:pdf_text/pdf_text.dart';

class PDFIndexView extends StatefulWidget {
  String? deepLink;
  PDFIndexView({Key? key, this.deepLink}) : super(key: key);

  @override
  _PDFIndexViewState createState() => _PDFIndexViewState();
}

enum TtsState { playing, stopped, paused, continued }

class _PDFIndexViewState extends State<PDFIndexView> {
  PDFDoc? _pdfDoc;
  String? _text;
  int curPgNo = 1;
  int curSentenceIndex = 0;
  bool loading = false;
  StreamSubscription? pdfServiceSubcription;
  final GlobalKey<State> _keyLoader = new GlobalKey<State>();
  @override
  void initState() {
    super.initState();

    listenToIntents();
    initPDFService();
  }

  void openPDFinService(String path) {
    FlutterBackgroundService()
        .sendData({'action': 'openPDF', 'path': path, "source": "pdf"});
  }

  void initPDFService() {
    FlutterBackgroundService()
        .sendData({'action': 'getPDFState', 'source': "pdf"});
    pdfServiceSubcription =
        FlutterBackgroundService().onDataReceived.listen((event) async {
      print(event);
      if (event!['action'] == 'PDFStateResponse' &&
          event['source'] == 'pdf' &&
          event['path'] != null &&
          event['pgNo'] != null) {
        this._pdfDoc = await PDFDoc.fromPath(event['path'] ?? "");
        setState(() {});
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          navigateToText(event['pgNo'], event['sentenceIndex']);
          if (widget.deepLink != null) {
            handleUriLinkStream(Uri.parse(widget.deepLink!));
          }
        });
      }
    });
  }

  void navigateToText(int pgNo, int sentenceIndex) {
    setCurrentPage(pgNo);
    Navigator.push(
        context,
        new MaterialPageRoute(
            builder: (context) => PDFPageView(
                  pgNo: pgNo,
                  sentenceIndex: sentenceIndex,
                  getCurPageText: getCurPageText,
                  setCurrentPage: setCurrentPage,
                  setCurrentSentenceIndex: setCurrentSentenceIndex,
                  // setCurrentState: setCurrentState
                )));
  }

  void handleUriLinkStream(uri) async {
    // Invoked when Bixby sends a ShareVia Intent
    if (uri == null || uri.path == null) return;
    String json = uri?.queryParameters['data'] ?? "{}";
    var data = jsonDecode(json);
    if (data.length == 0) return;
    print(data);

    // String message = data['Message'];
    String textType = data?['TextType'] ?? "SENTENCE";
    double index = data?['Index']?.toDouble() ?? 0;
    String type = data?['Type'] ?? "SPECIFIC";
    String actionType = data['ActionType'] ?? "START";
    if (textType == "PARAGRAPH") {
      textType = "SENTENCE";
    }
    print(data);

    if (actionType == "PAUSE") {
      // return handlePauseAction();
    }
    if (actionType == "STOP") {
      // return handleStopAction();
    }
    if (actionType == "START") {
      return handleStartAction(textType, type);
    }

    if (type == "SPECIFIC") {
      if (actionType == "READ") {
        handleReadAction(index, textType, type);
      }
    } else {
      if (actionType == "READ") {
        handleReadAction(index, textType, type);
      } else if (actionType == "SKIP") {
        handleSkipAction(index, textType, type);
      } else if (actionType == "REPEAT") {
        handleRepeatAction(index, textType, type);
      }
    }
  }

  void handleStartAction(textType, type) async {
    /** Valid Utterances
     *  Read Aloud this document
     *  Read Aloud rest of this document
     *   
     *  Purpose: To start reading aloud from the first sentence of the first paragraph 
     *    Or To start reading from the first sentence of the paragraph visible on screen
     *  
     */
    if (type == "SPECIFIC") {
      // read aloud this document (start from 1st page)
      print("handle Start action!");
      handleReadAction(1, "PAGE", "SPECIFIC");
      navigateToText(1, 0);
    } else if (type == "RELATIVE") {
      // Read aloud rest of this document (Start from sentence visible on screen)
      // Read from here

      FlutterBackgroundService().sendData({
        'action': 'start',
        'source': "pdf",
        'sentenceIndex': curSentenceIndex,
        'pgNo': curPgNo
      });
    }
  }

  void handleReadAction(num index, String textType, String type) async {
    /** Valid Utterances
     *  [Specific]
     *  Go to page 1 
     *  Go to sentence 3
     *  Purpose: To navigate to the page or sentence specified
     * 
     */

    print(textType);
    if (textType == "PAGE") {
      FlutterBackgroundService().sendData({
        "source": "pdf",
        "action": "readSpecific",
        "pgNo": index,
        "sentenceIndex": 0
      });
    } else if (textType == "SENTENCE") {
      // int pgno = await getPgNo();
      FlutterBackgroundService().sendData({
        "source": "pdf",
        "action": "readSpecific",
        "sentenceIndex": index,
        "pgNo": this.curPgNo,
      });
    } else if (textType == "SECTION" || textType == "CHAPTER") {
      print("HERE");
      int sectionSentenceIndex = 0;
      int sectionPgNo = 1;
      if (textType == "SECTION") {
        textType = "Section";
      } else {
        textType = "Chapter";
        index = index.toInt();
      }
      // find sentence index and page number of the given section index
      _pdfDoc!.docMap.forEach((value) {
        String title = value['title'];
        if (title.contains(textType + " " + index.toString())) {
          sectionPgNo = value['pgNo'];
        }
      });

      // find sentence index of the given section text from page sectionPgNo
      String text = await getCurPageText(sectionPgNo);

      String sentence = "";

      List<String> tempSentences = [];
      int curInd = 0;
      for (int i = 0; i < text.length; i++) {
        if (text[i] == '.') {
          sentence += text[i];
          tempSentences.add(sentence);
          if (tempSentences.join().length >= 40) {
            // this.sentences.add(tempSentences.join().replaceAll('\n', ''));
            if (tempSentences
                .join()
                .contains(textType + ' ' + index.toString())) {
              sectionSentenceIndex = curInd;
              print(tempSentences.join());
              sentence = "";
              break;
            }
            tempSentences.clear();
            curInd++;
            sentence = "";
          }
        } else {
          sentence += text[i];
        }
      }
      if (sentence != "") {
        if (sentence.contains(textType + ' ' + index.toString())) {
          sectionSentenceIndex = curInd;
        }
      }

      FlutterBackgroundService().sendData({
        "source": "pdf",
        "action": "readSpecific",
        "sentenceIndex": sectionSentenceIndex,
        "pgNo": sectionPgNo,
      });
      // navigateToText(sectionPgNo, sectionSentenceIndex);
    }
  }

  void handleSkipAction(double index, String textType, String type) {
    /** Valid Utterances
     *  Skip this sentence (Index = 0+1 =1 )
     *  Skip this page
     *  Skip 5 sentences (Index = 5+1 = 6)
     *  Purpose: To skip to the given number of sentences or pages
     */

    print(index.toString() + " " + textType + " " + type);

    final service = FlutterBackgroundService();
    service.sendData({
      "source": "pdf",
      "action": "setCurrentState",
      "pgNo": this.curPgNo,
      "sentenceIndex": this.curSentenceIndex,
    });
    service.sendData({
      "source": "pdf",
      "action": "skipText",
      "skipBy": index.toInt(),
      "textType": textType,
      "pgNo": curPgNo,
    });
  }

  void handleRepeatAction(double index, String textType, String type) {
    /** Valid Utterances
     * Repeat last sentence
     * Repeat last page
     * Repeat last 5 sentences
     * Repeat previous 5 sentences 
     *  Purpose: To repeat the given number of sentences or pages before the current sentence or page
     */

    final service = FlutterBackgroundService();
    service.sendData({
      "source": "pdf",
      "action": "repeatText",
      "repeatBy": index.toInt(),
      "textType": textType
    });
  }

  void listenToIntents() {
    uriLinkStream.asBroadcastStream().listen((uri) async {
      handleUriLinkStream(uri);
    });
  }

  Future<String> getCurPageText(pgno) async {
    if (pgno <= 0 || pgno > _pdfDoc!.docMap.length) {
      throw ("Invalid Page Number");
    }
    try {
      String text = await _pdfDoc!.pageAt(pgno).text;
      print("geting next page text");
      if (text == "") {
        text = "PDF Document ends here.";
      }
      return text;
    } catch (e) {
      throw (e);
    }
  }

  void setCurrentPage(pgNo) {
    this.curPgNo = pgNo;
  }

  void setCurrentSentenceIndex(sentenceIndex) {
    this.curSentenceIndex = sentenceIndex;
  }

  @override
  void dispose() {
    pdfServiceSubcription?.cancel();
    super.dispose();
  }

  void clearState() {
    FlutterBackgroundService().sendData({
      "action": "disposeAll",
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        clearState();
        return true;
      },
      child: Scaffold(
        // key: _keyLoader,
        appBar: AppBar(
          title: Text('PDF View'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_outlined),
            iconSize: 20.0,
            onPressed: () {
              clearState();
              Navigator.pop(context);
            },
          ),
        ),
        body: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(10),
          child: ListView(
            children: <Widget>[
              TextButton(
                child: Text(
                  "Pick PDF document",
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.all(5),
                    backgroundColor: Colors.blueAccent),
                onPressed: _pickPDFText,
              ),

              Padding(
                child: Text(
                  _pdfDoc == null
                      ? "Pick a new PDF document and wait for it to load..."
                      : "PDF document loaded, ${_pdfDoc!.length} pages\n",
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                padding: EdgeInsets.all(15),
              ),
              Padding(
                child: Text(
                  _text == "" ? "" : "Table of Contents",
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                padding: EdgeInsets.all(15),
              ),
              // Text(_text.toString()),
              _pdfDoc == null
                  ? Container()
                  : SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        // shrinkWrap: true,
                        itemCount: _pdfDoc?.docMap.length ?? 0,
                        itemBuilder: (BuildContext context, int index) {
                          double leftPadding =
                              (_pdfDoc?.docMap[index]['level'] ?? 0.0) * 20.0;

                          return ListTile(
                            title: Padding(
                              padding:
                                  EdgeInsets.fromLTRB(leftPadding, 0, 0, 0),
                              child: Text(
                                _pdfDoc?.docMap[index]['title'] ?? "",
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            trailing: Text(
                              _pdfDoc?.docMap[index]['pgNo'].toString() ?? "",
                              style: TextStyle(fontSize: 18),
                            ),
                            enabled: _pdfDoc?.docMap[index]["pgNo"] == -1
                                ? false
                                : true,
                            onTap: () async {
                              int pgno = (_pdfDoc?.docMap[index]['pgNo'] ?? 0);
                              // TODO : find sentence Index of chapter / section
                              navigateToText(pgno, 0);
                            },
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks a new PDF document from the device
  Future _pickPDFText() async {
    var filePickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (filePickerResult != null) {
      setState(() {
        loading = true;
      });
      loadingDialog.showLoadingDialog(context, _keyLoader); //invoking login

      _pdfDoc = await PDFDoc.fromPath(filePickerResult.files.first.path ?? "");
      // _text = await _pdfDoc!.text;
      openPDFinService(filePickerResult.files.first.path ?? "");
      Navigator.of(context, rootNavigator: true).pop(); //close the dialoge
      setState(() {});
    }
  }
}
