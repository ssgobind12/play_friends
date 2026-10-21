/// Configuration for AWS Cloud Storage (Amazon DynamoDB & AWS API Gateway).
/// Allows storing and verifying user registrations (email and mobile number).
class AwsConfig {
  /// AWS API Gateway / Lambda REST Endpoint URL
  static String apiEndpoint = 'https://6zsqpcfh9j.execute-api.ap-southeast-2.amazonaws.com/users';

  /// AWS Region
  static String region = 'ap-southeast-2';

  /// Amazon DynamoDB table name for gamer accounts
  static String tableName = 'PlayFriends_Users';

  /// Optional AWS API Gateway API Key for x-api-key header
  static String apiKey = '';

  /// Returns true if an AWS API Gateway endpoint URL has been configured
  static bool get isConfigured =>
      apiEndpoint.trim().isNotEmpty &&
      apiEndpoint.trim().startsWith('http');
}
