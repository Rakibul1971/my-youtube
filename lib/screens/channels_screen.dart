import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/video.dart';
import '../services/settings_controller.dart';
import '../services/storage.dart';
import '../services/youtube_service.dart';
import '../utils/time_ago.dart';
import 'player_screen.dart';

/// Tab that lists subscribed channels and their latest videos.
class ChannelsScreen extends StatefulWidget {
  final SettingsController settings;
  const ChannelsScreen({super.key, required this.settings});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _storage = Storage();
  final _yt = YoutubeService();

  List<Channel> _channels = [];
  final Map<String, List<Video>> _videos = {};
  final Set<String> _loading = {};
  bool _booting = true;
  late int _limit = widget.settings.videosPerChannel;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _boot();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Reload feeds when the "videos per channel" preference changes.
  void _onSettingsChanged() {
    if (widget.settings.videosPerChannel == _limit) return;
    _limit = widget.settings.videosPerChannel;
    _refreshAll();
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
      final (_, videos) = await _yt.fetchFeed(c.channelId, limit: _limit);
      _videos[c.channelId] = videos;
      if (c.thumbnail == null) await _backfillAvatar(c);
    } catch (_) {
      _videos[c.channelId] = [];
    } finally {
      if (mounted) setState(() => _loading.remove(c.channelId));
    }
  }

  /// Fetches and caches a channel's avatar the first time it's missing.
  Future<void> _backfillAvatar(Channel c) async {
    final avatar = await _yt.fetchChannelAvatar(c.channelId);
    if (avatar == null || !mounted) return;
    setState(() {
      _channels = _channels
          .map((x) =>
              x.channelId == c.channelId ? x.copyWith(thumbnail: avatar) : x)
          .toList();
    });
    await _storage.save(_channels);
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
      final (channel, videos) = await _yt.fetchFeed(id, limit: _limit);
      final avatar = await _yt.fetchChannelAvatar(id);
      setState(() {
        _channels = [..._channels, channel.copyWith(thumbnail: avatar)];
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
      floatingActionButton: _channels.isEmpty
          ? null
          : FloatingActionButton.extended(
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: _channels.length,
                    itemBuilder: (_, i) => _ChannelSection(
                      channel: _channels[i],
                      videos: _videos[_channels[i].channelId] ?? const [],
                      loading: _loading.contains(_channels[i].channelId),
                      limit: _limit,
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
  final int limit;
  final VoidCallback onRemove;
  final ValueChanged<Video> onOpenVideo;

  const _ChannelSection({
    required this.channel,
    required this.videos,
    required this.loading,
    required this.limit,
    required this.onRemove,
    required this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              backgroundImage: (channel.thumbnail != null)
                  ? NetworkImage(channel.thumbnail!)
                  : null,
              child: (channel.thumbnail == null)
                  ? Text(channel.title.isNotEmpty
                      ? channel.title.characters.first.toUpperCase()
                      : '?')
                  : null,
            ),
            title: Text(channel.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Latest ${limit == 1 ? 'video' : '$limit videos'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (_) => onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Remove channel'),
                  ),
                ),
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
            ...videos.map(
                (v) => _VideoTile(video: v, onTap: () => onOpenVideo(v))),
          const SizedBox(height: 4),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(url: video.bestThumbnail),
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
                      timeAgo(video.published!),
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
}

/// 16:9 thumbnail with rounded corners, a play badge, and graceful fallback.
class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            url,
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
              child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
            ),
          ),
        ],
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
            const Icon(Icons.subscriptions_outlined, size: 72),
            const SizedBox(height: 16),
            Text('No channels yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Add a channel by its link, @handle, or UC… ID to see its '
              'latest videos.',
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
