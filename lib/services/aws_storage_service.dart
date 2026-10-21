import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/aws_config.dart';
import '../models/user_model.dart';

class AwsCheckResult {
  final bool exists;
  final String? existingField; // 'email' or 'mobile'
  final String? message;

  const AwsCheckResult({
    required this.exists,
    this.existingField,
    this.message,
  });
}

/// Service to interface with AWS Cloud Storage (Amazon DynamoDB & API Gateway)
/// for persisting user accounts and enforcing uniqueness on Email and Mobile Number.
class AwsStorageService {
  // In-memory cache of registered users (persists during app runtime)
  static final List<Map<String, dynamic>> _cloudUserCache = [];

  /// Check if an email or mobile number is already registered in AWS or local registry
  static Future<AwsCheckResult> checkUserExists({
    required String email,
    required String phoneNumber,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // 1. Check local cache first
    for (final u in _cloudUserCache) {
      final uEmail = (u['email'] ?? '').toString().trim().toLowerCase();
      final uPhone = (u['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

      if (uEmail.isNotEmpty && uEmail == cleanEmail) {
        return const AwsCheckResult(
          exists: true,
          existingField: 'email',
          message: 'This email is already used / registered. Please sign in or use another email.',
        );
      }

      if (cleanPhone.isNotEmpty && uPhone.isNotEmpty && uPhone == cleanPhone) {
        return const AwsCheckResult(
          exists: true,
          existingField: 'mobile',
          message: 'This mobile number is already used / registered. Please sign in or use another mobile number.',
        );
      }
    }

    // 2. If AWS API Gateway is configured, query the AWS cloud endpoint
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'checkUser',
                'email': cleanEmail,
                'phoneNumber': cleanPhone,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 409) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final exists = data['exists'] == true;
            final field = data['field']?.toString();
            if (exists) {
              if (field == 'email') {
                return const AwsCheckResult(
                  exists: true,
                  existingField: 'email',
                  message: 'This email is already used / registered in AWS. Please sign in or use another email.',
                );
              } else if (field == 'mobile' || field == 'phone') {
                return const AwsCheckResult(
                  exists: true,
                  existingField: 'mobile',
                  message: 'This mobile number is already used / registered in AWS. Please sign in or use another mobile number.',
                );
              } else {
                return AwsCheckResult(
                  exists: true,
                  message: data['message']?.toString() ?? 'This account is already registered in AWS.',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('AWS checkUserExists network error (falling back to local): $e');
      }
    }

    return const AwsCheckResult(exists: false);
  }

  /// Store a registered user account in AWS DynamoDB & local cache
  static Future<bool> storeUser(UserModel user) async {
    final cleanEmail = user.email.trim().toLowerCase();
    final cleanPhone = (user.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');

    // Cache locally
    _cloudUserCache.add({
      'id': user.id,
      'email': cleanEmail,
      'phoneNumber': cleanPhone,
      'name': user.name,
      'tag': user.tag,
      'countryCode': user.countryCode,
      'countryFlag': user.countryFlag,
      'registeredAt': DateTime.now().toIso8601String(),
    });

    // If AWS API Gateway is configured, upload to AWS DynamoDB
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final payload = {
          'action': 'register',
          'userId': user.id,
          'email': cleanEmail,
          'phoneNumber': cleanPhone,
          'countryCode': user.countryCode,
          'countryFlag': user.countryFlag,
          'name': user.name,
          'tag': user.tag,
          'level': user.level,
          'coins': user.coins,
          'trophies': user.trophies,
          'tableName': AwsConfig.tableName,
          'registeredAt': DateTime.now().toIso8601String(),
        };

        final response = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 5));

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('AWS storeUser error: $e');
        return false;
      }
    }

    return true;
  }

  /// Test connection to AWS endpoint
  static Future<({bool success, String message})> testConnection() async {
    if (!AwsConfig.isConfigured) {
      return (
        success: false,
        message: 'AWS API Gateway endpoint is not set. Please enter your AWS Lambda / API Gateway URL below.',
      );
    }

    try {
      final uri = Uri.parse(AwsConfig.apiEndpoint);
      final headers = {
        'Content-Type': 'application/json',
        if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
      };

      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'action': 'ping',
              'tableName': AwsConfig.tableName,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          message: 'Connected to AWS API Gateway (${stopwatch.elapsedMilliseconds}ms)! DynamoDB table "${AwsConfig.tableName}" ready.',
        );
      } else {
        return (
          success: false,
          message: 'AWS responded with HTTP ${response.statusCode}: ${response.body.isNotEmpty ? response.body : "Check your API Gateway permissions or Lambda handler."}',
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Connection failed: $e. Verify the URL and ensure your phone has internet access.',
      );
    }
  }

  /// Get the recommended AWS Lambda handler code for DynamoDB integration
  static String getRecommendedLambdaCode() {
    return '''
// AWS Lambda (Node.js 20.x) for Play Friends User Storage with DynamoDB
// Table: PlayFriends_Users (Primary Key: email [String], GSI: phoneNumber [String])

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, ScanCommand, GetCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME || "PlayFriends_Users";

exports.handler = async (event) => {
    let body = {};
    if (event.body) {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    }
    
    const action = body.action || "ping";
    
    try {
        if (action === "ping") {
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ status: "ok", message: "Play Friends AWS backend online" })
            };
        }
        
        if (action === "checkUser") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").trim();
            
            // Check by Email
            const emailResult = await docClient.send(new GetCommand({
                TableName: TABLE_NAME,
                Key: { email }
            }));
            
            if (emailResult.Item) {
                return {
                    statusCode: 200,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ exists: true, field: "email", message: "This email is already registered." })
                };
            }
            
            // Check by Phone Number
            if (phone) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    FilterExpression: "phoneNumber = :p",
                    ExpressionAttributeValues: { ":p": phone },
                    Limit: 1
                }));
                
                if (scanResult.Items && scanResult.Items.length > 0) {
                    return {
                        statusCode: 200,
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ exists: true, field: "mobile", message: "This mobile number is already registered." })
                    };
                }
            }
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ exists: false })
            };
        }
        
        if (action === "register") {
            const item = {
                email: (body.email || "").toLowerCase().trim(),
                phoneNumber: (body.phoneNumber || "").trim(),
                userId: body.userId,
                name: body.name,
                tag: body.tag,
                countryCode: body.countryCode,
                level: body.level || 1,
                coins: body.coins || 500,
                trophies: body.trophies || 0,
                createdAt: body.registeredAt || new Date().toISOString()
            };
            
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: item
            }));
            
            return {
                statusCode: 201,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, message: "User stored in AWS DynamoDB successfully" })
            };
        }
        
        return { statusCode: 400, body: JSON.stringify({ error: "Unknown action" }) };
    } catch (err) {
        return {
            statusCode: 500,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: err.message })
        };
    }
};
''';
  }
}
