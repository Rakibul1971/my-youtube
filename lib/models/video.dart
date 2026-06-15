class Video {
  final String videoId;
  final String title;
  final String channelTitle;
  final DateTime? published;
  final String? thumbnail;

  Video({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    this.published,
    this.thumbnail,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  String get bestThumbnail =>
      thumbnail ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}
