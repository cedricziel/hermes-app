# hermes_api.model.MoaConfigPayload

## Load the model package
```dart
import 'package:hermes_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**referenceTimeout** | **num** |  | [optional] 
**degradedReferencePolicy** | **String** |  | [optional] [default to 'loud']
**defaultPreset** | **String** |  | [optional] [default to 'default']
**activePreset** | **String** |  | [optional] [default to '']
**presets** | [**Map&lt;String, MoaPresetPayload&gt;**](MoaPresetPayload.md) |  | [optional] [default to {}]
**referenceModels** | [**List&lt;MoaModelSlot&gt;**](MoaModelSlot.md) |  | [optional] [default to []]
**aggregator** | [**MoaModelSlot**](MoaModelSlot.md) |  | [optional] 
**referenceTemperature** | **num** |  | [optional] 
**aggregatorTemperature** | **num** |  | [optional] 
**fanout** | **String** |  | [optional] 
**enabled** | **bool** |  | [optional] [default to true]
**profile** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


