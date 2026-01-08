import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AgeSignalsResult {
  const AgeSignalsResult({
    required this.status,
    required this.isUnderAgeOfConsent,
    this.ageLower,
    this.ageUpper,
  });

  final String status;
  final bool isUnderAgeOfConsent;
  final int? ageLower;
  final int? ageUpper;

  bool get isMinorOrUnknown {
    final normalized = status.toUpperCase();
    if (normalized != 'VERIFIED') {
      return true;
    }
    return isUnderAgeOfConsent;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'status': status,
        'isUnderAgeOfConsent': isUnderAgeOfConsent,
        'ageLower': ageLower,
        'ageUpper': ageUpper,
      };

  factory AgeSignalsResult.fromJson(Map<String, dynamic> json) {
    return AgeSignalsResult(
      status: (json['status'] as String?)?.toUpperCase() ?? 'UNKNOWN',
      isUnderAgeOfConsent: json['isUnderAgeOfConsent'] is bool
          ? json['isUnderAgeOfConsent'] as bool
          : true,
      ageLower: (json['ageLower'] is num) ? (json['ageLower'] as num).toInt() : null,
      ageUpper: (json['ageUpper'] is num) ? (json['ageUpper'] as num).toInt() : null,
    );
  }

  factory AgeSignalsResult.unknown() => const AgeSignalsResult(
        status: 'UNKNOWN',
        isUnderAgeOfConsent: true,
        ageLower: null,
        ageUpper: null,
      );
}

class AgeSignalsService {
  AgeSignalsService._();

  static final AgeSignalsService instance = AgeSignalsService._();

  static const MethodChannel _channel = MethodChannel('app.age_signals');

  AgeSignalsResult _result = AgeSignalsResult.unknown();
  bool _initialized = false;
  Future<AgeSignalsResult>? _pending;

  AgeSignalsResult get currentResult => _result;

  bool get isMinorOrUnknown => _result.isMinorOrUnknown;

  Future<AgeSignalsResult> ensureInitialized() async {
    if (_initialized) {
      return _result;
    }
    _pending ??= _fetchAgeSignals();
    try {
      _result = await _pending!;
    } finally {
      _initialized = true;
      _pending = null;
    }
    return _result;
  }

  Future<AgeSignalsResult> _fetchAgeSignals() async {
    if (!Platform.isAndroid) {
      return AgeSignalsResult.unknown();
    }
    try {
      final response = await _channel.invokeMethod<String>('getAgeSignals');
      if (response == null || response.isEmpty) {
        return AgeSignalsResult.unknown();
      }
      final decoded = jsonDecode(response);
      if (decoded is! Map<String, dynamic>) {
        return AgeSignalsResult.unknown();
      }
      final result = AgeSignalsResult.fromJson(decoded);
      if (kDebugMode) {
        debugPrint('[AgeSignals] result: ${jsonEncode(result.toMap())}');
      }
      return result;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AgeSignals] fetch failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return AgeSignalsResult.unknown();
    }
  }

  AdRequest buildAdRequest() {
    final useNpa = _result.isMinorOrUnknown;
    if (kDebugMode) {
      debugPrint('[AgeSignals] building AdRequest (NPA=$useNpa)');
    }
    return AdRequest(nonPersonalizedAds: useNpa);
  }
}
