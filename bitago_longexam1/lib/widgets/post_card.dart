import 'package:flutter/material.dart';
import '../models/post.dart';
import '../providers/likes_provider.dart';
import 'custom_dialogs.dart';
import 'custom_font.dart';
import 'custom_inkwell_button.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.likes,
    this.onOpen,
  });
  final Post post;
  final LikesProvider likes;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person_outline)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'User ${post.userId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Post #${post.id}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Text(post.body, style: CustomFont.body(context)),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: likes,
            builder: (context, _) {
              final liked = likes.contains('post_${post.id}');
              return Wrap(
                spacing: 8,
                children: [
                  CustomInkwellButton(
                    icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    label: '${post.likes + (liked ? 1 : 0)} likes',
                    selected: liked,
                    onTap: () async {
                      try {
                        await likes.toggle('post_${post.id}');
                      } catch (_) {
                        if (context.mounted) {
                          CustomDialogs.message(
                            context,
                            'Could not save your like.',
                          );
                        }
                      }
                    },
                  ),
                  if (onOpen != null)
                    CustomInkwellButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Comments',
                      onTap: onOpen!,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
