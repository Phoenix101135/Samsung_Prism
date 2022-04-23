import 'dart:async';

// import 'package:audio_focus/audio_focus.dart';
import 'package:audio_session/audio_session.dart';

class AudioFocusHandler {
  // AudioFocus audioFocus = AudioFocus();
  StreamController<String>? audioFocusStream;
  AudioSession? session;

  Future<void> initAudioSession() async {
    print("AUDIO SESSION!");
    session = await AudioSession.instance;
    await session!.configure(AudioSessionConfiguration.speech());
  }

  void startAudioSession() async {
    // Activate the audio session before playing audio.
    if (session == null) {
      await initAudioSession();
    }
    if (await session!.setActive(true)) {
      print("Audio session activated");
      // Now play audio.
    } else {
      // The request was denied and the app should not play audio
    }
  }

  AudioFocusHandler() {
    audioFocusStream = new StreamController.broadcast();

    initAudioSession().then((value) {
      session?.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
            // Another app started playing audio and we should duck (lower the volume).
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Another app started playing audio and we should pause.
              audioFocusStream?.add("INTERRUPT");
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
            // The interruption ended and we should unduck.
            case AudioInterruptionType.pause:
            // The interruption ended and we should resume.
            case AudioInterruptionType.unknown:
              // The interruption ended but we should not resume.
              audioFocusStream?.add("RESUME");

              break;
          }
        }
      });
    });

    // audioFocus.audioFocusEvents.listen((focusEvent) {
    //   if (focusEvent == AudioState.AUDIOFOCUS_GAIN) {
    //     audioFocusStream!.add("AUDIOFOCUS_GAIN");
    //     print("gained focus");
    //   } else if (focusEvent == AudioState.BECOME_NOISY) {
    //     audioFocusStream!.add("BECOME_NOISY");
    //     //Do Something
    //     print("become noisy");
    //   } else if (focusEvent == AudioState.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK) {
    //     //Do Something
    //     audioFocusStream!.add("AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK");

    //     print("AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK");
    //   } else if (focusEvent == AudioState.AUDIOFOCUS_LOSS_TRANSIENT) {
    //     //Do Something
    //     audioFocusStream!.add("BIXBY_OPEN");
    //     print("bixby opened");
    //   }
    // });
  }
}
