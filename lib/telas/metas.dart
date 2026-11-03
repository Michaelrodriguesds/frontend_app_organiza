// =====================================================================
// metas.dart — metas e compras futuras (viagem, moto, reserva...).
// IMPORTANTE: metas NÃO são despesas. Elas aparecem como "planejado",
// separadas do dinheiro real.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> tiposMeta = {'meta': 'Meta (guardar dinheiro)', 'compra': 'Compra / serviço futuro'};
const Map<String, String> prioridades = {'baixa': 'Baixa', 'media': 'Média', 'alta': 'Alta'};

Future<bool> editarMeta(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Nova meta' : 'Editar meta',
      rota: 'metas',
      registro: registro,
      campos: const [
        Campo('nome', 'Nome (ex.: Viagem, Moto, Computador)', obrigatorio: true),
        Campo('tipo', 'Tipo', tipo: TipoCampo.opcoes, opcoes: tiposMeta),
        Campo('valorAlvo', 'Valor necessário (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
        Campo('prazo', 'Data desejada', tipo: TipoCampo.data),
        Campo('prioridade', 'Prioridade', tipo: TipoCampo.opcoes, opcoes: prioridades, inicial: 'media'),
        Campo('obs', 'Observação'),
      ],
    );

/// Guardar (ou retirar) dinheiro de uma meta.
Future<bool> registrarAporte(BuildContext context, Map<String, dynamic> meta) async {
  final r = await pedir(context, 'Guardar dinheiro — ${meta['nome']}', const [
    Campo('acao', 'O que fazer?', tipo: TipoCampo.opcoes, opcoes: {'guardar': 'Guardar', 'retirar': 'Retirar'}),
    Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
    Campo('data', 'Data', tipo: TipoCampo.data, obrigatorio: true),
    Campo('obs', 'Observação (ex.: dinheiro adicionado na conta X)'),
  ]);
  if (r == null || !context.mounted) return false;
  final valor = (r['valor'] as num).toDouble();
  return tentar(
    context,
    () => Api.post('/metas/${meta['_id']}/aportes', {
      'valor': r['acao'] == 'retirar' ? -valor : valor,
      'data': r['data'],
      'obs': r['obs'],
    }),
    ok: 'Registrado!',
  );
}

/// Escolhe a meta e guarda dinheiro (usado pelo botão "+" do início).
Future<void> aporteRapido(BuildContext context) async {
  final metas = await listaOuAviso(context, 'metas');
  if (metas == null || !context.mounted) return;
  if (metas.isEmpty) {
    aviso(context, 'Primeiro crie uma meta.');
    await editarMeta(context);
    return;
  }
  final id = await escolher(context, 'Em qual meta?', {for (final m in metas) (m['_id'] as String): '${m['nome']}'});
  if (id == null || !context.mounted) return;
  await registrarAporte(context, metas.firstWhere((m) => m['_id'] == id));
}

class TelaMetas extends StatelessWidget {
  const TelaMetas({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Metas',
      fab: botaoMais(() => editarMeta(context), dica: 'Nova meta'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('metas'),
        construir: (c, metas) => listaPadrao([
          const Text('Metas e compras futuras não contam como despesa: ficam separadas, como planejamento.', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 14),
          if (metas.isEmpty) const Vazio('Nenhuma meta ainda. Toque no + para criar.'),
          for (final m in metas)
            Cartao(
              aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalheMeta(metaId: m['_id']))),
              filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(m['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  Text('${m['percentual']}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Cores.verde)),
                ]),
                const SizedBox(height: 8),
                Progresso((m['percentual'] as num) / 100),
                const SizedBox(height: 6),
                Text('${reais(m['acumulado'])} de ${reais(m['valorAlvo'])} · faltam ${reais(m['faltante'])}',
                    style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                if (m['prazo'] != null) Text('Data desejada: ${dataBR(m['prazo'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class DetalheMeta extends StatelessWidget {
  final String metaId;
  const DetalheMeta({super.key, required this.metaId});

  @override
  Widget build(BuildContext context) {
    return Carregador<Map<String, dynamic>?>(
      titulo: 'Meta',
      carregar: () async {
        final metas = await Api.lista('metas');
        final achadas = metas.where((m) => m['_id'] == metaId);
        return achadas.isEmpty ? null : achadas.first;
      },
      construir: (c, m) {
        if (m == null) return const Pagina(titulo: 'Meta', corpo: Center(child: Text('Meta não encontrada.')));
        final aportes = (m['aportes'] as List).reversed.toList(); // mais recentes primeiro
        return Pagina(
          titulo: m['nome'],
          acoes: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editarMeta(c, registro: m)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await excluir(c, 'metas', m['_id'], nome: '"${m['nome']}"') && c.mounted) Navigator.of(c).pop();
              },
            ),
          ],
          fab: FloatingActionButton.extended(
            backgroundColor: Cores.verde,
            foregroundColor: Colors.white,
            onPressed: () => registrarAporte(c, m),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Guardar dinheiro'),
          ),
          corpo: listaPadrao([
            Cartao(
              filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['percentual']}% concluído', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Cores.verde)),
                const SizedBox(height: 8),
                Progresso((m['percentual'] as num) / 100),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Estatistica('Guardado', reais(m['acumulado']))),
                  Expanded(child: Estatistica('Meta', reais(m['valorAlvo']))),
                  Expanded(child: Estatistica('Falta', reais(m['faltante']))),
                ]),
              ]),
            ),
            const Titulo('Histórico'),
            if (aportes.isEmpty) const Vazio('Nada guardado ainda. Toque em "Guardar dinheiro".'),
            for (final a in aportes)
              Cartao(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dataBR(a['data']), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if ((a['obs'] ?? '').toString().isNotEmpty) Text(a['obs'], style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                  Text('${(a['valor'] as num) >= 0 ? '+' : '-'} ${reais((a['valor'] as num).abs())}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: (a['valor'] as num) >= 0 ? Cores.ok : Cores.vermelho)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => tentar(c, () => Api.apagar('/metas/${m['_id']}/aportes/${a['_id']}'), ok: 'Removido.'),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
