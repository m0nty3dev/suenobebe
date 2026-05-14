import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadBabyPhoto({
    required String babyId,
    required File file,
  }) async {
    final ref = _storage.ref('babies/$babyId/photo.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadExportCsv({
    required String userId,
    required String csvContent,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('exports/$userId/$timestamp.csv');
    await ref.putString(csvContent, metadata: SettableMetadata(contentType: 'text/csv'));
    return await ref.getDownloadURL();
  }
}
