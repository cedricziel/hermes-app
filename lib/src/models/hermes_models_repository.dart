import 'package:hermes_api/hermes_api.dart';

import 'auxiliary_models.dart';
import 'model_provider_option.dart';

/// Reads the models a profile can chat with, and reads and sets its helper
/// models, through the generated [DefaultApi]. The routes have no response
/// schema, so the answers are parsed here.
class HermesModelsRepository {
  HermesModelsRepository(this._api);

  final DefaultApi _api;

  Future<ModelOptions> load({String? profile}) async {
    final response = await _api.getModelOptionsApiModelOptionsGet(
      profile: profile,
    );
    return ModelOptions.fromJson(response.data);
  }

  Future<AuxiliaryModels> loadAuxiliary({String? profile}) async {
    final response = await _api.getAuxiliaryModelsApiModelAuxiliaryGet(
      profile: profile,
    );
    return AuxiliaryModels.fromJson(response.data);
  }

  /// Runs [task] on [choice], or on the main model when it is null. Returns
  /// Hermes' warning when the model is expensive and was not confirmed with
  /// [confirmExpensive]; nothing is saved then.
  Future<String?> assignAuxiliary(
    String task,
    ModelChoice? choice, {
    String? profile,
    bool confirmExpensive = false,
  }) async {
    final response = await _api.setModelAssignmentApiModelSetPost(
      profile: profile,
      modelAssignment: ModelAssignment(
        scope: 'auxiliary',
        task: task,
        provider: choice?.providerId ?? 'auto',
        model: choice?.modelId ?? '',
        reasoningEffort: choice?.effort,
        confirmExpensiveModel: confirmExpensive,
      ),
    );
    final body = response.data;
    if (body is Map && body['confirm_required'] == true) {
      final message = body['confirm_message'];
      return message is String && message.isNotEmpty
          ? message
          : 'This model is expensive. Use it anyway?';
    }
    return null;
  }
}
