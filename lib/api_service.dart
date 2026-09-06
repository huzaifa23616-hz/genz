import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================

  static const String baseUrl = 'http://138.197.201.213:8000';

  // ============================================================
  // AUTH ENDPOINTS
  // ============================================================

  static const String loginEndpoint = '/api/auth/login/';

  // IMPORTANT:
  // If your Scalar documentation shows a different refresh URL,
  // change ONLY this line.
  static const String refreshEndpoint = '/api/auth/token/refresh/';

  // ============================================================
  // TOKEN STORAGE KEYS
  // ============================================================

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // ============================================================
  // GET ACCESS TOKEN
  // ============================================================

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(accessTokenKey);

    if (token != null && token.trim().isNotEmpty) {
      return token.trim();
    }

    return null;
  }

  // ============================================================
  // GET REFRESH TOKEN
  // ============================================================

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(refreshTokenKey);

    if (token != null && token.trim().isNotEmpty) {
      return token.trim();
    }

    return null;
  }

  // ============================================================
  // SAVE ACCESS TOKEN
  // ============================================================

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      accessTokenKey,
      token.trim(),
    );

    print('================================');
    print('ACCESS TOKEN SAVED');
    print('TOKEN LENGTH: ${token.length}');
    print('================================');
  }

  // ============================================================
  // SAVE REFRESH TOKEN
  // ============================================================

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      refreshTokenKey,
      token.trim(),
    );

    print('================================');
    print('REFRESH TOKEN SAVED');
    print('================================');
  }

  // ============================================================
  // SAVE BOTH TOKENS
  // ============================================================

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      accessTokenKey,
      accessToken.trim(),
    );

    await prefs.setString(
      refreshTokenKey,
      refreshToken.trim(),
    );

    print('================================');
    print('ACCESS + REFRESH TOKENS SAVED');
    print('================================');
  }

  // ============================================================
  // CLEAR TOKENS
  // ============================================================

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);

    print('================================');
    print('TOKENS CLEARED');
    print('USER MUST LOGIN AGAIN');
    print('================================');
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login(
      String email,
      String password,
      ) async {
    final url = Uri.parse(
      '$baseUrl$loginEndpoint',
    );

    print('================================');
    print('LOGIN REQUEST');
    print('URL: $url');
    print('================================');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('LOGIN STATUS: ${response.statusCode}');
      print('LOGIN RESPONSE: ${response.body}');

      Map<String, dynamic> data = {};

      if (response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        String? accessToken;
        String? refreshToken;

        // ------------------------------------------------------
        // YOUR CURRENT RESPONSE FORMAT
        //
        // data
        //   └── tokens
        //        ├── access
        //        └── refresh
        // ------------------------------------------------------

        if (data['data'] is Map) {
          final nestedData = Map<String, dynamic>.from(
            data['data'],
          );

          if (nestedData['tokens'] is Map) {
            final tokens = Map<String, dynamic>.from(
              nestedData['tokens'],
            );

            if (tokens['access'] != null) {
              accessToken = tokens['access'].toString();
            }

            if (tokens['refresh'] != null) {
              refreshToken = tokens['refresh'].toString();
            }
          }
        }

        // ------------------------------------------------------
        // ALSO SUPPORT FLAT RESPONSE
        // ------------------------------------------------------

        if (accessToken == null &&
            data['access'] != null) {
          accessToken = data['access'].toString();
        }

        if (refreshToken == null &&
            data['refresh'] != null) {
          refreshToken = data['refresh'].toString();
        }

        // ------------------------------------------------------
        // SAVE TOKENS
        // ------------------------------------------------------

        if (accessToken != null &&
            accessToken.trim().isNotEmpty) {
          await saveToken(accessToken);

          print('LOGIN ACCESS TOKEN RECEIVED');
        }

        if (refreshToken != null &&
            refreshToken.trim().isNotEmpty) {
          await saveRefreshToken(refreshToken);

          print('LOGIN REFRESH TOKEN RECEIVED');
        }

        if (accessToken == null) {
          print(
            'WARNING: LOGIN SUCCESS BUT NO ACCESS TOKEN FOUND',
          );
        }

        if (refreshToken == null) {
          print(
            'WARNING: LOGIN SUCCESS BUT NO REFRESH TOKEN FOUND',
          );
        }

        return data;
      }

      // ========================================================
      // LOGIN FAILED
      // ========================================================

      String message = 'Login failed';

      if (data['detail'] != null) {
        message = data['detail'].toString();
      } else if (data['message'] != null) {
        message = data['message'].toString();
      } else if (data['error'] != null) {
        message = data['error'].toString();
      }

      throw Exception(
        '$message (${response.statusCode})',
      );
    } catch (e) {
      print('LOGIN ERROR: $e');
      rethrow;
    }
  }

  // ============================================================
  // REFRESH ACCESS TOKEN
  // ============================================================

  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null ||
        refreshToken.trim().isEmpty) {
      print('NO REFRESH TOKEN FOUND');
      return false;
    }

    final url = Uri.parse(
      '$baseUrl$refreshEndpoint',
    );

    print('================================');
    print('REFRESHING ACCESS TOKEN');
    print('URL: $url');
    print('================================');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      print(
        'REFRESH STATUS: ${response.statusCode}',
      );

      print(
        'REFRESH RESPONSE: ${response.body}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (response.body.trim().isEmpty) {
          print('REFRESH RESPONSE IS EMPTY');
          return false;
        }

        final decoded = jsonDecode(response.body);

        String? newAccessToken;
        String? newRefreshToken;

        // ------------------------------------------------------
        // NORMAL SIMPLE JWT RESPONSE
        //
        // {
        //   "access": "new_access_token"
        // }
        // ------------------------------------------------------

        if (decoded is Map) {
          final data = Map<String, dynamic>.from(
            decoded,
          );

          if (data['access'] != null) {
            newAccessToken =
                data['access'].toString();
          }

          if (data['refresh'] != null) {
            newRefreshToken =
                data['refresh'].toString();
          }

          // ----------------------------------------------------
          // ALSO SUPPORT NESTED RESPONSE
          // ----------------------------------------------------

          if (newAccessToken == null &&
              data['data'] is Map) {
            final nestedData =
            Map<String, dynamic>.from(
              data['data'],
            );

            if (nestedData['access'] != null) {
              newAccessToken =
                  nestedData['access'].toString();
            }

            if (nestedData['refresh'] != null) {
              newRefreshToken =
                  nestedData['refresh'].toString();
            }

            if (nestedData['tokens'] is Map) {
              final tokens =
              Map<String, dynamic>.from(
                nestedData['tokens'],
              );

              if (tokens['access'] != null) {
                newAccessToken =
                    tokens['access'].toString();
              }

              if (tokens['refresh'] != null) {
                newRefreshToken =
                    tokens['refresh'].toString();
              }
            }
          }
        }

        // ------------------------------------------------------
        // SAVE NEW ACCESS TOKEN
        // ------------------------------------------------------

        if (newAccessToken != null &&
            newAccessToken.trim().isNotEmpty) {
          await saveToken(newAccessToken);

          // ----------------------------------------------------
          // IF BACKEND ROTATES REFRESH TOKENS,
          // SAVE THE NEW ONE TOO.
          // ----------------------------------------------------

          if (newRefreshToken != null &&
              newRefreshToken.trim().isNotEmpty) {
            await saveRefreshToken(
              newRefreshToken,
            );
          }

          print('================================');
          print('ACCESS TOKEN REFRESHED SUCCESSFULLY');
          print('================================');

          return true;
        }

        print(
          'REFRESH SUCCESS BUT NO NEW ACCESS TOKEN FOUND',
        );

        return false;
      }

      // ========================================================
      // REFRESH TOKEN EXPIRED / INVALID
      // ========================================================

      if (response.statusCode == 401) {
        print('================================');
        print('REFRESH TOKEN EXPIRED OR INVALID');
        print('CLEARING TOKENS');
        print('USER MUST LOGIN AGAIN');
        print('================================');

        await clearToken();

        return false;
      }

      print(
        'TOKEN REFRESH FAILED: ${response.statusCode}',
      );

      return false;
    } catch (e) {
      print('TOKEN REFRESH ERROR: $e');
      return false;
    }
  }

  // ============================================================
  // AUTHORIZATION HEADERS
  // ============================================================

  static Future<Map<String, String>> headers() async {
    final token = await getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'No access token found. Please login first.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<http.Response> get(
      String endpoint,
      ) async {
    final url = Uri.parse(
      '$baseUrl$endpoint',
    );

    print('================================');
    print('GET REQUEST');
    print('URL: $url');
    print('================================');

    // First request
    http.Response response = await http.get(
      url,
      headers: await headers(),
    );

    print(
      'GET STATUS: ${response.statusCode}',
    );

    print(
      'GET BODY: ${response.body}',
    );

    // ==========================================================
    // ACCESS TOKEN EXPIRED
    // ==========================================================

    if (response.statusCode == 401) {
      print(
        'ACCESS TOKEN EXPIRED. TRYING REFRESH...',
      );

      final refreshed =
      await refreshAccessToken();

      if (refreshed) {
        print(
          'RETRYING ORIGINAL GET REQUEST...',
        );

        response = await http.get(
          url,
          headers: await headers(),
        );

        print(
          'RETRY GET STATUS: ${response.statusCode}',
        );

        print(
          'RETRY GET BODY: ${response.body}',
        );
      }
    }

    return response;
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<http.Response> post(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    final url = Uri.parse(
      '$baseUrl$endpoint',
    );

    http.Response response = await http.post(
      url,
      headers: await headers(),
      body: body == null
          ? null
          : jsonEncode(body),
    );

    print(
      'POST STATUS: ${response.statusCode}',
    );

    print(
      'POST BODY: ${response.body}',
    );

    // ==========================================================
    // ACCESS TOKEN EXPIRED
    // ==========================================================

    if (response.statusCode == 401) {
      print(
        'ACCESS TOKEN EXPIRED. TRYING REFRESH...',
      );

      final refreshed =
      await refreshAccessToken();

      if (refreshed) {
        response = await http.post(
          url,
          headers: await headers(),
          body: body == null
              ? null
              : jsonEncode(body),
        );

        print(
          'RETRY POST STATUS: ${response.statusCode}',
        );

        print(
          'RETRY POST BODY: ${response.body}',
        );
      }
    }

    return response;
  }

  // ============================================================
  // PUT
  // ============================================================

  static Future<http.Response> put(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    final url = Uri.parse(
      '$baseUrl$endpoint',
    );

    http.Response response = await http.put(
      url,
      headers: await headers(),
      body: body == null
          ? null
          : jsonEncode(body),
    );

    if (response.statusCode == 401) {
      print(
        'ACCESS TOKEN EXPIRED. TRYING REFRESH...',
      );

      final refreshed =
      await refreshAccessToken();

      if (refreshed) {
        response = await http.put(
          url,
          headers: await headers(),
          body: body == null
              ? null
              : jsonEncode(body),
        );
      }
    }

    return response;
  }

  // ============================================================
  // PATCH
  // ============================================================

  static Future<http.Response> patch(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    final url = Uri.parse(
      '$baseUrl$endpoint',
    );

    http.Response response = await http.patch(
      url,
      headers: await headers(),
      body: body == null
          ? null
          : jsonEncode(body),
    );

    if (response.statusCode == 401) {
      print(
        'ACCESS TOKEN EXPIRED. TRYING REFRESH...',
      );

      final refreshed =
      await refreshAccessToken();

      if (refreshed) {
        response = await http.patch(
          url,
          headers: await headers(),
          body: body == null
              ? null
              : jsonEncode(body),
        );
      }
    }

    return response;
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<http.Response> delete(
      String endpoint,
      ) async {
    final url = Uri.parse(
      '$baseUrl$endpoint',
    );

    http.Response response = await http.delete(
      url,
      headers: await headers(),
    );

    if (response.statusCode == 401) {
      print(
        'ACCESS TOKEN EXPIRED. TRYING REFRESH...',
      );

      final refreshed =
      await refreshAccessToken();

      if (refreshed) {
        response = await http.delete(
          url,
          headers: await headers(),
        );
      }
    }

    return response;
  }
}