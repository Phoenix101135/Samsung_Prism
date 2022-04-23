import 'dart:async';
import 'dart:convert';
import 'package:bixby_app/backgroundServices/webpageService.dart';
import 'package:bixby_app/services/audioFocusHandler.dart';
import 'package:bixby_app/services/intentService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get_it/get_it.dart';
import 'package:uni_links/uni_links.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class WebpageView extends StatefulWidget {
  String url;
  String? deepLink;
  WebpageView({Key? key, required this.url, this.deepLink}) : super(key: key);

  @override
  _WebpageViewState createState() => _WebpageViewState();
}

class _WebpageViewState extends State<WebpageView> with WidgetsBindingObserver {
  String? url;
  FlutterTts flutterTts = FlutterTts();
  int curParaIndex = 0;
  int curSentenceIndex = 0;
  String textType = ""; // "PARAGRAPH" or "SENTENCE"
  String type = ""; // "RELATIVE or SPECIFIC"
  String actionType = "";
  WebViewController? _controllerWebView;
  bool isPlaying = false;
  String webViewScript = "";
  StreamSubscription? _uniLinksSubscription;
  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    _uniLinksSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    url = widget.url;
    initWebpageService();
    loadWebViewScript();
    listenToIntents();
    // listenToAudioFocus();
    listenToWebService();
    listenToFlutterTTSEvents();
    super.initState();
  }

  initWebpageService() {
    // data = widget.data;

    setState(() {});
    final service = FlutterBackgroundService();
    service
        .sendData({"source": "webpage", "action": "downloadHTML", "url": url});
  }

  loadWebViewScript() {
    rootBundle.loadString("assets/webview.js").then((script) {
      // print(script);
      print("script loaded");
      setState(() {
        webViewScript = script;
      });
    }).catchError((onError) {
      print(onError);
    });
  }

  listenToFlutterTTSEvents() {
    flutterTts.setStartHandler(() {
      setState(() {
        isPlaying = true;
      });
    });
    flutterTts.setCompletionHandler(() {
      setState(() {
        isPlaying = false;
      });
    });
    flutterTts.setCancelHandler(() {
      setState(() {
        isPlaying = false;
      });
    });
  }

  void listenToAudioFocus() {
    GetIt.I<AudioFocusHandler>().audioFocusStream!.stream.listen((event) {
      print("from website" + event);
      if (event == 'INTERRUPT') {
        // When bixby is launched / phone call is received
        flutterTts.stop();
      } else if (event == 'RESUME') {
        // When bixby is closed and audio focus is gained
      }
    });
  }

  void handleUriLinkStream(uri) async {
    // Invoked when Bixby sends a ShareVia Intent
    // await flutterTts.stop();
    String json = uri?.queryParameters['data'] ?? "{}";
    var data = jsonDecode(json);
    print(data);
    if (data.length == 0) return;

    // String message = data['Message'];
    String textType = data?['TextType'] ?? "SENTENCE";
    int index = data?['Index'] ?? 0;
    String type = data?['Type'] ?? "SPECIFIC";
    String actionType = data['ActionType'] ?? "START";
    print(data);

    if (actionType == "PAUSE") {
      return handlePauseAction();
    }
    if (actionType == "STOP") {
      return handleStopAction();
    }
    if (actionType == "START") {
      return handleStartAction(index, textType, type);
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

  void listenToIntents() {
    _uniLinksSubscription =
        uriLinkStream.asBroadcastStream().listen((uri) async {
      handleUriLinkStream(uri);
    });
  }

  void handleStartAction(index, textType, type) {
    /** Valid Utterances
     *  Read Aloud this document
     *  Read Aloud rest of this document
     *   
     *  Purpose: To start reading aloud from the first sentence of the first paragraph 
     *    Or To start reading from the first sentence of the paragraph visible on screen
     *  
     */
    setState(() {
      curSentenceIndex = 0;
      curParaIndex = 0;
      this.type = "RELATIVE";
    });
    passOnToJS();
  }

  void handleReadAction(index, String textType, String type) {
    // Here [index] is zero based index
    /** Valid Utterances
     *  [Specific]
     *  Go to paragraph 1 
     *  Go to sentence 3
     *  Purpose: To navigate to the absolute paragraph or sentence specified
     * 
     */

    final service = FlutterBackgroundService();
    setState(() {
      actionType = "READ";
    });
    print(textType);
    if (textType == "SENTENCE") {
      // Utterance - Go to sentence 3
      // action - read sentence 3 in the current paragraph

      service.sendData({
        "source": "webpage",
        "action": "readSpecific",
        "sentenceIndex": index
      });
    } else if (textType == "PARAGRAPH") {
      // Utterance - Go to paragraph 1
      // action - read the first paragraph
      service.sendData(
          {"source": "webpage", "action": "readSpecific", "paraIndex": index});
    }
  }

  void handleSkipAction(int index, String textType, String type) {
    /** Valid Utterances
     *  Skip this sentence (Index = 0+1 =1 )
     *  Skip this paragraph
     *  Skip 5 sentences (Index = 5+1 = 6)
     *  Purpose: To skip to the given number of sentences or paragraphs
     */

    print(index.toString() + " " + textType + " " + type);

    actionType = "READ";
    final service = FlutterBackgroundService();
    service.sendData({
      "source": "webpage",
      "action": "skipText",
      "skipBy": index,
      "textType": textType
    });
  }

  void handleRepeatAction(int index, String textType, String type) {
    /** Valid Utterances
     * Repeat last sentence
     * Repeat last paragraph
     * Repeat last 5 sentences
     * Repeat previous 5 paragraphs 
     *  Purpose: To repeat the given number of sentences or paragraphs before the current sentence or paragraph
     */
    print(curParaIndex.toString() +
        " " +
        index.toString() +
        " " +
        textType +
        " " +
        type);

    actionType = "READ";

    final service = FlutterBackgroundService();
    service.sendData({
      "source": "webpage",
      "action": "repeatText",
      "repeatBy": index,
      "textType": textType
    });
  }

  void listenToWebService() {
    FlutterBackgroundService().onDataReceived.listen((event) async {
      // Current state of the website
      if (event!['action'] == 'response' && event['source'] == 'webpage') {
        print("event in webpage view ! " + event.toString());
        await _controllerWebView?.runJavascript(webViewScript +
            '''
      highlightAndScrollToText({
        text:"${jsonDecode(event['text'])}",
        url:"${url}",
      } )''');
      }
    });
  }

  void handleStopAction() {
    final service = FlutterBackgroundService();
    service.sendData({actionType: "stopService", "source": "webpage"});
  }

  void handlePauseAction() {
    setState(() {
      actionType = "PAUSE";
    });
    FlutterBackgroundService()
        .sendData({actionType: "pauseTTS", "source": "webpage"});

    // flutterTts.stop();
  }

  Future passOnToJS() async {
    // setState(() {});
    // await flutterTts.stop();
    // while (_controllerWebView == null);
    await _controllerWebView!.runJavascript(webViewScript +
        '''
      getRequestedText({
        curParaIndex:${curParaIndex},
        curSentenceIndex:${curSentenceIndex},
        type:"${type}",
      } )''');

    // print('''
    //   curParaIndex:${curParaIndex},
    //     curSentenceIndex:${curSentenceIndex},
    //     textType:"${textType}",
    //     type:"${type}",
    //     actionType:"${actionType}"
    // ''');
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
        appBar: AppBar(
          title: const Text('Read Aloud'),
          actions: <Widget>[
            IconButton(
              icon: isPlaying ? Icon(Icons.stop) : Icon(Icons.play_arrow),
              onPressed: () async {
                handleStartAction(0, "PARAGRAPH",
                    "RELATIVE"); // Read from the text which is visible in the webview
              },
            ),
            IconButton(
              icon: Icon(Icons.pause),
              onPressed: () async {
                final service = FlutterBackgroundService();
                service.sendData({"source": "webpage", "action": "pauseTTS"});
              },
            ),
          ],
        ),
        body: WebView(
          initialUrl: url,
          javascriptChannels: Set.from([
            JavascriptChannel(
                name: 'WebViewTextSelectionChannel',
                onMessageReceived: (JavascriptMessage message) {}),
            JavascriptChannel(
                name: 'InitialStateUpdateChannel',
                onMessageReceived: (JavascriptMessage message) async {
                  int curSentenceIndex =
                      jsonDecode(message.message)['curSentenceIndex'];
                  int curParaIndex =
                      jsonDecode(message.message)['curParaIndex'];
                  String firstSentence =
                      jsonDecode(message.message)['firstSentence'];
                  final service = FlutterBackgroundService();
                  service.sendData({
                    "source": "webpage",
                    "action": "read",
                    "url": url,
                    "firstSentence": firstSentence,
                  });

                  setState(() {
                    this.curSentenceIndex = curSentenceIndex;
                    this.curParaIndex = curParaIndex;
                  });
                })
          ]),
          javascriptMode: JavascriptMode.unrestricted,
          onPageFinished: (String html) async {
            await _controllerWebView!.runJavascript(webViewScript +
                '''
                  splitAllParasIntoSentences()
                ''');
          },
          onWebViewCreated: (WebViewController webViewController) async {
            if (widget.deepLink != null) {
              handleUriLinkStream(Uri.parse(widget.deepLink!));
            }
            setState(() {
              _controllerWebView = webViewController;
            });
          },
        ),
      ),
    );
  }
}
