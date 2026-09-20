class KnowledgePack {
  final String packId;
  final String name;
  final String version;
  final String description;
  final String createdAt;
  final String embeddingModel;
  final int embeddingDim;
  final int docCount;
  final int chunkCount;
  final int fileSize;
  final bool isActive;
  final String filePath;

  KnowledgePack({
    required this.packId,
    required this.name,
    required this.version,
    required this.description,
    required this.createdAt,
    this.embeddingModel = 'all-MiniLM-L6-v2',
    this.embeddingDim = 384,
    this.docCount = 0,
    this.chunkCount = 0,
    this.fileSize = 0,
    this.isActive = false,
    this.filePath = '',
  });

  factory KnowledgePack.fromJson(Map<String, dynamic> json) {
    return KnowledgePack(
      packId: json['pack_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Pack',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      embeddingModel: json['embedding_model'] as String? ?? 'all-MiniLM-L6-v2',
      embeddingDim: json['embedding_dim'] as int? ?? 384,
      docCount: json['doc_count'] as int? ?? 0,
      chunkCount: json['chunk_count'] as int? ?? 0,
      fileSize: json['file_size'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      filePath: json['file_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pack_id': packId,
      'name': name,
      'version': version,
      'description': description,
      'created_at': createdAt,
      'embedding_model': embeddingModel,
      'embedding_dim': embeddingDim,
      'doc_count': docCount,
      'chunk_count': chunkCount,
      'file_size': fileSize,
      'is_active': isActive,
      'file_path': filePath,
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
