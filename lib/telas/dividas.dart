// =====================================================================
// dividas.dart — dívidas e empréstimos.
//   "Eu devo"       = você precisa pagar
//   "Devem a mim"   = você tem a receber
// Ao registrar um pagamento, o app lança sozinho a despesa/receita no
// financeiro (uma vez só).
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> sentidos = {'devo': 'Eu devo', 'devem_me': 'Devem a mim'};

Future<bool> editarDivida(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Nova dívida / empréstimo' : 'Editar',
      rota: 'dividas',
      registro: registro,
      campos: const [
        Campo('sentido', 'Situação', tipo: TipoCampo.opcoes, opcoes: sentidos),
        Campo('pessoa', 'Pessoa ou empresa', obrigatorio: true),
        Campo('valor', 'Valor total (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
        Campo('vencimento', 'Vencimento', tipo: TipoCampo.data),
        Campo('obs', 'Observação'),
      ],
    );

Future<bool> registrarPagamento(BuildContext context, Map<String, dynamic> d) async {
  final devo = d['sentido'] == 'devo';
  final r = await pedir(context, devo ? 'Pagamento a ${d['pessoa']}' : 'Recebimento de ${d['pessoa']}', const [
    Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
    Campo('data', 'Data', tipo: TipoCampo.data, obrigatorio: true),
  ]);
  if (r == null || !context.mounted) return false;
  return tentar(context, () => Api.post('/dividas/${d['_id']}/pagamentos', r), ok: 'Registrado — já entrou no financeiro.');
}

class TelaDividas extends StatelessWidget {
  const TelaDividas({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Dívidas e empréstimos',
      fab: botaoMais(() => editarDivida(context), dica: 'Nova dívida'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('dividas'),
        construir: (c, lista) {
          double falta(Map<String, dynamic> d) => (d['valor'] as num).toDouble() - (d['pago'] as num).toDouble();
          final devo = lista.where((d) => d['sentido'] == 'devo').fold<double>(0, (s, d) => s + falta(d));
          final devem = lista.where((d) => d['sentido'] == 'devem_me').fold<double>(0, (s, d) => s + falta(d));
          return listaPadrao([
            Cartao(
              filho: Row(children: [
                Expanded(child: Estatistica('Eu devo', reais(devo), cor: Cores.vermelho)),
                Expanded(child: Estatistica('Devem a mim', reais(devem), cor: Cores.ok)),
              ]),
            ),
            const SizedBox(height: 4),
            if (lista.isEmpty) const Vazio('Nenhum registro. Toque no + para adicionar.'),
            for (final d in lista) _item(c, d, falta(d)),
          ]);
        },
      ),
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> d, double falta) {
    final devo = d['sentido'] == 'devo';
    final quitada = falta <= 0;
    final cor = quitada ? Cores.ok : (devo ? Cores.vermelho : Cores.azul);
    final fundo = quitada ? Cores.verdeClaro : (devo ? Cores.vermelhoClaro : Cores.azulClaro);
    return Cartao(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      aoToque: () => editarDivida(context, registro: d),
      filho: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(d['pessoa'], style: const TextStyle(fontWeight: FontWeight.w700))),
              Etiqueta(quitada ? 'QUITADA' : (devo ? 'EU DEVO' : 'DEVEM A MIM'), cor: cor, fundo: fundo),
            ]),
            const SizedBox(height: 2),
            Text(
              'Total ${reais(d['valor'])} · pago ${reais(d['pago'])}${d['vencimento'] != null ? ' · vence ${dataBR(d['vencimento'])}' : ''}',
              style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5),
            ),
            if (!quitada) Text('Falta ${reais(falta)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'pagar') registrarPagamento(context, d);
            if (v == 'editar') editarDivida(context, registro: d);
            if (v == 'excluir') excluir(context, 'dividas', d['_id'], nome: '"${d['pessoa']}"');
          },
          itemBuilder: (_) => [
            if (!quitada) PopupMenuItem(value: 'pagar', child: Text(devo ? 'Registrar pagamento' : 'Registrar recebimento')),
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
          ],
        ),
      ]),
    );
  }
}
