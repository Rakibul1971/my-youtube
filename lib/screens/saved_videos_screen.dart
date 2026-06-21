import 'package:flutter/material.dart';

import '../models/saved_video.dart';
import '../services/storage.dart';
import '../services/youtube_service.dart';
import '../utils/time_ago.dart';
import 'player_screen.dart';

/// Tab where the user saves individual videos by pasting their links.
class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  final _storage = Storage();
  final _yt = YoutubeService();

  List<SavedVideo> _videos = [];
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _videos = await _storage.loadVideos();
    setState(() => _booting = false);
  }

  Future<void> _addVideo() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _AddVideoDialog(),
    );
    if (input == null || input.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final video = await _yt.resolveVideo(input);
      if (_videos.any((v) => v.videoId == video.videoId)) {
        messenger.showSnackBar(
            const SnackBar(content: Text('That video is already saved.')));
        return;
      }
      setState(() => _videos = [video, ..._videos]);
      await _storage.saveVideos(_videos);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(SavedVideo v) async {
    setState(() =>
        _videos = _videos.where((x) => x.videoId != v.videoId).toList());
    await _storage.saveVideos(_videos);
  }

  void _open(SavedVideo v) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(video: v.toVideo())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved videos')),
      floatingActionButton: _videos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addVideo,
              icon: const Icon(Icons.add_link),
              label: const Text('Save link'),
            ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? _EmptyState(onAdd: _addVideo)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: _videos.length,
                  itemBuilder: (_, i) => _SavedVideoCard(
                    video: _videos[i],
                    onTap: () => _open(_videos[i]),
                    onRemove: () => _remove(_videos[i]),
                  ),
                ),
    );
  }
}

class _SavedVideoCard extends StatelessWidget {
  final SavedVideo video;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedVideoCard({
    required this.video,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      video.bestThumbnail,
                      width: 140,
                      height: 79,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        height: 79,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.play_arrow,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    if (video.channelTitle.isNotEmpty)
                      Text(
                        video.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    Text(
                      'Saved ${timeAgo(video.addedAt)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 72),
            const SizedBox(height: 16),
            Text('No saved videos',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Paste any YouTube video link to save it here for quick access.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_link),
              label: const Text('Save a link'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVideoDialog extends StatefulWidget {
  const _AddVideoDialog();

  @override
  State<_AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<_AddVideoDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save video link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://youtu.be/…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 8),
          Text(
            'Accepts watch, youtu.be, shorts, or embed links — or a bare '
            'video ID.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
