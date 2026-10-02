import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 백업 파일 입출력. 플랫폼 플러그인에 의존하는 부분을 이 인터페이스 뒤에 가둔다.
abstract class BackupFileGateway {
  /// JSON 파일을 만들어 공유 시트(저장·전송)로 내보낸다.
  Future<void> shareJson(String json, String fileName);

  /// 사용자가 고른 JSON 파일의 내용. 취소하면 null.
  Future<String?> pickJson();
}

class PlatformBackupFileGateway implements BackupFileGateway {
  const PlatformBackupFileGateway();

  @override
  Future<void> shareJson(String json, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
  }

  @override
  Future<String?> pickJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path).readAsString();
  }
}

final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const PlatformBackupFileGateway(),
);
