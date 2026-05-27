import '../repositories/template_repository.dart';

/// Persists the user's chosen default invoice template.
class SaveDefaultTemplateUsecase {
  final TemplateRepository _repository;

  const SaveDefaultTemplateUsecase(this._repository);

  Future<void> call(String templateId) =>
      _repository.saveDefaultTemplateId(templateId);
}
