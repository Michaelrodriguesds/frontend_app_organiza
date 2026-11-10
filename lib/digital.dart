// =====================================================================
// digital.dart — login por digital no navegador/celular (WebAuthn).
// Quem faz o trabalho pesado é o arquivo web/digital.js; aqui só
// "conversamos" com ele e guardamos se a digital está ativada.
//
// Como funciona: ao ATIVAR, o aparelho pede a digital e o app guarda o id
// da credencial. Ao ABRIR o app, se a digital estiver ativada, aparece a
// tela de desbloqueio e o app só entra depois de a digital ser confirmada.
// (É um "cadeado" do app: o login continua guardado no aparelho.)
// =====================================================================
import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';

@JS('organizaDigital.suportado')
external JSPromise<JSAny?> _suportado();

@JS('organizaDigital.registrar')
external JSPromise<JSAny?> _registrar(JSString nome);

@JS('organizaDigital.verificar')
external JSPromise<JSAny?> _verificar(JSString id);

const _chave = 'digital_cred';

class Digital {
  /// O aparelho/navegador tem leitor de digital (ou rosto/PIN) disponível?
  static Future<bool> suportado() async {
    try {
      final r = await _suportado().toDart;
      return r.dartify() == true; // dartify(): converte o valor do JavaScript para Dart
    } catch (_) {
      return false; // sem o digital.js ou fora do navegador
    }
  }

  /// A digital está ativada neste aparelho?
  static Future<bool> ativa() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_chave) != null;
  }

  /// Pede a digital uma vez e, se der certo, deixa ativada. Devolve true/false.
  static Future<bool> ativar(String nome) async {
    try {
      final r = await _registrar(nome.toJS).toDart;
      final id = r.dartify(); // texto com o id da credencial, ou null se o usuário cancelou
      if (id is! String || id.isEmpty) return false;
      final p = await SharedPreferences.getInstance();
      await p.setString(_chave, id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pede a digital para desbloquear. true = confirmou.
  static Future<bool> desbloquear() async {
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString(_chave);
      if (id == null) return true; // não está ativada: não há o que pedir
      final r = await _verificar(id.toJS).toDart;
      return r.dartify() == true;
    } catch (_) {
      return false;
    }
  }

  /// Desativa (apaga o id guardado).
  static Future<void> desativar() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_chave);
  }
}
