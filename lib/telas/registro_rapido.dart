// =====================================================================
// registro_rapido.dart — o botão "+" da tela inicial: "O que deseja
// registrar?". Cada opção abre o formulário certo e o app relaciona
// tudo sozinho (financeiro, veículo, estoque, agenda...).
// =====================================================================
import 'package:flutter/material.dart';
import '../componentes.dart';
import '../tema.dart';
import 'agenda.dart';
import 'casa.dart';
import 'dividas.dart';
import 'eventos.dart';
import 'financas.dart';
import 'metas.dart';
import 'notas.dart';
import 'veiculos.dart';

Future<void> registroRapido(BuildContext context) async {
  const opcoes = {
    'despesa': 'Despesa (já paguei)',
    'receita': 'Receita (já recebi)',
    'a_pagar': 'Conta a pagar',
    'a_receber': 'A receber (ainda não recebi)',
    'servico': 'Serviço do veículo',
    'estoque': 'Compra / estoque (gás, água...)',
    'meta': 'Guardar dinheiro numa meta',
    'divida': 'Dívida ou empréstimo',
    'evento': 'Evento',
    'lembrete': 'Lembrete',
    'nota': 'Nota',
  };
  final o = await escolher(context, 'O que deseja registrar?', opcoes);
  if (o == null || !context.mounted) return;

  switch (o) {
    case 'despesa':
    case 'receita':
    case 'a_pagar':
    case 'a_receber':
      await novoLancamento(context, tipo: o);
    case 'servico':
      await _servico(context);
    case 'estoque':
      await compraRapida(context);
    case 'meta':
      await aporteRapido(context);
    case 'divida':
      await editarDivida(context);
    case 'evento':
      await editarEvento(context);
    case 'lembrete':
      await editarLembrete(context);
    case 'nota':
      await editarNota(context);
  }
}

/// Serviço de veículo: primeiro pergunta qual veículo.
Future<void> _servico(BuildContext context) async {
  final veiculos = await listaOuAviso(context, 'veiculos');
  if (veiculos == null || !context.mounted) return;
  if (veiculos.isEmpty) {
    aviso(context, 'Primeiro cadastre um veículo.');
    await editarVeiculo(context);
    return;
  }
  final id = await escolher(context, 'Qual veículo?', {for (final v in veiculos) (v['_id'] as String): '${v['modelo']}'});
  if (id == null || !context.mounted) return;
  await novoServico(context, id);
}
