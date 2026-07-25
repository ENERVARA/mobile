import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';
import '../widgets/page_header.dart';

/// Temporary in-shell page body used while individual screens are built out.
class PlaceholderBody extends StatelessWidget {
  final String title;
  final String subtitle;
  const PlaceholderBody({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
        children: [
          PageHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 40),
          Center(
            child: Text('Coming together…', style: TextStyle(color: context.tokens.ink3)),
          ),
        ],
      ),
    );
  }
}
