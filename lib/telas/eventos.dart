// =====================================================================
// eventos.dart — aniversário, viagem, festa... com ORÇAMENTO:
// você planeja quanto vai gastar (previsto) e depois anota o gasto real.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

Future<bool> editarEvento(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Novo evento' : 'Editar evento',
      rota: 'eventos',
      registro: registro,
      campos: const [
        Campo('nome', 'Nome (ex.: Aniversário da Ana)', obrigatorio: true),
        Campo('data', 'Data', tipo: TipoCampo.data, obrigatorio: true),
        Campo('hora', 'Horário (ex.: 19:30)'),
        Campo('local', 'Local'),
        Campo('obs', 'Observação', linhas: 3),
      ],
    );

class TelaEventos extends StatelessWidget {
  const TelaEventos({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Eventos',
      fab: botaoMais(() => editarEvento(context), dica: 'Novo evento'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('eventos'),
        construir: (c, eventos) => listaPadrao([
          if (eventos.isEmpty) const Vazio('Nenhum evento ainda. Toque no + para criar.'),
          for (final e in eventos)
            Cartao(
              aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalheEvento(eventoId: e['_id']))),
              filho: Row(children: [
                const Icon(Icons.celebration_outlined, color: Cores.verde),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['nome'], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(
                      [dataBR(e['data']), if ((e['hora'] ?? '').toString().isNotEmpty) e['hora'], if ((e['local'] ?? '').toString().isNotEmpty) e['local']].join(' · '),
                      style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5),
                    ),
                    if ((e['totalPrevisto'] as num) > 0)
                      Text('Previsto ${reais(e['totalPrevisto'])} · Realizado ${reais(e['totalReal'])}', style: const TextStyle(fontSize: 12.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Cores.textoSuave),
              ]),
            ),
        ]),
      ),
    );
  }
}

class DetalheEvento extends StatelessWidget {
  final String eventoId;
  const DetalheEvento({super.key, required this.eventoId});

  Future<bool> _item(BuildContext context, Map<String, dynamic> ev, {Map<String, dynamic>? item}) async {
    final lista = item == null
        ? const [
            Campo('descricao', 'Item (ex.: Comida, Bebida, Presente)', obrigatorio: true),
            Campo('previsto', 'Valor previsto (R\$)', tipo: TipoCampo.numero),
            Campo('real', 'Valor real gasto (R\$)', tipo: TipoCampo.numero),
          ]
        : [
            Campo('descricao', 'Item', obrigatorio: true, inicial: item['descricao']),
            Campo('previsto', 'Valor previsto (R\$)', tipo: TipoCampo.numero, inicial: item['previsto']),
            Campo('real', 'Valor real gasto (R\$)', tipo: TipoCampo.numero, inicial: item['real']),
          ];
    final r = await pedir(context, item == null ? 'Novo item do orçamento' : 'Editar item', lista);
    if (r == null || !context.mounted) return false;
    final corpo = {'descricao': r['descricao'], 'previsto': r['previsto'] ?? 0, 'real': r['real'] ?? 0};
    return tentar(context, () => item == null ? Api.post('/eventos/${ev['_id']}/itens', corpo) : Api.put('/eventos/${ev['_id']}/itens/${item['_id']}', corpo));
  }

  @override
  Widget build(BuildContext context) {
    return Carregador<Map<String, dynamic>?>(
      titulo: 'Evento',
      carregar: () async {
        final lista = await Api.lista('eventos');
        final achados = lista.where((e) => e['_id'] == eventoId);
        return achados.isEmpty ? null : achados.first;
      },
      construir: (c, e) {
        if (e == null) return const Pagina(titulo: 'Evento', corpo: Center(child: Text('Evento não encontrado.')));
        final itens = (e['itens'] as List).cast<Map<String, dynamic>>();
        final dif = (e['diferenca'] as num).toDouble();
        return Pagina(
          titulo: e['nome'],
          acoes: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editarEvento(c, registro: e)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await excluir(c, 'eventos', e['_id'], nome: '"${e['nome']}"') && c.mounted) Navigator.of(c).pop();
              },
            ),
          ],
          fab: FloatingActionButton.extended(
            backgroundColor: Cores.verde,
            foregroundColor: Colors.white,
            onPressed: () => _item(c, e),
            icon: const Icon(Icons.add),
            label: const Text('Item do orçamento'),
          ),
          corpo: listaPadrao([
            Cartao(
              filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${dataBR(e['data'])}${(e['hora'] ?? '').toString().isNotEmpty ? ' às ${e['hora']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((e['local'] ?? '').toString().isNotEmpty) Text(e['local'], style: const TextStyle(color: Cores.textoSuave)),
                if ((e['obs'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e['obs'])),
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Estatistica('Previsto', reais(e['totalPrevisto']))),
                  Expanded(child: Estatistica('Realizado', reais(e['totalReal']))),
                  Expanded(
                    child: Estatistica('Diferença', '${dif > 0 ? '+' : ''}${reais(dif)}', cor: dif > 0 ? Cores.vermelho : Cores.ok),
                  ),
                ]),
              ]),
            ),
            const Titulo('Orçamento'),
            if (itens.isEmpty) const Vazio('Nenhum item ainda. Ex.: Comida R\$ 300, Bebida R\$ 150...'),
            for (final i in itens)
              Cartao(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                aoToque: () => _item(c, e, item: i),
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i['descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Previsto ${reais(i['previsto'])} · Real ${reais(i['real'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => tentar(c, () => Api.apagar('/eventos/${e['_id']}/itens/${i['_id']}'), ok: 'Item removido.'),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
