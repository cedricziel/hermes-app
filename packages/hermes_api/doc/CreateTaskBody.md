# hermes_api.model.CreateTaskBody

## Load the model package
```dart
import 'package:hermes_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**title** | **String** |  | 
**body** | **String** |  | [optional] 
**assignee** | **String** |  | [optional] 
**tenant** | **String** |  | [optional] 
**priority** | **int** |  | [optional] [default to 0]
**workspaceKind** | **String** |  | [optional] 
**workspacePath** | **String** |  | [optional] 
**parents** | **List&lt;String&gt;** |  | [optional] 
**triage** | **bool** |  | [optional] [default to false]
**idempotencyKey** | **String** |  | [optional] 
**maxRuntimeSeconds** | **int** |  | [optional] 
**skills** | **List&lt;String&gt;** |  | [optional] 
**goalMode** | **bool** |  | [optional] [default to false]
**goalMaxTurns** | **int** |  | [optional] 
**modelOverride** | **String** |  | [optional] 
**providerOverride** | **String** |  | [optional] 
**reasoningEffort** | **String** |  | [optional] 
**projectId** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


