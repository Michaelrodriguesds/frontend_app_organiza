// =====================================================================
// api.dart — o "carteiro": único lugar do app que fala com o servidor.
// Todas as telas usam Api.get / Api.post / Api.put / Api.apagar.
// =====================================================================
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Endereço da API. Por padrão é o seu PC (localhost).
/// Para usar a API do Render, rode:
///   flutter run -d edge --dart-define=API=https://SEU-APP.onrender.com
const String apiBase = String.fromEnvironment('API', defaultValue: 'http://localhost:3000');

/// Erro "amigável" vindo da API (já com mensagem em português).
class ApiErro implements Exception {
  final String mensagem;
  final int status; // 0 = não conseguiu falar com o servidor
  final String? detalhe; // qual chamada falhou (ex.: "PUT /lembretes/123") — ajuda a achar problemas
  ApiErro(this.mensagem, this.status, {this.detalhe});
  @override
  String toString() => mensagem;
}

class Api {
  static String? _token;                    // o "crachá" de login
  static Map<String, dynamic>? usuario;     // dados do usuário logado

  static bool get logado => _token != null;

  /// Ao abrir o app: recupera o login guardado no aparelho/navegador.
  static Future<void> carregarSessao() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
  }

  static Future<void> _guardar(String token, Map usuarioJson) async {
    _token = token;
    usuario = Map<String, dynamic>.from(usuarioJson);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
  }

  static Future<void> sair() async {
    _token = null;
    usuario = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('digital_cred'); // sem login guardado, a digital também é desativada
  }

  /// Faz a chamada HTTP e devolve o JSON já decodificado.
  static Future<dynamic> _req(String metodo, String rota, [Object? corpo]) async {
    // Proteção: se algum id veio vazio, o endereço teria "/null". Melhor avisar do que enviar.
    if (RegExp(r'/(null|undefined)(/|\?|$)').hasMatch(rota)) {
      throw ApiErro('Este item não tem identificador. Volte, atualize a tela e tente de novo.', 0, detalhe: '$metodo $rota');
    }
    final uri = Uri.parse('$apiBase/api$rota');
    final cabecalhos = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    final json = corpo == null ? null : jsonEncode(corpo);

    http.Response r;
    try {
      final Future<http.Response> chamada = switch (metodo) {
        'POST' => http.post(uri, headers: cabecalhos, body: json ?? '{}'),
        'PUT' => http.put(uri, headers: cabecalhos, body: json ?? '{}'),
        'DELETE' => http.delete(uri, headers: cabecalhos, body: json),
        _ => http.get(uri, headers: cabecalhos),
      };
      // 60 s: o plano grátis do Render "dorme" e a 1ª chamada pode demorar.
      r = await chamada.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiErro('O servidor demorou para responder. Tente de novo.', 0);
    } catch (_) {
      throw ApiErro('Sem conexão com o servidor. Verifique se a API está rodando.', 0);
    }

    dynamic dados;
    if (r.bodyBytes.isNotEmpty) {
      try {
        dados = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        dados = null;
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return dados;

    if (r.statusCode == 401 && _token != null) await sair(); // sessão inválida
    final msg = (dados is Map && dados['erro'] != null) ? dados['erro'].toString() : 'Erro ${r.statusCode}';
    throw ApiErro(msg, r.statusCode, detalhe: '$metodo $rota');
  }

  // ---- atalhos usados pelas telas ----
  static Future<dynamic> get(String rota) => _req('GET', rota);
  static Future<dynamic> post(String rota, [Object? corpo]) => _req('POST', rota, corpo ?? {});
  static Future<dynamic> put(String rota, Object corpo) => _req('PUT', rota, corpo);
  static Future<dynamic> apagar(String rota, [Object? corpo]) => _req('DELETE', rota, corpo);

  /// Lista de registros. Ex.: Api.lista('veiculos') ou Api.lista('manutencoes?veiculoId=123')
  static Future<List<Map<String, dynamic>>> lista(String rota) async {
    final d = await get('/$rota') as List;
    return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Um objeto só. Ex.: Api.mapa('/dashboard')
  static Future<Map<String, dynamic>> mapa(String rota) async =>
      Map<String, dynamic>.from(await get(rota) as Map);

  // ---- login e conta ----
  static Future<void> login(String email, String senha) async {
    final d = await _req('POST', '/auth/login', {'email': email, 'senha': senha});
    await _guardar(d['token'], d['usuario']);
  }

  static Future<void> cadastro(String nome, String email, String senha) async {
    final d = await _req('POST', '/auth/cadastro', {'nome': nome, 'email': email, 'senha': senha});
    await _guardar(d['token'], d['usuario']);
  }

  static Future<void> esqueci(String email) => _req('POST', '/auth/esqueci', {'email': email});

  static Future<void> redefinir(String email, String codigo, String novaSenha) =>
      _req('POST', '/auth/redefinir', {'email': email, 'codigo': codigo, 'novaSenha': novaSenha});

  /// Atualiza os dados do usuário (dias de teste restantes, configurações...).
  static Future<Map<String, dynamic>> eu() async {
    usuario = await mapa('/eu');
    return usuario!;
  }
}
