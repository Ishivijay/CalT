import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/calt_logo_mark.dart';
import 'package:opennutritracker/features/ai_insights/presentation/coach_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class HomeAppbar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const SizedBox(width: 40, child: CaltLogoMark()),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: S.of(context).appTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          identifier: 'home-ask-calt',
          child: IconButton(
            tooltip: 'Ask CalT',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CoachScreen(scrollToAsk: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
