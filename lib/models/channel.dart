class Channel {
  final String channelId;
  final String title;
  final String? thumbnail;

  Channel({required this.channelId, required this.title, this.thumbnail});

  Channel copyWith({String? title, String? thumbnail}) => Channel(
        channelId: channelId,
        title: title ?? this.title,
        thumbnail: thumbnail ?? this.thumbnail,
      );

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'title': title,
        'thumbnail': thumbnail,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        channelId: json['channelId'] as String,
        title: json['title'] as String? ?? json['channelId'] as String,
        thumbnail: json['thumbnail'] as String?,
      );
}
