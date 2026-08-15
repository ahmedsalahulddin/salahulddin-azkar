import 'package:just_audio/just_audio.dart';

/// The one audio player the whole app shares.
///
/// just_audio_background supports exactly one AudioPlayer instance — its own
/// words: "the simple use case where an app has a single AudioPlayer". Every
/// screen creating its own player worked only until two of them met, and the
/// meeting was guaranteed: recitation in one tab, a dhikr in another, the
/// radio behind both. One player also means one sound at a time everywhere,
/// which is what a listener wants anyway.
class AppAudio {
  AppAudio._();

  static final player = AudioPlayer();

  /// The tag id of whatever is loaded, or null. Screens use this to tell
  /// their own playback from a sibling's after the player changed hands.
  static String? currentId() {
    final tag = player.sequenceState.currentSource?.tag;
    if (tag == null) return null;
    return (tag as dynamic).id as String?;
  }

  /// Whether what is loaded belongs to [owner].
  ///
  /// Since one player serves the whole app, "something is loaded" no longer
  /// means "my playlist is loaded" — a screen that assumes so will seek into
  /// whatever the last screen left behind, and play the radio while showing
  /// its own reciter's name. Every screen asks this before reusing what is
  /// there.
  static bool ownsCurrent(String owner) =>
      currentId()?.startsWith(owner) ?? false;
}
