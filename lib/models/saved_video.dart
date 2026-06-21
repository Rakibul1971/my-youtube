import 'video.dart';

/// A single YouTube video the user saved by its link.
class SavedVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String? thumbnail;
  final DateTime addedAt;

  SavedVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    this.thumbnail,
    required this.addedAt,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  String get bestThumbnail =>
      thumbnail ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  /// Adapts a saved entry to the shared [Video] type used by the player.
  Video toVideo() => Video(
        videoId: videoId,
        title: title,
        channelTitle: channelTitle,
        thumbnail: thumbnail,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'channelTitle': channelTitle,
        'thumbnail': thumbnail,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SavedVideo.fromJson(Map<String, dynamic> json) => SavedVideo(
        videoId: json['videoId'] as String,
        title: json['title'] as String? ?? '(untitled)',
        channelTitle: json['channelTitle'] as String? ?? '',
        thumbnail: json['thumbnail'] as String?,
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
