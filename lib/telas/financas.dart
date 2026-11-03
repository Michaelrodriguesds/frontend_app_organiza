// =====================================================================
// financas.dart — despesas, receitas, contas a pagar e a receber.
//
// Conceito importante (não misturar!):
//   Despesa / Receita  = já aconteceu (dinheiro já saiu ou entrou)
//   Conta a pagar      = vai sair (pendente até você marcar como pago)
//   A receber          = vai entrar (pendente até marcar como recebido)
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';
import 'contas.dart';

const Map<String, String> tiposLancamento = {
  'despesa': 'Despesa (já paguei)',
  'receita': 'Receita (já recebi)',
  'a_pagar': 'Conta a pagar',
  'a_receber': 'A receber (ainda não recebi)',
};

/// Formulário de lançamento. Usado pela tela de Finanças e pelo botão "+".
///  tipo:     se já souber o tipo, não pergunta.
///  registro: se informado, é uma edição.
Future<bool> novoLancamento(BuildContext context, {String? tipo, Map<String, dynamic>? registro}) async {
  String? t = (registro?['tipo'] as String?) ?? tipo;
  t ??= await escolher(context, 'O que deseja registrar?', tiposLancamento);
  if (t == null || !context.mounted) return false;

  final pendente = t == 'a_pagar' || t == 'a_receber';
  final contas = await listaOuAviso(context, 'contas') ?? [];
  if (!context.mounted) return false;

  return salvarForm(
    context,
    titulo: tiposLancamento[t]!,
    rota: 'movimentacoes',
    registro: registro,
    campos: [
      const Campo('descricao', 'O que foi?', obrigatorio: true),
      const Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
      Campo('data', pendente ? 'Vence / previsto para' : 'Data', tipo: TipoCampo.data, obrigatorio: true),
      const Campo('categoria', 'Categoria', tipo: TipoCampo.opcoes, opcoes: categorias, inicial: 'outros'),
      if (contas.isNotEmpty)
        Campo('contaId', 'Conta ou cartão', tipo: TipoCampo.opcoes, opcoes: {
          '': 'Nenhuma',
          for (final c in contas) (c['_id'] as String): (c['nome'] as String),
        }),
    ],
    // "tipo" e "pago" só são definidos ao CRIAR
    extras: registro == null ? {'tipo': t, 'pago': !pendente} : const {},
    ok: 'Registrado!',
  );
}

class TelaFinancas extends StatefulWidget {
  const TelaFinancas({super.key});
  @override
  State<TelaFinancas> createState() => _TelaFinancasState();
}

class _TelaFinancasState extends State<TelaFinancas> {
  String _filtro = 'pagar'; // pagar | receber | feito

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Finanças',
      acoes: [
        IconButton(
          icon: const Icon(Icons.account_balance_outlined),
          tooltip: 'Contas e cartões',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaContas())),
        ),
      ],
      fab: botaoMais(() => novoLancamento(context), dica: 'Novo lançamento'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('movimentacoes'),
        construir: (c, todas) {
          // Pendente = conta a pagar/receber que ainda não foi paga.
          bool pendente(Map m) => (m['tipo'] == 'a_pagar' || m['tipo'] == 'a_receber') && m['pago'] != true;

          final lista = todas.where((m) {
            if (_filtro == 'pagar') return m['tipo'] == 'a_pagar' && m['pago'] != true;
            if (_filtro == 'receber') return m['tipo'] == 'a_receber' && m['pago'] != true;
            return !pendente(m);
          }).toList();
          // Pendentes: do vencimento mais próximo para o mais distante.
          if (_filtro != 'feito') lista.sort((a, b) => a['data'].toString().compareTo(b['data'].toString()));

          final total = lista.fold<double>(0, (s, m) => s + (m['valor'] as num).toDouble());
          final rotuloTotal = _filtro == 'pagar' ? 'Total a pagar' : _filtro == 'receber' ? 'Total a receber' : 'Últimos lançamentos';

          return listaPadrao([
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'pagar', label: Text('A pagar')),
                ButtonSegment(value: 'receber', label: Text('A receber')),
                ButtonSegment(value: 'feito', label: Text('Realizado')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
            const SizedBox(height: 14),
            if (_filtro != 'feito')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('$rotuloTotal: ${reais(total)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            if (lista.isEmpty) const Vazio('Nada por aqui. Toque no + para registrar.'),
            for (final m in lista) _item(c, m),
          ]);
        },
      ),
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> m) {
    final tipo = m['tipo'] as String;
    final entrada = tipo == 'receita' || tipo == 'a_receber';
    final pendente = (tipo == 'a_pagar' || tipo == 'a_receber') && m['pago'] != true;
    final venc = lerIso(m['data']);
    final atrasada = pendente && venc != null && DateUtils.dateOnly(venc).isBefore(DateUtils.dateOnly(DateTime.now()));

    return Cartao(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      aoToque: () => novoLancamento(context, registro: m),
      filho: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(m['descricao'], style: const TextStyle(fontWeight: FontWeight.w600))),
              if (atrasada && tipo == 'a_pagar') const Etiqueta('PENDENTE', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
              if (pendente && !atrasada) Etiqueta(tipo == 'a_pagar' ? 'A PAGAR' : 'A RECEBER', cor: Cores.azul, fundo: Cores.azulClaro),
            ]),
            const SizedBox(height: 2),
            Text('${dataBR(m['data'])} · ${rotuloCategoria(m['categoria'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
        Text('${entrada ? '+' : '-'} ${reais(m['valor'])}', style: TextStyle(fontWeight: FontWeight.w700, color: entrada ? Cores.ok : Cores.texto)),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'pago') {
              await tentar(context, () => Api.put('/movimentacoes/${m['_id']}', {'pago': true}),
                  ok: tipo == 'a_pagar' ? 'Marcado como pago.' : 'Marcado como recebido.');
            } else if (v == 'editar') {
              await novoLancamento(context, registro: m);
            } else {
              await excluir(context, 'movimentacoes', m['_id'], nome: '"${m['descricao']}"');
            }
          },
          itemBuilder: (_) => [
            if (pendente) PopupMenuItem(value: 'pago', child: Text(tipo == 'a_pagar' ? 'Marcar como pago' : 'Marcar como recebido')),
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
          ],
        ),
      ]),
    );
  }
}
