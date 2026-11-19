import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../widgets/common.dart';

/// One titled block of static, honest explanatory copy.
class InfoSection {
  const InfoSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

/// Generic static information page used for Privacy & Security, Help & Support
/// and About. All content is plain, factual copy about what the app actually
/// does on this device - nothing is presented as a server feature that does
/// not exist yet.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.sections});

  final String title;
  final List<InfoSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApsColors.bg,
      appBar: AppBar(
        backgroundColor: ApsColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: ApsText.title.copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          for (final section in sections) ...[
            ApsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.heading, style: ApsText.bodyBold),
                  for (var i = 0; i < section.paragraphs.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 6 : 8),
                      child: Text(
                        section.paragraphs[i],
                        style: ApsText.label.copyWith(height: 1.45),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                'APS Reader - Powered by Adverune',
                style: ApsText.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
