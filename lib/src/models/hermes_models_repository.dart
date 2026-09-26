import 'package:hermes_api/hermes_api.dart';

import 'model_provider_option.dart';

/// Reads the models a profile can chat with through the generated
/// [DefaultApi]. The route has no response schema, so [ModelOptions.fromJson]
/// parses it.
class HermesModelsRepository {
  HermesModelsRepository(this._api);

  final DefaultApi _api;

  Future<ModelOptions> load({String? profile}) async {
    final response = await _api.getModelOptionsApiModelOptionsGet(
      profile: profile,
    );
    return ModelOptions.fromJson(response.data);
  }
}
