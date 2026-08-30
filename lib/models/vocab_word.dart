/// A single saved vocabulary word, pulled from the local database.
class VocabWord {
  final int id;
  final String word;
  final String? sourceSentence;
  final String? videoPath;
  final String? videoTitle;
  final DateTime createdAt;

  const VocabWord({
    required this.id,
    required this.word,
    this.sourceSentence,
    this.videoPath,
    this.videoTitle,
    required this.createdAt,
  });

  factory VocabWord.fromMap(Map<String, Object?> map) {
    return VocabWord(
      id: map['id'] as int,
      word: map['word'] as String,
      sourceSentence: map['source_sentence'] as String?,
      videoPath: map['video_path'] as String?,
      videoTitle: map['video_title'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
