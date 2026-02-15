import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/request_model.dart';

class LLMClassificationResult {
  final String requestType;
  final ImportanceLevel importanceLevel;
  final Map<String, dynamic> extractedMetadata;
  final String reasoning;

  LLMClassificationResult({
    required this.requestType,
    required this.importanceLevel,
    required this.extractedMetadata,
    required this.reasoning,
  });

  factory LLMClassificationResult.fromJson(Map<String, dynamic> json) {
    return LLMClassificationResult(
      requestType: json['request_type'] as String? ?? 'other',
      importanceLevel: _parseImportance(
        json['importance_level'] as String? ?? 'medium',
      ),
      extractedMetadata: json['metadata'] as Map<String, dynamic>? ?? {},
      reasoning: json['reasoning'] as String? ?? '',
    );
  }

  static ImportanceLevel _parseImportance(String importance) {
    switch (importance.toLowerCase()) {
      case 'low':
        return ImportanceLevel.low;
      case 'medium':
        return ImportanceLevel.medium;
      case 'high':
        return ImportanceLevel.high;
      case 'critical':
        return ImportanceLevel.critical;
      default:
        return ImportanceLevel.medium;
    }
  }
}

class LLMService {
  final String baseUrl;
  final String model;

  LLMService({String? baseUrl, String? model})
    : baseUrl =
          baseUrl ?? dotenv.env['LLM_BASE_URL'] ?? 'http://localhost:11434',
      model = model ?? dotenv.env['LLM_MODEL'] ?? 'phi3';

  // Classify request using local LLM
  Future<LLMClassificationResult> classifyRequest({
    required String title,
    required String description,
  }) async {
    // 1. Quick connection check (fail fast on mobile)
    final isConnected = await testConnection();
    if (!isConnected) {
      debugPrint('LLM unreachable. Using keyword fallback.');
      return _fallbackClassification(title, description);
    }

    try {
      final prompt = _buildClassificationPrompt(title, description);
      final response = await _generateCompletion(prompt);

      // Parse the response
      return _parseClassificationResponse(response);
    } catch (e) {
      // Fallback classification if LLM fails
      debugPrint('LLM classification failed: $e. Using fallback.');
      return _fallbackClassification(title, description);
    }
  }

  String _buildClassificationPrompt(String title, String description) {
    return '''You are an AI assistant that classifies employee requests. Analyze the following request and provide a JSON response with:
1. request_type: one of [leave, purchase, travel, equipment, hr, it_support, training, other]
2. importance_level: one of [low, medium, high, critical]
3. metadata: any relevant extracted details (dates, amounts, names, etc.)
4. reasoning: brief explanation of your classification

Request Title: $title
Request Description: $description

Respond ONLY with valid JSON, no additional text. Example format:
{
  "request_type": "leave",
  "importance_level": "medium",
  "metadata": {
    "start_date": "2024-03-15",
    "end_date": "2024-03-20",
    "days": 5
  },
  "reasoning": "Employee requesting planned leave for 5 days"
}''';
  }

  Future<String> _generateCompletion(String prompt) async {
    final url = Uri.parse('$baseUrl/api/generate');

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'stream': false,
            'options': {
              'temperature':
                  0.3, // Low temperature for consistent classification
              'num_predict': 300,
            },
          }),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('LLM request timed out'),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    } else {
      throw Exception('LLM API error: ${response.statusCode}');
    }
  }

  LLMClassificationResult _parseClassificationResponse(String response) {
    try {
      // Extract JSON from response (handling potential markdown formatting)
      String jsonStr = response.trim();

      // Remove markdown code blocks if present
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        jsonStr = lines.sublist(1, lines.length - 1).join('\n');
        if (jsonStr.startsWith('json')) {
          jsonStr = jsonStr.substring(4).trim();
        }
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LLMClassificationResult.fromJson(parsed);
    } catch (e) {
      debugPrint('Failed to parse LLM response: $e');
      throw Exception('Invalid LLM response format');
    }
  }

  // Fallback classification using simple keyword matching
  LLMClassificationResult _fallbackClassification(
    String title,
    String description,
  ) {
    final combined = '${title.toLowerCase()} ${description.toLowerCase()}';

    String requestType = 'other';
    ImportanceLevel importance = ImportanceLevel.medium;

    // Simple keyword-based classification
    if (combined.contains('leave') ||
        combined.contains('vacation') ||
        combined.contains('pto')) {
      requestType = 'leave';
    } else if (combined.contains('purchase') ||
        combined.contains('buy') ||
        combined.contains('equipment')) {
      requestType = 'purchase';
      importance = ImportanceLevel.high;
    } else if (combined.contains('travel') || combined.contains('trip')) {
      requestType = 'travel';
    } else if (combined.contains('training') || combined.contains('course')) {
      requestType = 'training';
    } else if (combined.contains('hr') || combined.contains('human resource')) {
      requestType = 'hr';
    } else if (combined.contains('it') ||
        combined.contains('technical') ||
        combined.contains('support')) {
      requestType = 'it_support';
    }

    // Check for urgency keywords
    if (combined.contains('urgent') ||
        combined.contains('asap') ||
        combined.contains('emergency')) {
      importance = ImportanceLevel.critical;
    } else if (combined.contains('important') ||
        combined.contains('critical')) {
      importance = ImportanceLevel.high;
    }

    return LLMClassificationResult(
      requestType: requestType,
      importanceLevel: importance,
      extractedMetadata: {},
      reasoning: 'Classified using keyword matching (LLM unavailable)',
    );
  }

  // Improved connection test with short timeout
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse(baseUrl);
      // Just check if the server is reachable, not specific endpoint
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      // 200 OK or 404 Not Found (but server exists) means we have connection
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }
}
