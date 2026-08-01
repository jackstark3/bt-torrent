import 'package:bt_torrent/domain/repositories/settings_repository.dart';

/// 获取设置用例
class GetSettingsUseCase {
  final SettingsRepository _repository;
  const GetSettingsUseCase(this._repository);

  Future<Map<String, dynamic>> execute() async {
    return {
      'wifiOnly': await _repository.getWifiOnly(),
      'downloadPath': await _repository.getDownloadPath(),
      'maxDownloads': await _repository.getMaxDownloads(),
      'maxConnections': await _repository.getMaxConnections(),
      'downloadRateLimit': await _repository.getDownloadRateLimit(),
      'uploadRateLimit': await _repository.getUploadRateLimit(),
      'dhtEnabled': await _repository.getDhtEnabled(),
      'safeMode': await _repository.getSafeMode(),
      'darkMode': await _repository.getDarkMode(),
    };
  }
}

/// 更新单个设置项用例
class UpdateSettingUseCase {
  final SettingsRepository _repository;
  const UpdateSettingUseCase(this._repository);

  Future<void> execute(String key, dynamic value) async {
    switch (key) {
      case 'wifiOnly':
        await _repository.setWifiOnly(value as bool);
      case 'downloadPath':
        await _repository.setDownloadPath(value as String);
      case 'maxDownloads':
        await _repository.setMaxDownloads(value as int);
      case 'maxConnections':
        await _repository.setMaxConnections(value as int);
      case 'downloadRateLimit':
        await _repository.setDownloadRateLimit(value as int);
      case 'uploadRateLimit':
        await _repository.setUploadRateLimit(value as int);
      case 'dhtEnabled':
        await _repository.setDhtEnabled(value as bool);
      case 'safeMode':
        await _repository.setSafeMode(value as bool);
      case 'darkMode':
        await _repository.setDarkMode(value as bool);
    }
  }
}
