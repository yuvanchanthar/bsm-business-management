import '../../domain/repositories/template_repository.dart';
import '../datasources/template_local_datasource.dart';

/// Concrete implementation of [TemplateRepository].
/// Delegates all persistence to [TemplateLocalDatasource].
class TemplateRepositoryImpl implements TemplateRepository {
  final TemplateLocalDatasource _datasource;

  const TemplateRepositoryImpl(this._datasource);

  @override
  Future<String?> getDefaultTemplateId() =>
      _datasource.getDefaultTemplateId();

  @override
  Future<void> saveDefaultTemplateId(String id) =>
      _datasource.saveDefaultTemplateId(id);
}
