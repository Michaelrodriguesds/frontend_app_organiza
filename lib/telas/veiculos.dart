// =====================================================================
// veiculos.dart — seus carros/motos, histórico de serviços e próximas
// manutenções (por data OU por quilometragem — o que chegar primeiro).
//
// Ao registrar um serviço com valor, o app cria sozinho a despesa no
// financeiro: você cadastra UMA vez e aparece em tudo.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> tiposVeiculo = {'carro': 'Carro', 'moto': 'Moto', 'outro': 'Outro'};

Future<bool> editarVeiculo(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Novo veículo' : 'Editar veículo',
      rota: 'veiculos',
      registro: registro,
      campos: const [
        Campo('tipo', 'Tipo', tipo: TipoCampo.opcoes, opcoes: tiposVeiculo),
        Campo('modelo', 'Modelo (ex.: Onix, Fazer 250)', obrigatorio: true),
        Campo('marca', 'Marca'),
        Campo('ano', 'Ano', tipo: TipoCampo.numero),
        Campo('placa', 'Placa'),
        Campo('km', 'Quilometragem atual', tipo: TipoCampo.numero),
      ],
      ok: registro == null ? 'Veículo cadastrado!' : 'Veículo alterado!',
    );

/// Registra (ou edita) um serviço de um veículo.
Future<bool> novoServico(BuildContext context, String veiculoId, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Registrar serviço' : 'Editar serviço',
      rota: 'manutencoes',
      registro: registro,
      extras: {'veiculoId': veiculoId},
      campos: const [
        Campo('descricao', 'O que foi feito? (ex.: Troca de óleo)', obrigatorio: true),
        Campo('data', 'Data', tipo: TipoCampo.data, obrigatorio: true),
        Campo('valor', 'Valor pago (R\$)', tipo: TipoCampo.numero),
        Campo('km', 'Quilometragem no serviço', tipo: TipoCampo.numero),
        Campo('oficina', 'Oficina / prestador'),
        Campo('proximaData', 'Próxima manutenção em (data)', tipo: TipoCampo.data),
        Campo('proximoKm', 'Próxima manutenção aos (km)', tipo: TipoCampo.numero),
      ],
      ok: registro == null ? 'Serviço registrado — já entrou nas despesas também.' : 'Serviço alterado!',
    );

// ---------------------------------------------------------------------
// Lista de veículos
// ---------------------------------------------------------------------
class TelaVeiculos extends StatelessWidget {
  const TelaVeiculos({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Veículos',
      fab: botaoMais(() => editarVeiculo(context), dica: 'Novo veículo'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('veiculos'),
        construir: (c, lista) => listaPadrao([
          if (lista.isEmpty) const Vazio('Nenhum veículo ainda. Toque no + para cadastrar.'),
          for (final v in lista)
            Cartao(
              aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalheVeiculo(veiculoId: v['_id']))),
              filho: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Cores.verdeClaro, borderRadius: BorderRadius.circular(12)),
                  child: Icon(v['tipo'] == 'moto' ? Icons.two_wheeler : Icons.directions_car, color: Cores.verde),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${v['modelo']}${v['ano'] != null ? ' ${v['ano']}' : ''}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text('${v['km'] ?? 0} km${(v['placa'] ?? '').toString().isNotEmpty ? ' · ${v['placa']}' : ''}',
                        style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
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

// ---------------------------------------------------------------------
// Detalhe do veículo: resumo, próximas manutenções e histórico
// ---------------------------------------------------------------------
class DetalheVeiculo extends StatelessWidget {
  final String veiculoId;
  const DetalheVeiculo({super.key, required this.veiculoId});

  /// Busca o veículo e seus serviços ao mesmo tempo.
  Future<Map<String, dynamic>> _carregar() async {
    final veiculos = await Api.lista('veiculos');
    final servicos = await Api.lista('manutencoes?veiculoId=$veiculoId');
    final achados = veiculos.where((v) => v['_id'] == veiculoId);
    return {'veiculo': achados.isEmpty ? null : achados.first, 'servicos': servicos};
  }

  @override
  Widget build(BuildContext context) {
    return Carregador<Map<String, dynamic>>(
      titulo: 'Veículo',
      carregar: _carregar,
      construir: (c, d) {
        final Map<String, dynamic>? v = d['veiculo'];
        final servicos = (d['servicos'] as List).cast<Map<String, dynamic>>();

        if (v == null) {
          return Pagina(titulo: 'Veículo', corpo: const Center(child: Text('Veículo não encontrado (talvez esteja na lixeira).')));
        }

        final gasto = servicos.fold<double>(0, (s, m) => s + ((m['valor'] ?? 0) as num).toDouble());

        // Próximas manutenções: vale só o serviço mais recente de cada tipo.
        final vistos = <String>{};
        final proximas = <Map<String, dynamic>>[];
        for (final m in servicos) { // já vêm do mais novo para o mais antigo
          final chave = m['descricao'].toString().toLowerCase();
          if (vistos.add(chave) && (m['proximaData'] != null || m['proximoKm'] != null)) proximas.add(m);
        }

        return Pagina(
          titulo: '${v['modelo']}',
          acoes: [
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: () => editarVeiculo(c, registro: v)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir veículo',
              onPressed: () async {
                if (await excluir(c, 'veiculos', v['_id'], nome: '"${v['modelo']}" e seu histórico') && c.mounted) Navigator.of(c).pop();
              },
            ),
          ],
          fab: FloatingActionButton.extended(
            backgroundColor: Cores.verde,
            foregroundColor: Colors.white,
            onPressed: () => novoServico(c, veiculoId),
            icon: const Icon(Icons.build),
            label: const Text('Registrar serviço'),
          ),
          corpo: listaPadrao([
            Cartao(
              filho: Row(children: [
                Expanded(child: Estatistica('Quilometragem', '${v['km'] ?? 0} km')),
                Expanded(child: Estatistica('Gasto total', reais(gasto))),
                IconButton(
                  icon: const Icon(Icons.speed),
                  tooltip: 'Atualizar km',
                  onPressed: () => salvarForm(c,
                      titulo: 'Atualizar quilometragem',
                      rota: 'veiculos',
                      registro: v,
                      campos: const [Campo('km', 'Quilometragem atual', tipo: TipoCampo.numero, obrigatorio: true)]),
                ),
              ]),
            ),
            if (proximas.isNotEmpty) ...[
              const Titulo('Próximas manutenções'),
              for (final m in proximas)
                Cartao(
                  filho: Row(children: [
                    const Icon(Icons.event_repeat, color: Cores.azul),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            if (m['proximaData'] != null) dataBR(m['proximaData']),
                            if (m['proximoKm'] != null) 'aos ${m['proximoKm']} km',
                          ].join('  ou  '),
                          style: const TextStyle(color: Cores.azul, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ],
            const Titulo('Histórico de serviços'),
            if (servicos.isEmpty) const Vazio('Nenhum serviço registrado ainda.'),
            for (final m in servicos)
              Cartao(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                aoToque: () => novoServico(c, veiculoId, registro: m),
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['descricao'], style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          dataBR(m['data']),
                          if (m['km'] != null) '${m['km']} km',
                          if ((m['oficina'] ?? '').toString().isNotEmpty) m['oficina'],
                        ].join(' · '),
                        style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5),
                      ),
                    ]),
                  ),
                  if (((m['valor'] ?? 0) as num) > 0) Text(reais(m['valor']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  PopupMenuButton<String>(
                    onSelected: (op) => op == 'editar'
                        ? novoServico(c, veiculoId, registro: m)
                        : excluir(c, 'manutencoes', m['_id'], nome: '"${m['descricao']}"'),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
