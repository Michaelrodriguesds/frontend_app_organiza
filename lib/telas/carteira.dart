// =====================================================================
// carteira.dart — a tela inicial em formato de "carteira digital":
// saldo (com botão de ocultar), atalhos (extrato, guardado, anotações), cartão
// da conta, gráfico dos últimos 6 meses, gastos por categoria e movimentações.
//
// ATENÇÃO: o saldo é calculado com o que VOCÊ registrou (ou importou do
// extrato do banco). Não é consultado no banco — e o app nunca grava saldo:
// só a API calcula, a partir das movimentações.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'assistente.dart';
import 'busca.dart';
import 'extrato.dart';
import 'inicio.dart';
import 'metas.dart';
import 'notas.dart';
import 'registro_rapido.dart';

const _verdeEscuro = Color(0xFF123530);
const _destaque = Color(0xFFC9E265);

/// Lembra (neste aparelho) se o saldo está oculto.
class SaldoOculto {
  static final ValueNotifier<bool> oculto = ValueNotifier<bool>(false);
  static bool _lido = false;

  static Future<void> carregar() async {
    if (_lido) return;
    final p = await SharedPreferences.getInstance();
    oculto.value = p.getBool('saldo_oculto') ?? false;
    _lido = true;
  }

  static Future<void> alternar() async {
    oculto.value = !oculto.value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('saldo_oculto', oculto.value);
  }
}

String _v(num? n, bool oculto) => oculto ? 'R\$ ••••' : reais(n);

class TelaCarteira extends StatefulWidget {
  const TelaCarteira({super.key});
  @override
  State<TelaCarteira> createState() => _TelaCarteiraState();
}

class _TelaCarteiraState extends State<TelaCarteira> {
  @override
  void initState() {
    super.initState();
    SaldoOculto.carregar();
  }

  void _abrir(Widget tela) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));

  @override
  Widget build(BuildContext context) {
    final nome = (Api.usuario?['nome'] ?? '').toString().split(' ').first;
    return Pagina(
      titulo: 'Olá, $nome',
      largura: 1000,
      fab: botaoMais(() => registroRapido(context), dica: 'Registrar'),
      acoes: [
        ValueListenableBuilder<bool>(
          valueListenable: SaldoOculto.oculto,
          builder: (_, oc, _) => IconButton(
            icon: Icon(oc ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: oc ? 'Mostrar saldo' : 'Ocultar saldo',
            onPressed: SaldoOculto.alternar,
          ),
        ),
        IconButton(icon: const Icon(Icons.search), tooltip: 'Buscar', onPressed: () => _abrir(const TelaBusca())),
      ],
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () async {
          final d = await Api.mapa('/carteira');
          await Api.eu(); // atualiza dias de teste restantes
          return d;
        },
        construir: (c, d) => ValueListenableBuilder<bool>(
          valueListenable: SaldoOculto.oculto,
          builder: (_, oc, _) => _corpo(c, d, oc),
        ),
      ),
    );
  }

  Widget _corpo(BuildContext c, Map<String, dynamic> d, bool oc) {
    final diasTeste = Api.usuario?['diasRestantes'];
    final esquerda = <Widget>[
      if (diasTeste != null && diasTeste <= 7)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Seu teste grátis termina em $diasTeste dia(s).', style: const TextStyle(color: Cores.ambar, fontWeight: FontWeight.w600)),
        ),
      _cartaoConta(d, oc),
      const SizedBox(height: 14),
      _acoes(),
      const ResumoAssistente(),
      Aviso(d['aviso']?.toString() ?? '', icone: Icons.info_outline),
      const Titulo('Este mês'),
      Row(children: [
        Expanded(child: _resumo('Entradas', (d['mesAtual'] as Map)['entradas'], Cores.ok, Icons.south_west, oc)),
        const SizedBox(width: 10),
        Expanded(child: _resumo('Saídas', (d['mesAtual'] as Map)['saidas'], Cores.vermelho, Icons.north_east, oc)),
      ]),
      const SizedBox(height: 10),
      _grafico((d['meses'] as List).cast<Map<String, dynamic>>()),
    ];
    final categorias = (d['porCategoria'] as List).cast<Map<String, dynamic>>();
    final contas = (d['contas'] as List).cast<Map<String, dynamic>>();
    final ultimas = (d['ultimas'] as List).cast<Map<String, dynamic>>();
    final direita = <Widget>[
      const Titulo('Para onde foi o dinheiro (mês)'),
      if (categorias.isEmpty) const Vazio('Sem saídas neste mês.'),
      if (categorias.isNotEmpty) _categorias(categorias, oc),
      if (contas.isNotEmpty) ...[
        const Titulo('Minhas contas'),
        for (final k in contas)
          Cartao(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            filho: Row(children: [
              const Icon(Icons.account_balance_outlined, color: Cores.verde),
              const SizedBox(width: 12),
              Expanded(child: Text('${k['nome']}', style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(_v(k['saldoAtual'], oc), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
      Row(children: [
        const Expanded(child: Titulo('Últimas movimentações')),
        TextButton(onPressed: () => _abrir(const TelaExtrato()), child: const Text('Ver extrato')),
      ]),
      if (ultimas.isEmpty) const Vazio('Nada registrado ainda. Toque em "Adicionar" para começar.'),
      for (final m in ultimas) LinhaExtrato(m, oculto: oc),
      const SizedBox(height: 6),
      Cartao(
        aoToque: () => _abrir(const TelaInicio()),
        filho: const Row(children: [
          Icon(Icons.insights_outlined, color: Cores.verde),
          SizedBox(width: 12),
          Expanded(child: Text('Situação financeira: contas a pagar, previsões e alertas', style: TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right, color: Cores.textoSuave),
        ]),
      ),
    ];

    return LayoutBuilder(builder: (ctx, caixa) {
      final largo = caixa.maxWidth >= 820; // computador: duas colunas
      if (!largo) return listaPadrao([...esquerda, ...direita]);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: esquerda)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: direita)),
          ]),
        ],
      );
    });
  }

  // ---- cartão visual da conta ----
  Widget _cartaoConta(Map<String, dynamic> d, bool oc) {
    final nome = (Api.usuario?['nome'] ?? '').toString().toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Cores.verde, _verdeEscuro], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Organiza+', style: TextStyle(color: _destaque, fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          const Icon(Icons.contactless_outlined, color: Colors.white54),
        ]),
        const SizedBox(height: 18),
        const Text('Saldo disponível', style: TextStyle(color: Color(0xFFB9CFC5))),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(_v(d['saldo'], oc), key: ValueKey(oc), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _mini('Guardado', _v(d['guardado'], oc)),
          _mini('Livre', _v(d['livre'], oc)),
        ]),
        const SizedBox(height: 16),
        Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, letterSpacing: 1.6, fontSize: 12.5)),
        const Text('CARTEIRA PESSOAL', style: TextStyle(color: Colors.white38, letterSpacing: 1.6, fontSize: 10.5)),
      ]),
    );
  }

  Widget _mini(String r, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r, style: const TextStyle(color: Color(0xFFB9CFC5), fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      );

  // ---- botões de atalho ----
  Widget _acoes() {
    Widget b(IconData i, String t, VoidCallback f) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: f,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Cores.linha)),
                  child: Icon(i, color: Cores.verde),
                ),
                const SizedBox(height: 6),
                Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Row(children: [
      b(Icons.receipt_long_outlined, 'Extrato', () => _abrir(const TelaExtrato())),
      b(Icons.savings_outlined, 'Guardado', () => _abrir(const TelaMetas())),
      b(Icons.sticky_note_2_outlined, 'Anotações', () => _abrir(const TelaNotas())),
    ]);
  }

  Widget _resumo(String r, dynamic v, Color cor, IconData i, bool oc) => Cartao(
        filho: Row(children: [
          Icon(i, color: cor, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Estatistica(r, _v(v as num?, oc), cor: cor)),
        ]),
      );

  // ---- gráfico dos últimos 6 meses (barras feitas à mão: sem biblioteca extra) ----
  Widget _grafico(List<Map<String, dynamic>> meses) {
    double maximo = 1;
    for (final m in meses) {
      maximo = [maximo, (m['entradas'] as num).toDouble(), (m['saidas'] as num).toDouble()].reduce((a, b) => a > b ? a : b);
    }
    const nomes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    Widget barra(double v, Color cor) => Container(
          width: 14,
          height: 4 + 96 * (v / maximo),
          decoration: BoxDecoration(color: cor, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        );
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Entradas x saídas (6 meses)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(
          height: 125,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final m in meses)
              Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  barra((m['entradas'] as num).toDouble(), Cores.ok),
                  const SizedBox(width: 3),
                  barra((m['saidas'] as num).toDouble(), Cores.vermelho),
                ]),
                const SizedBox(height: 4),
                Text(nomes[((m['mes'] as num).toInt() - 1) % 12], style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
              ]),
          ]),
        ),
        const SizedBox(height: 8),
        const Row(children: [
          Icon(Icons.circle, size: 10, color: Cores.ok),
          SizedBox(width: 4),
          Text('Entradas', style: TextStyle(fontSize: 12)),
          SizedBox(width: 14),
          Icon(Icons.circle, size: 10, color: Cores.vermelho),
          SizedBox(width: 4),
          Text('Saídas', style: TextStyle(fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _categorias(List<Map<String, dynamic>> lista, bool oc) {
    final total = lista.fold<double>(0, (s, x) => s + (x['total'] as num).toDouble());
    return Cartao(
      filho: Column(children: [
        for (final x in lista.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(rotuloCategoria(x['categoria']), style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(_v(x['total'] as num?, oc), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Progresso(total == 0 ? 0 : (x['total'] as num).toDouble() / total),
            ]),
          ),
      ]),
    );
  }
}
