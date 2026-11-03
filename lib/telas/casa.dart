// =====================================================================
// casa.dart — Casa: ESTOQUE (gás, água, ração...) e despesas da casa.
//
// Como a previsão funciona:
//  1. Você diz quanto dura 1 unidade (ex.: botijão = 120 dias). É um chute inicial.
//  2. Cada vez que toca em "Acabou 1", o app guarda quantos dias ela durou DE VERDADE.
//  3. Com 2+ registros, a previsão passa a usar a média real (histórico).
// Sempre é uma ESTIMATIVA, não uma certeza.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> unidades = {
  'un': 'unidade',
  'botijão': 'botijão',
  'galão': 'galão',
  'litro': 'litro',
  'kg': 'kg',
  'pacote': 'pacote',
  'caixa': 'caixa',
};

Future<bool> editarItem(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Novo item de estoque' : 'Editar item',
      rota: 'estoque',
      registro: registro,
      campos: const [
        Campo('nome', 'Nome (ex.: Gás, Água, Ração)', obrigatorio: true),
        Campo('unidade', 'Unidade', tipo: TipoCampo.opcoes, opcoes: unidades),
        Campo('quantidade', 'Quantidade que tem agora', tipo: TipoCampo.numero, obrigatorio: true, inicial: 0),
        Campo('duracaoDias', 'Quanto dura 1 unidade? (em dias)', tipo: TipoCampo.numero),
      ],
    );

/// "Comprei": entra no estoque E vira despesa de uma vez só.
Future<bool> comprarItem(BuildContext context, Map<String, dynamic> item) async {
  final r = await pedir(context, 'Comprei: ${item['nome']}', const [
    Campo('quantidade', 'Quantidade comprada', tipo: TipoCampo.numero, obrigatorio: true),
    Campo('valor', 'Valor total pago (R\$)', tipo: TipoCampo.numero),
    Campo('data', 'Data da compra', tipo: TipoCampo.data, obrigatorio: true),
  ]);
  if (r == null || !context.mounted) return false;
  return tentar(context, () => Api.post('/estoque/${item['_id']}/comprar', r),
      ok: 'Compra registrada — estoque, despesa e previsão atualizados.');
}

/// Escolhe o item e registra a compra (usado pelo botão "+" do início).
Future<void> compraRapida(BuildContext context) async {
  final itens = await listaOuAviso(context, 'estoque');
  if (itens == null || !context.mounted) return;
  if (itens.isEmpty) {
    aviso(context, 'Primeiro cadastre o item que você controla (ex.: Gás).');
    await editarItem(context);
    return;
  }
  final id = await escolher(context, 'Qual item você comprou?', {for (final i in itens) (i['_id'] as String): '${i['nome']}'});
  if (id == null || !context.mounted) return;
  await comprarItem(context, itens.firstWhere((i) => i['_id'] == id));
}

String _textoPrevisao(Map<String, dynamic> item) {
  final p = item['previsao'] as Map<String, dynamic>;
  if ((item['quantidade'] as num) <= 0) return 'Estoque zerado.';
  if (p['fim'] == null) return p['duracao'] == null ? 'Informe quanto dura 1 unidade para ver a previsão.' : 'Previsão disponível após a próxima compra.';
  final dias = p['diasRestantes'] as int;
  final base = p['fonte'] == 'histórico' ? 'o histórico indica' : 'pela estimativa configurada';
  final quando = dias < 0 ? 'já deveria ter acabado' : dias == 0 ? 'deve acabar hoje' : 'deve acabar em aproximadamente $dias dia(s)';
  return 'Previsão: $quando ($base).';
}

class TelaCasa extends StatefulWidget {
  const TelaCasa({super.key});
  @override
  State<TelaCasa> createState() => _TelaCasaState();
}

class _TelaCasaState extends State<TelaCasa> {
  String _aba = 'estoque'; // estoque | despesas

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Casa',
      fab: _aba == 'estoque' ? botaoMais(() => editarItem(context), dica: 'Novo item') : null,
      corpo: _aba == 'estoque' ? _estoque() : _despesas(),
    );
  }

  Widget _abas() => SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'estoque', label: Text('Estoque')),
          ButtonSegment(value: 'despesas', label: Text('Despesas da casa')),
        ],
        selected: {_aba},
        onSelectionChanged: (s) => setState(() => _aba = s.first),
      );

  // ---------- ESTOQUE ----------
  Widget _estoque() => Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('estoque'),
        construir: (c, itens) => listaPadrao([
          _abas(),
          const SizedBox(height: 14),
          if (itens.isEmpty) const Vazio('Nenhum item controlado. Toque no + para cadastrar (ex.: Gás, Água).'),
          for (final it in itens) _cartaoItem(c, it),
        ]),
      );

  Widget _cartaoItem(BuildContext context, Map<String, dynamic> it) {
    final qtd = it['quantidade'] as num;
    final p = it['previsao'] as Map<String, dynamic>;
    final ultima = qtd == 1;
    final acabou = qtd <= 0;

    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(child: Text(it['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (acabou) const Etiqueta('ACABOU', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
              if (ultima) const Etiqueta('ÚLTIMA UNIDADE', cor: Cores.ambar, fundo: Cores.ambarClaro),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'editar') editarItem(context, registro: it);
              if (v == 'historico') _historico(context, it);
              if (v == 'excluir') excluir(context, 'estoque', it['_id'], nome: '"${it['nome']}"');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'historico', child: Text('Ver histórico')),
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'excluir', child: Text('Excluir')),
            ],
          ),
        ]),
        Text('${numeroParaCampo(qtd)} ${it['unidade']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Cores.verde)),
        if (ultima) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Atenção: este é seu último(a) em uso.', style: TextStyle(color: Cores.ambar, fontWeight: FontWeight.w600))),
        const SizedBox(height: 6),
        Text(_textoPrevisao(it), style: const TextStyle(color: Cores.textoSuave, height: 1.3)),
        if ((p['amostras'] as int) >= 2)
          Text(
            'Configurada: ${it['duracaoDias'] ?? '-'} dias · Média real: ${p['duracao']} dias (${p['amostras']} registros'
            '${p['confiavel'] == true ? ', estimativa mais confiável' : ''})',
            style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilledButton.tonalIcon(
            onPressed: () => comprarItem(context, it),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Comprei'),
          ),
          OutlinedButton.icon(
            onPressed: acabou
                ? null
                : () => tentar(context, () => Api.post('/estoque/${it['_id']}/consumir'), ok: 'Registrado! A previsão foi recalculada.'),
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            label: const Text('Acabou 1'),
          ),
        ]),
      ]),
    );
  }

  void _historico(BuildContext context, Map<String, dynamic> it) {
    final compras = (it['compras'] as List).reversed.toList();
    final duracoes = (it['historicoDuracao'] as List);
    showModalBottomSheet(
      context: context,
      backgroundColor: Cores.fundo,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
          Text('Histórico — ${it['nome']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Titulo('Quanto cada unidade durou'),
          Text(duracoes.isEmpty ? 'Ainda sem registros. Toque em "Acabou 1" quando terminar uma unidade.' : duracoes.map((d) => '$d dias').join(' · ')),
          const Titulo('Compras'),
          if (compras.isEmpty) const Text('Nenhuma compra registrada.'),
          for (final cp in compras)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${numeroParaCampo(cp['quantidade'] ?? 0)} ${it['unidade']}'),
              subtitle: Text(dataBR(cp['data'])),
              trailing: Text(reais(cp['valor'] ?? 0)),
            ),
        ]),
      ),
    );
  }

  // ---------- DESPESAS DA CASA (lançamentos da categoria "casa") ----------
  Widget _despesas() => Carregador<List<Map<String, dynamic>>>(
        carregar: () async => (await Api.lista('movimentacoes')).where((m) => m['categoria'] == 'casa' && m['pago'] == true).toList(),
        construir: (c, lista) {
          final total = lista.fold<double>(0, (s, m) => s + (m['valor'] as num).toDouble());
          return listaPadrao([
            _abas(),
            const SizedBox(height: 14),
            Text('Total gasto com a casa: ${reais(total)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Para aparecer aqui, lance a despesa na categoria "Casa" (em Finanças).', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
            const SizedBox(height: 12),
            if (lista.isEmpty) const Vazio('Nenhuma despesa da casa ainda.'),
            for (final m in lista)
              Cartao(
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(dataBR(m['data']), style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                  Text(reais(m['valor']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]);
        },
      );
}
