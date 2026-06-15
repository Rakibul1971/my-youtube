import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/video.dart';
import '../services/storage.dart';
import '../services/youtube_service.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = Storage();
  final _yt = YoutubeService();

  List<Channel> _channels = [];
  final Map<String, List<Video>> _videos = {};
  final Set<String> _loading = {};
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _channels = await _storage.load();
    setState(() => _booting = false);
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait(_channels.map(_loadChannel));
  }

  Future<void> _loadChannel(Channel c) async {
    setState(() => _loading.add(c.channelId));
    try {
      final (_, videos) = await _yt.fetchFeed(c.channelId, limit: 3);
      _videos[c.channelId] = videos;
    } catch (_) {
      _videos[c.channelId] = [];
    } finally {
      if (mounted) setState(() => _loading.remove(c.channelId));
    }
  }

  Future<void> _addChannel() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _AddChannelDialog(),
    );
    if (input == null || input.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await _yt.resolveChannelId(input);
      if (_channels.any((c) => c.channelId == id)) {
        messenger.showSnackBar(
            const SnackBar(content: Text('That channel is already added.')));
        return;
      }
      final (channel, videos) = await _yt.fetchFeed(id, limit: 3);
      setState(() {
        _channels = [..._channels, channel];
        _videos[id] = videos;
      });
      await _storage.save(_channels);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeChannel(Channel c) async {
    setState(() {
      _channels = _channels.where((x) => x.channelId != c.channelId).toList();
      _videos.remove(c.channelId);
    });
    await _storage.save(_channels);
  }

  void _openVideo(Video v) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(video: v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My YouTube'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _channels.isEmpty ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChannel,
        icon: const Icon(Icons.add),
        label: const Text('Add channel'),
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : _channels.isEmpty
              ? _EmptyState(onAdd: _addChannel)
              : RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _channels.length,
                    itemBuilder: (_, i) => _ChannelSection(
                      channel: _channels[i],
                      videos: _videos[_channels[i].channelId] ?? const [],
                      loading: _loading.contains(_channels[i].channelId),
                      onRemove: () => _removeChannel(_channels[i]),
                      onOpenVideo: _openVideo,
                    ),
                  ),
                ),
    );
  }
}

class _ChannelSection extends StatelessWidget {
  final Channel channel;
  final List<Video> videos;
  final bool loading;
  final VoidCallback onRemove;
  final ValueChanged<Video> onOpenVideo;

  const _ChannelSection({
    required this.channel,
    required this.videos,
    required this.loading,
    required this.onRemove,
    required this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            child: Text(channel.title.isNotEmpty
                ? channel.title.characters.first.toUpperCase()
                : '?'),
          ),
          title: Text(channel.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Latest 3 videos'),
          trailing: PopupMenuButton<String>(
            onSelected: (_) => onRemove(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove channel')),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (videos.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('No videos found.'),
          )
        else
          ...videos.map((v) => _VideoTile(video: v, onTap: () => onOpenVideo(v))),
        const Divider(height: 1),
      ],
    );
  }
}

class _VideoTile extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;

  const _VideoTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
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
                  if (video.published != null)
                    Text(
                      _timeAgo(video.published!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays >= 365) return '${(d.inDays / 365).floor()}y ago';
    if (d.inDays >= 30) return '${(d.inDays / 30).floor()}mo ago';
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
    return 'just now';
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
            const Icon(Icons.subscriptions_outlined, size: 72),
            const SizedBox(height: 16),
            Text('No channels yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Add a channel by its link, @handle, or UC… ID to see its 3 latest videos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a channel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChannelDialog extends StatefulWidget {
  const _AddChannelDialog();

  @override
  State<_AddChannelDialog> createState() => _AddChannelDialogState();
}

class _AddChannelDialogState extends State<_AddChannelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add channel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '@MrBeast or a channel URL/ID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 8),
          Text(
            'Accepts: @handle, youtube.com/… link, or a UC… channel ID.',
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}
