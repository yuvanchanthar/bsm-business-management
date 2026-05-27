/// Abstract contract for template persistence operations.
/// The data layer provides the concrete implementation via SharedPreferences.
abstract class TemplateRepository {
  /// Returns the stored default template ID, or null if none has been set.
  Future<String?> getDefaultTemplateId();

  /// Persists [id] as the user's default invoice template.
  Future<void> saveDefaultTemplateId(String id);
}
