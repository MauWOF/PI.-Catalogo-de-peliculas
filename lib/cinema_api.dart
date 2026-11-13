import 'dart:convert';

import 'package:http/http.dart' as http;

class Movie {
  Movie(this.id, this.values);
  final String id;
  final Map<String, String> values;
  String operator [](String key) => values[key] ?? '';
}

class CinemaApi {
  static const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const key = String.fromEnvironment('FIREBASE_API_KEY');
  static bool get configured => project.isNotEmpty && key.isNotEmpty;
  String? token;
  String? refreshToken;
  DateTime? expiry;
  bool admin = false;

  Map<String, dynamic> read(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = data['error']?['message'] as String? ?? '';
      throw Exception(switch (message) {
        'EMAIL_EXISTS' => 'Este correo ya está registrado.',
        'INVALID_LOGIN_CREDENTIALS' ||
        'INVALID_PASSWORD' ||
        'EMAIL_NOT_FOUND' => 'Revisa tu correo y contraseña.',
        'Missing or insufficient permissions.' =>
          'Tu cuenta no tiene permiso para realizar esta acción.',
        _ => 'Firebase respondió con un error (${response.statusCode}).',
      });
    }
    return data;
  }

  void updateToken(String id, String refresh, String seconds) {
    token = id;
    refreshToken = refresh;
    expiry = DateTime.now().add(Duration(seconds: int.parse(seconds) - 60));
  }

  Future<void> authenticate(
    String email,
    String password,
    bool register,
  ) async {
    if (!configured) throw Exception('Configura Firebase para continuar.');
    final action = register ? 'signUp' : 'signInWithPassword';
    final data = read(
      await http.post(
        Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$action', {
          'key': key,
        }),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      ),
    );
    updateToken(data['idToken'], data['refreshToken'], data['expiresIn']);
    final payload = token!.split('.')[1];
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    );
    admin = claims['admin'] == true;
  }

  void signOut() {
    token = null;
    refreshToken = null;
    expiry = null;
    admin = false;
  }

  Future<Map<String, dynamic>> request(
    String method, [
    String? id,
    Map<String, String>? movie,
  ]) async {
    if (expiry!.isBefore(DateTime.now())) {
      final data = read(
        await http.post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {'key': key}),
          body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken!},
        ),
      );
      updateToken(data['id_token'], data['refresh_token'], data['expires_in']);
    }
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$project/databases/(default)/documents/movies${id == null ? '' : '/$id'}',
      method == 'GET' ? {'pageSize': '100'} : null,
    );
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token';
    if (movie != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'fields': movie.map(
          (key, value) => MapEntry(
            key,
            key == 'year' ? {'integerValue': value} : {'stringValue': value},
          ),
        ),
      });
    }
    return read(await http.Response.fromStream(await request.send()));
  }

  Future<List<Movie>> movies() async {
    final result = <Movie>[];
    final first = await request('GET');
    var data = first;
    while (true) {
      for (final doc in data['documents'] ?? []) {
        final fields = doc['fields'] as Map<String, dynamic>;
        result.add(
          Movie(
            (doc['name'] as String).split('/').last,
            fields.map(
              (key, value) => MapEntry(
                key,
                (value['stringValue'] ?? value['integerValue'] ?? '')
                    .toString(),
              ),
            ),
          ),
        );
      }
      final page = data['nextPageToken'] as String?;
      if (page == null) break;
      data = read(
        await http.get(
          Uri.https(
            'firestore.googleapis.com',
            '/v1/projects/$project/databases/(default)/documents/movies',
            {'pageSize': '100', 'pageToken': page},
          ),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    }
    return result..sort(
      (a, b) => a['title'].toLowerCase().compareTo(b['title'].toLowerCase()),
    );
  }

  Future<void> add(Map<String, String> movie) async =>
      request('POST', null, movie);
  Future<void> remove(String id) async => request('DELETE', id);
}
