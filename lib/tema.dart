// =====================================================================
// tema.dart — cores, formatação de dinheiro/datas e pequenos ajudantes.
// Mudou a cor do app? É só editar a classe Cores.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Cores {
  static const fundo = Color(0xFFF2F1EC);
  static const verde = Color(0xFF1F4B43);
  static const verdeClaro = Color(0xFFDCE7E1);
  static const linha = Color(0xFFDAD8CF);
  static const texto = Color(0xFF16211F);
  static const textoSuave = Color(0xFF5B655F);
  static const vermelho = Color(0xFFB5482E);
  static const vermelhoClaro = Color(0xFFF5DED6);
  static const ambar = Color(0xFFB4822F);
  static const ambarClaro = Color(0xFFF3E7D2);
  static const azul = Color(0xFF3B5B7A);
  static const azulClaro = Color(0xFFDEE5EC);
  static const ok = Color(0xFF2F7D4F);
}

ThemeData temaApp() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Cores.verde),
      scaffoldBackgroundColor: Cores.fundo,
    );

/// Visual padrão dos campos de texto.
InputDecoration decoracao(String rotulo, {String? dica, Widget? sufixo}) => InputDecoration(
      labelText: rotulo,
      hintText: dica,
      suffixIcon: sufixo,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cores.linha)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cores.linha)),
    );

// ---------- Categorias (valor guardado -> nome mostrado) ----------
const Map<String, String> categorias = {
  'casa': 'Casa',
  'mercado': 'Mercado',
  'veiculo': 'Veículo',
  'transporte': 'Transporte',
  'saude': 'Saúde',
  'educacao': 'Educação',
  'lazer': 'Lazer',
  'divida': 'Dívidas',
  'outros': 'Outros',
};
String rotuloCategoria(dynamic c) => categorias[c] ?? c?.toString() ?? 'Outros';

// ---------- Dinheiro e datas ----------
final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// 1234.5 -> "R$ 1.234,50"
String reais(num? v) => _moeda.format(v ?? 0);

/// Lê uma data que veio do servidor (texto ISO) e converte para o horário local.
DateTime? lerIso(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// "2026-10-17T..." -> "17/10/2026"
String dataBR(dynamic v) {
  final d = lerIso(v);
  return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
}

/// Data escolhida pelo usuário -> texto ISO guardado no servidor (sempre ao meio-dia
/// para não "pular" de dia por causa de fuso horário).
String isoDoDia(DateTime d) => DateTime.utc(d.year, d.month, d.day, 12).toIso8601String();

/// Lê "1.234,56" ou "1234.56" e devolve o número (ou null se não for número).
double? lerNumero(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final limpo = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(limpo);
}

/// 12.5 -> "12,5" | 12.0 -> "12" (para preencher campos de edição)
String numeroParaCampo(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

/// Mensagem rápida na parte de baixo da tela.
void aviso(BuildContext context, String msg, {bool erro = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: erro ? Cores.vermelho : Cores.texto,
    behavior: SnackBarBehavior.floating,
  ));
}
