import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloaderService {
  final Dio _dio = Dio();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> downloadModel({
    required String url,
    required String fileName,
    required Function(int downloaded, int total) onProgress,
  }) async {
    final basePath = await _localPath;
    final savePath = '$basePath/$fileName';
    
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
      ),
    );

    return File(savePath);
  }

  Future<bool> isModelDownloaded(String fileName) async {
    final basePath = await _localPath;
    final file = File('$basePath/$fileName');
    return await file.exists();
  }
}