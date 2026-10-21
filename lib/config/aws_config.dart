/// Configuration for AWS Cloud Storage (Amazon DynamoDB & AWS API Gateway).
/// Allows storing and verifying user registrations (email and mobile number).
class AwsConfig {
  /// AWS API Gateway / Lambda REST Endpoint URL
  /// Example: https://xxxxxxxxxx.execute-api.ap-south-1.amazonaws.com/prod/users
  static String apiEndpoint = '';

  /// AWS Region (default: ap-south-1 for Mumbai, India)
  static String region = 'ap-south-1';

  /// Amazon DynamoDB table name for gamer accounts
  static String tableName = 'PlayFriends_Users';

  /// Optional AWS API Gateway API Key for x-api-key header
  static String apiKey = '';

  /// Returns true if an AWS API Gateway endpoint URL has been configured
  static bool get isConfigured =>
      apiEndpoint.trim().isNotEmpty &&
      apiEndpoint.trim().startsWith('http');
}
