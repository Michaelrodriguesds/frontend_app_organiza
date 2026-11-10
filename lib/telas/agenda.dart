// =====================================================================
// agenda.dart — Agenda inteligente + Lembretes.
// A agenda NÃO é um calendário vazio: ela junta, em ordem de data, tudo que
// vem das outras áreas (contas, dívidas, manutenções, eventos, estoque,
// metas e lembretes).
// =====================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

Future<bool> editarLembrete(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Novo lembrete' : 'Editar lembrete',
      rota: 'lembretes',
      registro: registro,
      campos: const [
        Campo('titulo', 'Lembrar de quê?', obrigatorio: true),
        Campo('data', 'Quando', tipo: TipoCampo.data, obrigatorio: true),
      ],
    );

class TelaAgenda extends StatefulWidget {
  const TelaAgenda({super.key});
  @override
  State<TelaAgenda> createState() => _TelaAgendaState();
}

class _TelaAgendaState extends State<TelaAgenda> {
  String _aba = 'agenda'; // agenda | lembretes

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Agenda',
      fab: botaoMais(() => editarLembrete(context), dica: 'Novo lembrete'),
      corpo: _aba == 'agenda' ? _agenda() : _lembretes(),
    );
  }

  Widget _abas() => SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'agenda', label: Text('Próximos 90 dias')),
          ButtonSegment(value: 'lembretes', label: Text('Lembretes')),
        ],
        selected: {_aba},
        onSelectionChanged: (s) => setState(() => _aba = s.first),
      );

  /// "Hoje", "Amanhã" ou "sex, 20/11"
  String _rotuloDia(DateTime d) {
    final dif = DateUtils.dateOnly(d).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (dif == 0) return 'Hoje';
    if (dif == 1) return 'Amanhã';
    return DateFormat('EEE, dd/MM', 'pt_BR').format(d);
  }

  /// Toque num item da agenda: ações rápidas quando fizer sentido.
  Future<void> _aoTocar(BuildContext context, Map<String, dynamic> item) async {
    final id = item['id'], rota = item['rota'];
    if (id == null || rota == null) return;
    if (rota == 'movimentacoes') {
      final recebimento = item['tipo'] == 'receber';
      if (await confirmar(context, recebimento ? 'Marcar como recebido?' : 'Marcar como pago?', item['titulo'].toString(), botao: 'Sim')) {
        if (context.mounted) await tentar(context, () => Api.put('/movimentacoes/$id', {'pago': true}), ok: 'Feito!');
      }
    } else if (rota == 'lembretes') {
      await tentar(context, () => Api.put('/lembretes/$id', {'feito': true}), ok: 'Lembrete concluído.');
    }
  }

  // key: cada aba tem a sua chave, senão o Flutter reaproveita os dados da outra aba
  Widget _agenda() => Carregador<List<Map<String, dynamic>>>(
        key: const ValueKey('aba-agenda'),
        carregar: () => Api.lista('agenda?dias=90'),
        construir: (c, itens) {
          final atrasados = itens.where((i) => (i['dias'] as num) < 0).toList();
          final proximos = itens.where((i) => (i['dias'] as num) >= 0).toList();

          // Agrupa por dia (a lista já vem ordenada por data).
          final grupos = <String, List<Map<String, dynamic>>>{};
          final datas = <String, DateTime>{};
          for (final i in proximos) {
            final d = lerIso(i['data'])!;
            final chave = DateFormat('yyyy-MM-dd').format(d);
            grupos.putIfAbsent(chave, () => []).add(i);
            datas[chave] = d;
          }

          return listaPadrao([
            _abas(),
            const SizedBox(height: 6),
            if (itens.isEmpty) const Vazio('Nada com data nos próximos 90 dias. Contas, manutenções, eventos e lembretes aparecem aqui.'),
            if (atrasados.isNotEmpty) ...[
              const Titulo('Atrasados'),
              for (final i in atrasados) ItemAlerta(i, aoToque: () => _aoTocar(c, i)),
            ],
            for (final e in grupos.entries) ...[
              Titulo(_rotuloDia(datas[e.key]!)),
              for (final i in e.value) ItemAlerta(i, aoToque: () => _aoTocar(c, i)),
            ],
            const SizedBox(height: 8),
            const Text('Toque numa conta para marcar como paga/recebida, ou num lembrete para concluí-lo.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]);
        },
      );

  Widget _lembretes() => Carregador<List<Map<String, dynamic>>>(
        key: const ValueKey('aba-lembretes'),
        carregar: () => Api.lista('lembretes'),
        construir: (c, lista) => listaPadrao([
          _abas(),
          const SizedBox(height: 14),
          if (lista.isEmpty) const Vazio('Nenhum lembrete. Toque no + para criar.'),
          for (final l in lista)
            Cartao(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              aoToque: () => editarLembrete(c, registro: l),
              filho: Row(children: [
                Checkbox(
                  value: l['feito'] == true,
                  onChanged: (v) => tentar(c, () => Api.put('/lembretes/${l['_id']}', {'feito': v == true})),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      l['titulo'],
                      style: TextStyle(fontWeight: FontWeight.w600, decoration: l['feito'] == true ? TextDecoration.lineThrough : null),
                    ),
                    Text(dataBR(l['data']), style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => excluir(c, 'lembretes', l['_id'], nome: '"${l['titulo']}"'),
                ),
              ]),
            ),
        ]),
      );
}
