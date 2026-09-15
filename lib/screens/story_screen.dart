import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/stories_data.dart';
import '../widgets/speak_button.dart';

/// One story: its full text, read aloud on request by the device's voice.
class StoryScreen extends StatelessWidget {
  final Story story;

  const StoryScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(story.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            SpeakButton(id: story.id, text: '${story.title}. ${story.body}', size: 22),
            const SizedBox(width: 12),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blackCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    story.body,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 2.0),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.goldBorder)),
                    ),
                    child: Text(
                      '📖 ${story.source}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.textGold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'القصة مرويّة بأسلوب مبسّط؛ نص الآيات والأحاديث كما وردت '
              'موجود في قسمَي القرآن والأحاديث بالتطبيق.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
