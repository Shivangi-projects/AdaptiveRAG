class DocumentItem {
  final int id;
  final String filename;
  final String fileHash;
  final String fileType;
  final int pageCount;
  final int chunkCount;
  final String dateAdded;
  final int fileSize;

  DocumentItem({
    required this.id,
    required this.filename,
    required this.fileHash,
    required this.fileType,
    required this.pageCount,
    required this.chunkCount,
    required this.dateAdded,
    required this.fileSize,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as int? ?? 0,
      filename: json['filename'] as String? ?? '',
      fileHash: json['file_hash'] as String? ?? '',
      fileType: json['file_type'] as String? ?? 'txt',
      pageCount: json['page_count'] as int? ?? 1,
      chunkCount: json['chunk_count'] as int? ?? 0,
      dateAdded: json['date_added'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'file_hash': fileHash,
      'file_type': fileType,
      'page_count': pageCount,
      'chunk_count': chunkCount,
      'date_added': dateAdded,
      'file_size': fileSize,
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
