import '../repositories/template_repository.dart';

/// Retrieves the user's persisted default invoice template ID.
/// Returns null when no default has been set yet.
class GetDefaultTemplateUsecase {
  final TemplateRepository _repository;

  const GetDefaultTemplateUsecase(this._repository);

  Future<String?> call() => _repository.getDefaultTemplateId();
}
