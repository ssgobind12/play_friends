/// Configuration for AWS Cloud Storage (Amazon DynamoDB & AWS API Gateway).
/// Allows storing and verifying user registrations (email and mobile number).
class AwsConfig {
  /// AWS API Gateway / Lambda REST Endpoint URL
  static const String apiEndpoint = String.fromEnvironment(
    'AWS_API_ENDPOINT',
    defaultValue: 'https://6zsqpcfh9j.execute-api.ap-southeast-2.amazonaws.com/users',
  );

  /// AWS Region
  static const String region = String.fromEnvironment(
    'AWS_REGION',
    defaultValue: 'ap-southeast-2',
  );

  /// Amazon DynamoDB table name for gamer accounts
  static const String tableName = String.fromEnvironment(
    'AWS_TABLE_NAME',
    defaultValue: 'PlayFriends_Users',
  );

  /// Optional AWS API Gateway API Key for x-api-key header
  static const String apiKey = String.fromEnvironment(
    'AWS_API_KEY',
    defaultValue: '',
  );

  /// Returns true if an AWS API Gateway endpoint URL has been configured
  static bool get isConfigured =>
      apiEndpoint.trim().isNotEmpty &&
      apiEndpoint.trim().startsWith('http');
}
