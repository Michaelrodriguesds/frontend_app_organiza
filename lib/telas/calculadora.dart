// =====================================================================
// calculadora.dart — ferramentas rápidas (funcionam sem internet):
//   Básica | Porcentagem e desconto | Regra de três | Parcelas
// =====================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../componentes.dart';
import '../tema.dart';

class TelaCalculadora extends StatefulWidget {
  const TelaCalculadora({super.key});
  @override
  State<TelaCalculadora> createState() => _TelaCalculadoraState();
}

class _TelaCalculadoraState extends State<TelaCalculadora> {
  String _modo = 'basica';

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Calculadora',
      corpo: ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 40), children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'basica', label: Text('Básica')),
            ButtonSegment(value: 'percentual', label: Text('%')),
            ButtonSegment(value: 'regra3', label: Text('Regra de 3')),
            ButtonSegment(value: 'parcelas', label: Text('Parcelas')),
          ],
          selected: {_modo},
          onSelectionChanged: (s) => setState(() => _modo = s.first),
        ),
        const SizedBox(height: 16),
        if (_modo == 'basica') const _Basica(),
        if (_modo == 'percentual') const _Percentual(),
        if (_modo == 'regra3') const _RegraDeTres(),
        if (_modo == 'parcelas') const _Parcelas(),
      ]),
    );
  }
}

/// Formata um resultado: 5.0 -> "5" | 3.14159 -> "3,14".
String _fmt(double v, {int casas = 2}) {
  if (v.isNaN || v.isInfinite) return 'Erro';
  if (v == v.roundToDouble() && v.abs() < 1e12) return v.toInt().toString();
  var t = v.toStringAsFixed(casas);
  if (t.contains('.')) t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return t.replaceAll('.', ',');
}

/// Campo numérico simples que avisa a tela a cada letra digitada.
Widget _campo(TextEditingController c, String rotulo, VoidCallback aoMudar) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => aoMudar(),
        decoration: decoracao(rotulo),
      ),
    );

Widget _resultado(String texto) => Cartao(
      filho: Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Cores.verde)),
    );

// ---------------------------------------------------------------------
// BÁSICA: teclado de calculadora
// ---------------------------------------------------------------------
class _Basica extends StatefulWidget {
  const _Basica();
  @override
  State<_Basica> createState() => _BasicaState();
}

class _BasicaState extends State<_Basica> {
  String _visor = '0';
  double? _acumulado;     // número guardado antes do operador
  String? _operador;
  bool _novaEntrada = true; // o próximo dígito começa um número novo

  double _valor() => double.tryParse(_visor.replaceAll(',', '.')) ?? 0;

  double _aplicar(double a, String op, double b) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      default: return b == 0 ? double.nan : a / b; // divisão por zero -> Erro
    }
  }

  void _tecla(String t) {
    setState(() {
      if (_visor == 'Erro') { _visor = '0'; _acumulado = null; _operador = null; _novaEntrada = true; }
      if ('0123456789'.contains(t)) {
        _visor = _novaEntrada ? t : (_visor == '0' ? t : _visor + t);
        _novaEntrada = false;
      } else if (t == ',') {
        if (_novaEntrada) { _visor = '0,'; _novaEntrada = false; }
        else if (!_visor.contains(',')) { _visor += ','; }
      } else if (t == 'C') {
        _visor = '0'; _acumulado = null; _operador = null; _novaEntrada = true;
      } else if (t == '⌫') {
        if (!_novaEntrada) { _visor = _visor.length > 1 ? _visor.substring(0, _visor.length - 1) : '0'; }
      } else if (t == '%') {
        _visor = _fmt(_valor() / 100, casas: 8);
        _novaEntrada = true;
      } else if (t == '=') {
        if (_acumulado != null && _operador != null) {
          _visor = _fmt(_aplicar(_acumulado!, _operador!, _valor()), casas: 8);
          _acumulado = null; _operador = null; _novaEntrada = true;
        }
      } else { // + - × ÷
        if (_acumulado != null && _operador != null && !_novaEntrada) {
          final r = _aplicar(_acumulado!, _operador!, _valor());
          _visor = _fmt(r, casas: 8);
          _acumulado = r.isNaN || r.isInfinite ? null : r;
        } else {
          _acumulado = _valor();
        }
        _operador = t;
        _novaEntrada = true;
      }
    });
  }

  Widget _botao(String t, {Color? fundo, Color cor = Cores.texto}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: () => _tecla(t),
              style: FilledButton.styleFrom(
                backgroundColor: fundo ?? Colors.white,
                foregroundColor: cor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Cores.linha)),
              ),
              child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget linha(List<Widget> filhos) => Row(children: filhos);
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Cores.verde, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_operador == null ? ' ' : '${_fmt(_acumulado ?? 0, casas: 8)} $_operador', style: const TextStyle(color: Color(0xFFB9CFC5))),
          FittedBox(child: Text(_visor, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 10),
      linha([_botao('C', cor: Cores.vermelho), _botao('⌫'), _botao('%'), _botao('÷', fundo: Cores.verdeClaro)]),
      linha([_botao('7'), _botao('8'), _botao('9'), _botao('×', fundo: Cores.verdeClaro)]),
      linha([_botao('4'), _botao('5'), _botao('6'), _botao('-', fundo: Cores.verdeClaro)]),
      linha([_botao('1'), _botao('2'), _botao('3'), _botao('+', fundo: Cores.verdeClaro)]),
      linha([_botao('0'), _botao(','), _botao('=', fundo: Cores.verde, cor: Colors.white)]),
    ]);
  }
}

// ---------------------------------------------------------------------
// PORCENTAGEM E DESCONTO
// ---------------------------------------------------------------------
class _Percentual extends StatefulWidget {
  const _Percentual();
  @override
  State<_Percentual> createState() => _PercentualState();
}

class _PercentualState extends State<_Percentual> {
  final _valor = TextEditingController();
  final _pct = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final v = lerNumero(_valor.text);
    final p = lerNumero(_pct.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _campo(_valor, 'Valor (R\$)', () => setState(() {})),
      _campo(_pct, 'Porcentagem (%)', () => setState(() {})),
      if (v != null && p != null) ...[
        _resultado('${_fmt(p)}% de ${reais(v)} = ${reais(v * p / 100)}'),
        _resultado('Com desconto de ${_fmt(p)}%: ${reais(v - v * p / 100)}'),
        _resultado('Com acréscimo de ${_fmt(p)}%: ${reais(v + v * p / 100)}'),
      ] else
        const Text('Digite o valor e a porcentagem.', style: TextStyle(color: Cores.textoSuave)),
    ]);
  }
}

// ---------------------------------------------------------------------
// REGRA DE TRÊS: se A está para B, então C está para ?
// ---------------------------------------------------------------------
class _RegraDeTres extends StatefulWidget {
  const _RegraDeTres();
  @override
  State<_RegraDeTres> createState() => _RegraDeTresState();
}

class _RegraDeTresState extends State<_RegraDeTres> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final a = lerNumero(_a.text), b = lerNumero(_b.text), c = lerNumero(_c.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Se A está para B, então C está para ?\nEx.: 2 botijões duram 8 meses; 5 botijões duram quantos meses?',
            style: TextStyle(color: Cores.textoSuave)),
      ),
      _campo(_a, 'A', () => setState(() {})),
      _campo(_b, 'B', () => setState(() {})),
      _campo(_c, 'C', () => setState(() {})),
      if (a != null && b != null && c != null)
        _resultado(a == 0 ? 'A não pode ser zero.' : 'Resultado: ${_fmt(b * c / a)}')
      else
        const Text('Preencha A, B e C.', style: TextStyle(color: Cores.textoSuave)),
    ]);
  }
}

// ---------------------------------------------------------------------
// PARCELAS (com ou sem juros)
// ---------------------------------------------------------------------
class _Parcelas extends StatefulWidget {
  const _Parcelas();
  @override
  State<_Parcelas> createState() => _ParcelasState();
}

class _ParcelasState extends State<_Parcelas> {
  final _valor = TextEditingController();
  final _n = TextEditingController();
  final _juros = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final v = lerNumero(_valor.text);
    final n = lerNumero(_n.text);
    final j = lerNumero(_juros.text) ?? 0; // juros vazio = sem juros
    String? texto;
    if (v != null && n != null && n >= 1) {
      final i = j / 100;
      // Fórmula da parcela fixa (Tabela Price). Sem juros: valor ÷ parcelas.
      final parcela = i == 0 ? v / n : v * i / (1 - math.pow(1 + i, -n));
      texto = '${_fmt(n)}x de ${reais(parcela)}\nTotal pago: ${reais(parcela * n)}\nJuros pagos: ${reais(parcela * n - v)}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _campo(_valor, 'Valor total (R\$)', () => setState(() {})),
      _campo(_n, 'Número de parcelas', () => setState(() {})),
      _campo(_juros, 'Juros ao mês (%) — deixe vazio se não tiver', () => setState(() {})),
      if (texto != null) _resultado(texto) else const Text('Digite o valor e o número de parcelas.', style: TextStyle(color: Cores.textoSuave)),
    ]);
  }
}
