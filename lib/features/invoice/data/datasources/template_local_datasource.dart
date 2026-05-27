import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

/// Local data source that persists the user's default template preference
/// using [SharedPreferences]. This is the only class that knows about
/// the storage key — all higher layers use the repository abstraction.
class TemplateLocalDatasource {
  final SharedPreferences _prefs;

  const TemplateLocalDatasource(this._prefs);

  Future<String?> getDefaultTemplateId() async {
    return _prefs.getString(AppConstants.kDefaultTemplateKey);
  }

  Future<void> saveDefaultTemplateId(String id) async {
    await _prefs.setString(AppConstants.kDefaultTemplateKey, id);
  }
}
