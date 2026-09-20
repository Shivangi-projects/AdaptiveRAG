class ChunkItem {
  final int id;
  final int docId;
  final int chunkIndex;
  final int pageNum;
  final String content;
  final double score;
  final String filename;

  ChunkItem({
    required this.id,
    required this.docId,
    required this.chunkIndex,
    required this.pageNum,
    required this.content,
    this.score = 0.0,
    this.filename = '',
  });

  factory ChunkItem.fromJson(Map<String, dynamic> json) {
    return ChunkItem(
      id: json['chunk_id'] as int? ?? json['id'] as int? ?? 0,
      docId: json['doc_id'] as int? ?? 0,
      chunkIndex: json['chunk_index'] as int? ?? 0,
      pageNum: json['page_num'] as int? ?? 1,
      content: json['content'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      filename: json['filename'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chunk_id': id,
      'doc_id': docId,
      'chunk_index': chunkIndex,
      'page_num': pageNum,
      'content': content,
      'score': score,
      'filename': filename,
    };
  }
}
