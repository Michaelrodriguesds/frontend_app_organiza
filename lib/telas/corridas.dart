// =====================================================================
// corridas.dart — "Corridas (app)": análise do que você ganha rodando.
//
// Como usar: no fim do dia, registre o valor LIMPO como Receita, sempre com a
// mesma descrição (ex.: "Uber"). O app soma por dia e mostra:
//   • melhor e pior dia da semana, mês e semana do mês;
//   • efeito de feriados, vésperas e emendas nos SEUS dados;
//   • o que esperar de hoje e dos próximos 7 dias;
//   • projeção do mês e quanto falta para a sua meta.
//
// Tudo é estimativa feita só com os seus lançamentos. Dia sem lançamento conta
// como folga. "Bom/ruim" = acima/abaixo da SUA média, e só aparece quando a
// diferença é maior que a variação normal dos seus dias.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String _dm(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
String _mesAno(String ym) => '${_meses[int.parse(ym.substring(5, 7)) - 1]}/${ym.substring(2, 4)}';
Color _cor(String? t) => t == 'bom' ? Cores.ok : t == 'ruim' ? Cores.vermelho : Cores.textoSuave;
Widget _chip(String? t) => t == 'bom'
    ? const Etiqueta('ACIMA DA MÉDIA', cor: Cores.ok, fundo: Cores.verdeClaro)
    : t == 'ruim'
        ? const Etiqueta('ABAIXO DA MÉDIA', cor: Cores.vermelho, fundo: Cores.vermelhoClaro)
        : const Etiqueta('SEM DIFERENÇA CLARA', cor: Cores.textoSuave, fundo: Cores.linha);
String _conf(String? c) => c == 'alta' ? 'confiança alta' : c == 'media' ? 'confiança média' : 'confiança baixa';

/// Registra o valor líquido de um dia de corrida (vira uma Receita normal).
Future<bool> registrarDiaCorrida(BuildContext context, {String descricao = 'Uber'}) {
  return salvarForm(
    context,
    titulo: 'Registrar dia de corrida',
    rota: 'movimentacoes',
    campos: const [
      Campo('valor', 'Valor LIMPO do dia (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
      Campo('data', 'Dia', tipo: TipoCampo.data, obrigatorio: true),
    ],
    extras: {'tipo': 'receita', 'pago': true, 'descricao': descricao, 'categoria': 'outros'},
    ok: 'Dia registrado!',
  );
}

class TelaCorridas extends StatelessWidget {
  const TelaCorridas({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Corridas (app)',
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () => Api.mapa('/corridas'),
        construir: (c, d) => _Conteudo(d: d),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  final Map<String, dynamic> d;
  const _Conteudo({required this.d});

  List<Map<String, dynamic>> get _cands => (d['candidatos'] as List).cast<Map<String, dynamic>>();

  String get _nomeFonte {
    final fontes = (d['fontes'] as List).cast<String>();
    for (final c in _cands) {
      if (fontes.contains(c['chave'])) return '${c['nome']}';
    }
    return 'Uber';
  }

  /// Escolher quais lançamentos de receita contam como rendimento do app.
  Future<void> _escolherFontes(BuildContext context) async {
    final marcadas = {...(d['fontes'] as List).cast<String>()};
    final r = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Quais receitas são do app?'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Marque as descrições que você usa para lançar o valor do dia (ex.: "Uber").', style: TextStyle(color: Cores.textoSuave, fontSize: 13)),
                for (final c in _cands)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: marcadas.contains(c['chave']),
                    title: Text('${c['nome']}'),
                    subtitle: Text('${c['n']} lançamentos · ${reais(c['total'])}'),
                    onChanged: (v) => setSt(() => v == true ? marcadas.add('${c['chave']}') : marcadas.remove('${c['chave']}')),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(onPressed: marcadas.isEmpty ? null : () => Navigator.pop(ctx, marcadas.toList()), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (r != null && context.mounted) await tentar(context, () => Api.put('/eu/config', {'fontesCorridas': r}), ok: 'Salvo!');
  }

  Future<void> _meta(BuildContext context) async {
    final r = await pedir(context, 'Meta de ganho por mês', [
      Campo('metaCorridasMes', 'Quanto quer fazer por mês? (R\$, 0 = sem meta)', tipo: TipoCampo.numero, obrigatorio: true, inicial: d['metaMes']),
    ]);
    if (r != null && context.mounted) await tentar(context, () => Api.put('/eu/config', r), ok: 'Meta salva!');
  }

  @override
  Widget build(BuildContext context) {
    if (d['precisaEscolher'] == true) return _escolha(context);
    if (d['vazio'] == true) {
      return listaPadrao([
        _topo(context),
        const Vazio('Ainda não há dias registrados para esta fonte. Toque em "Registrar dia" ao terminar de rodar.'),
        _botaoRegistrar(context),
      ]);
    }
    final r = d['resumo'] as Map<String, dynamic>;
    final hoje = d['hoje'] as Map<String, dynamic>;
    final proximos = (d['proximos'] as List).cast<Map<String, dynamic>>();
    final semana = (d['semana'] as List).cast<Map<String, dynamic>>();
    final meses = (d['meses'] as List).cast<Map<String, dynamic>>();
    final sdm = (d['semanaDoMes'] as List).cast<Map<String, dynamic>>();
    final avisos = (d['avisos'] as List).cast<String>();
    return listaPadrao([
      _topo(context),
      _cartaoHoje(hoje, r),
      const Titulo('Próximos 7 dias'),
      Cartao(filho: Column(children: [for (final p in proximos.skip(1)) _linhaProximo(p)])),
      _cartaoMes(d['mes'] as Map<String, dynamic>),
      const Titulo('Por dia da semana'),
      _barras(semana.map((s) => (rotulo: '${s['nome']}'.substring(0, 3), valor: (s['media'] as num).toDouble(), n: s['n'] as int, extra: s['n'] == 0 ? '—' : '${_sinal(s['vsMedia'])}%', cor: _cor(s['tendencia'] as String?))).toList()),
      _legenda('Média por dia rodado. A cor mostra se é acima ou abaixo da sua média geral de ${reais(r['mediaDia'])}.'),
      ..._melhorPior(semana),
      const Titulo('Por mês'),
      _meses_(meses),
      if (d['melhorMes'] != null)
        Text('Melhor mês fechado: ${_mesAno(d['melhorMes']['mes'])} (${reais(d['melhorMes']['total'])}) · pior: ${_mesAno(d['piorMes']['mes'])} (${reais(d['piorMes']['total'])}).',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      const Titulo('Por semana do mês'),
      _barras(sdm.map((s) => (rotulo: '${s['semana']}ª', valor: (s['media'] as num).toDouble(), n: s['n'] as int, extra: s['n'] == 0 ? '—' : '${_sinal(s['vsMedia'])}%', cor: _cor(s['tendencia'] as String?))).toList()),
      _legenda('1ª = dias 1–7 · 2ª = 8–14 · 3ª = 15–21 · 4ª = 22–28 · 5ª = 29 em diante.'),
      const Titulo('Feriados e datas especiais'),
      _feriados(d['feriados'] as Map<String, dynamic>, (d['proximosFeriados'] as List).cast<Map<String, dynamic>>()),
      const Titulo('Resumo geral'),
      Cartao(
        filho: Column(children: [
          Row(children: [
            Expanded(child: Estatistica('Total registrado', reais(r['total']))),
            Expanded(child: Estatistica('Média por dia', reais(r['mediaDia']))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Estatistica('Dias rodados', '${d['diasRodados']}')),
            Expanded(child: Estatistica('Ritmo recente', '${r['diasPorSemana']} dias/semana')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Estatistica('Melhor dia', '${reais(r['melhorDia']['valor'])} (${_dm(r['melhorDia']['data'])})', cor: Cores.ok)),
            Expanded(child: Estatistica('Pior dia', '${reais(r['piorDia']['valor'])} (${_dm(r['piorDia']['data'])})', cor: Cores.vermelho)),
          ]),
        ]),
      ),
      for (final a in avisos) Text('• $a', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5, height: 1.4)),
      const SizedBox(height: 10),
      _botaoRegistrar(context),
    ]);
  }

  String _sinal(dynamic v) {
    final n = (v as num?)?.round() ?? 0;
    return n > 0 ? '+$n' : '$n';
  }

  Widget _botaoRegistrar(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Cores.verde, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => registrarDiaCorrida(context, descricao: _nomeFonte),
          icon: const Icon(Icons.add),
          label: const Text('Registrar dia'),
        ),
      );

  /// Linha com a fonte atual e a meta.
  Widget _topo(BuildContext context) => Row(children: [
        Expanded(
          child: ActionChip(
            avatar: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text('Fonte: $_nomeFonte', overflow: TextOverflow.ellipsis),
            onPressed: _cands.isEmpty ? null : () => _escolherFontes(context),
          ),
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: const Icon(Icons.flag_outlined, size: 18),
          label: Text((d['metaMes'] as num) > 0 ? 'Meta ${reais(d['metaMes'])}' : 'Definir meta'),
          onPressed: () => _meta(context),
        ),
      ]);

  Widget _escolha(BuildContext context) => listaPadrao([
        const Aviso(
          'Para analisar seus ganhos, lance o valor LIMPO de cada dia como Receita, sempre com a mesma descrição (ex.: "Uber"). '
          'Com 3 ou mais dias eu começo a mostrar; com 30 dias já dá para ver padrões.',
          icone: Icons.local_taxi_outlined,
          cor: Cores.azul,
          fundo: Cores.azulClaro,
        ),
        const SizedBox(height: 12),
        if (_cands.isEmpty) const Vazio('Ainda não encontrei receitas repetidas (preciso de pelo menos 3 com a mesma descrição).'),
        if (_cands.isNotEmpty) ...[
          const Titulo('Qual destas é o rendimento do app?'),
          for (final x in _cands)
            Cartao(
              aoToque: () async {
                await tentar(context, () => Api.put('/eu/config', {'fontesCorridas': [x['chave']]}), ok: 'Pronto! Analisando…');
              },
              filho: Row(children: [
                const Icon(Icons.local_taxi_outlined, color: Cores.verde),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${x['n']} lançamentos · ${reais(x['total'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Cores.textoSuave),
              ]),
            ),
        ],
        const SizedBox(height: 10),
        _botaoRegistrar(context),
      ]);

  Widget _cartaoHoje(Map<String, dynamic> h, Map<String, dynamic> r) {
    final prev = h['previsto'] as num?;
    final ja = h['jaRegistrado'] as num?;
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Hoje · ${h['diaSemana']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          _chip(h['tendencia'] as String?),
        ]),
        const SizedBox(height: 6),
        if (ja != null)
          Text('Hoje você já registrou ${reais(ja)}.', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (ja == null && prev != null) ...[
          Text(reais(prev), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          const Text('previsão para hoje', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
        ],
        if (prev == null) const Text('Ainda não tenho dias suficientes neste dia da semana para prever.', style: TextStyle(color: Cores.textoSuave)),
        const SizedBox(height: 6),
        Text('${h['motivo']} · ${_conf(h['confianca'] as String?)}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5, height: 1.35)),
        if (h['especial'] != null) Text('📅 ${h['especial']}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _linhaProximo(Map<String, dynamic> p) {
    final prev = p['previsto'] as num?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 84, child: Text('${p['diaSemana']}\n${_dm(p['data'])}', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prev == null ? 'sem dados' : reais(prev), style: TextStyle(fontWeight: FontWeight.w700, color: _cor(p['tendencia'] as String?))),
            if (p['especial'] != null) Text('${p['especial']}', style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
          ]),
        ),
        _chip(p['tendencia'] as String?),
      ]),
    );
  }

  Widget _cartaoMes(Map<String, dynamic> m) {
    final meta = m['meta'] as Map<String, dynamic>?;
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Este mês', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Estatistica('Até agora', reais(m['acumulado']))),
          Expanded(child: Estatistica('Projeção', reais(m['projecao']))),
        ]),
        const SizedBox(height: 4),
        Text('Projeção = o que já fez + os dias que ainda faltam no seu ritmo recente (${_conf(m['confianca'] as String?)}).',
            style: const TextStyle(color: Cores.textoSuave, fontSize: 12)),
        if (meta != null) ...[
          const SizedBox(height: 10),
          Progresso(meta['valor'] == 0 ? 0 : (m['acumulado'] as num) / (meta['valor'] as num)),
          const SizedBox(height: 4),
          Text(meta['atingida'] == true
              ? 'Meta de ${reais(meta['valor'])} batida! 🎉'
              : 'Faltam ${reais(meta['falta'])} para ${reais(meta['valor'])}.'
                  '${meta['porDiaRodado'] != null ? ' No seu ritmo, seriam ~${reais(meta['porDiaRodado'])} por dia rodado em ~${meta['diasDeTrabalhoEstimados']} dias.' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ]),
    );
  }

  List<Widget> _melhorPior(List<Map<String, dynamic>> semana) {
    final com = semana.where((s) => (s['n'] as int) >= 3).toList();
    if (com.length < 3) return [];
    com.sort((a, b) => (b['media'] as num).compareTo(a['media'] as num));
    final m = com.first, p = com.last;
    return [
      const SizedBox(height: 6),
      Text('Melhor: ${m['nome']} (${reais(m['media'])} em média, ${m['n']} dias). Mais fraco: ${p['nome']} (${reais(p['media'])}, ${p['n']} dias).',
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
    ];
  }

  Widget _legenda(String t) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: const TextStyle(color: Cores.textoSuave, fontSize: 12)));

  /// Barras horizontais simples (sem biblioteca de gráficos).
  Widget _barras(List<({String rotulo, double valor, int n, String extra, Color cor})> itens) {
    final maximo = itens.fold<double>(1, (m, i) => i.valor > m ? i.valor : m);
    return Cartao(
      filho: Column(children: [
        for (final i in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 38, child: Text(i.rotulo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Expanded(child: Progresso(i.valor / maximo, cor: i.cor)),
              SizedBox(width: 78, child: Text(i.n == 0 ? '—' : reais(i.valor), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
              SizedBox(width: 44, child: Text(i.extra, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: i.cor))),
            ]),
          ),
      ]),
    );
  }

  Widget _meses_(List<Map<String, dynamic>> meses) {
    final maximo = meses.fold<double>(1, (m, i) => (i['total'] as num) > m ? (i['total'] as num).toDouble() : m);
    return Cartao(
      filho: Column(children: [
        for (final m in meses.reversed.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_mesAno(m['mes']), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (m['atual'] == true) const Etiqueta('EM ANDAMENTO', cor: Cores.azul, fundo: Cores.azulClaro),
                const Spacer(),
                Text(reais(m['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Progresso((m['total'] as num) / maximo),
              Text('${m['dias']} dias rodados · ${reais(m['mediaDia'])} por dia', style: const TextStyle(color: Cores.textoSuave, fontSize: 12)),
            ]),
          ),
      ]),
    );
  }

  Widget _feriados(Map<String, dynamic> f, List<Map<String, dynamic>> prox) {
    String linha(String nome, Map<String, dynamic> g) {
      final n = g['n'] as int;
      if (n == 0) return '$nome: nenhum dia seu ainda';
      final fator = g['fator'] as num?;
      return '$nome: ${reais(g['media'])} em média ($n dia${n == 1 ? '' : 's'})${fator != null ? ' · ${fator >= 1 ? '+' : ''}${((fator - 1) * 100).round()}% vs um dia comum da mesma semana' : ''}';
    }

    final registros = (f['registros'] as List).cast<Map<String, dynamic>>();
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dia comum: ${reais((f['normal'] as Map)['media'])} em média (${(f['normal'] as Map)['n']} dias)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(linha('Feriados', f['feriado'] as Map<String, dynamic>), style: const TextStyle(height: 1.4)),
        Text(linha('Vésperas', f['vespera'] as Map<String, dynamic>), style: const TextStyle(height: 1.4)),
        Text(linha('Emendas', f['emenda'] as Map<String, dynamic>), style: const TextStyle(height: 1.4)),
        if (registros.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Quando você rodou em data especial:', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          for (final x in registros.take(6)) Text('• ${_dm(x['data'])} ${x['nome']}: ${reais(x['valor'])}', style: const TextStyle(fontSize: 13)),
        ],
        if (prox.isNotEmpty) ...[
          const Divider(height: 22),
          const Text('Próximos feriados', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final x in prox.take(5))
            Text('• ${_dm(x['data'])} ${x['nome']} (${x['diasAte'] == 0 ? 'hoje' : 'em ${x['diasAte']} dias'})', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 4),
          const Text('Feriados municipais não estão incluídos. Quanto mais feriados você rodar e registrar, mais o app aprende como eles funcionam para você.',
              style: TextStyle(color: Cores.textoSuave, fontSize: 12)),
        ],
      ]),
    );
  }
}
