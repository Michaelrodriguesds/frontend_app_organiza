// =====================================================================
// plano_metas.dart — "Plano das metas": quanto guardar HOJE para cada objetivo
// (inclui as RESERVAS de reposição: novo botijão de gás, novo galão de água...).
//
// Para cada meta com prazo o app mostra:
//   • quanto guardar por semana/dia e uma sugestão para hoje;
//   • se, no SEU ritmo de aportes anteriores, você chega no prazo;
//   • a chance estimada de conseguir (só aparece com pelo menos 3 semanas de
//     histórico — antes disso o app diz "sem histórico", não inventa número).
//
// Tudo é estimativa feita com os seus próprios aportes. Não é promessa e o
// dinheiro continua onde você o deixou (é organização dentro do app).
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';
import 'recorrentes.dart';

String _data(String? iso) => iso == null || iso.length < 10 ? '' : '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

({String texto, Color cor, Color fundo}) _status(String? s) => switch (s) {
      'concluida' => (texto: 'CONCLUÍDA', cor: Cores.ok, fundo: Cores.verdeClaro),
      'no_caminho' => (texto: 'NO CAMINHO', cor: Cores.ok, fundo: Cores.verdeClaro),
      'atencao' => (texto: 'ATENÇÃO', cor: Cores.ambar, fundo: Cores.ambarClaro),
      'risco' => (texto: 'EM RISCO', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
      'atrasada' => (texto: 'PRAZO CHEGOU', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
      'sem_historico' => (texto: 'SEM HISTÓRICO', cor: Cores.azul, fundo: Cores.azulClaro),
      _ => (texto: 'SEM PRAZO', cor: Cores.textoSuave, fundo: Cores.linha),
    };

class TelaPlanoMetas extends StatelessWidget {
  const TelaPlanoMetas({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Plano das metas',
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () => Api.mapa('/plano-metas'),
        construir: (c, d) {
          final planos = (d['planos'] as List).cast<Map<String, dynamic>>();
          final sugestoes = (d['sugestoes'] as List).cast<Map<String, dynamic>>();
          final resumo = (d['resumo'] as Map).cast<String, dynamic>();
          final comp = d['comparacao'] as Map?;
          final aviso = d['aviso'] as String?;
          return listaPadrao([
            OutlinedButton.icon(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const TelaRecorrentes())),
              icon: const Icon(Icons.event_repeat_outlined),
              label: const Text('Contas do mês: quanto guardar por dia'),
            ),
            const SizedBox(height: 10),
            if (planos.isNotEmpty)
              Cartao(
                filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Para ficar em dia com tudo', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Estatistica('Guardar hoje', reais(resumo['hojeTotal'] as num?), cor: Cores.verde)),
                    Expanded(child: Estatistica('Por semana', reais(resumo['semanaTotal'] as num?))),
                    Expanded(child: Estatistica('Por mês', reais(resumo['mesTotal'] as num?))),
                  ]),
                  if ((resumo['emRisco'] as num? ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Text('${resumo['emRisco']} objetivo(s) pedem atenção agora.',
                        style: const TextStyle(color: Cores.vermelho, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            if (comp != null)
              Aviso(
                comp['cabe'] == true
                    ? 'Sua sobra média por mês (${reais(comp['sobraMedia'] as num)}) cobre o que as metas pedem (${reais(comp['necessarioMes'] as num)}).'
                    : 'Sua sobra média por mês (${reais(comp['sobraMedia'] as num)}) é menor que o que as metas pedem (${reais(comp['necessarioMes'] as num)}). Vale rever prazos ou valores.',
                cor: comp['cabe'] == true ? Cores.ok : Cores.vermelho,
                fundo: comp['cabe'] == true ? Cores.verdeClaro : Cores.vermelhoClaro,
                icone: comp['cabe'] == true ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              ),
            if (aviso != null && aviso.isNotEmpty) Aviso(aviso, icone: Icons.info_outline),
            if (planos.isEmpty && sugestoes.isEmpty)
              const Vazio('Crie objetivos com prazo (em "Meu dinheiro guardado") e eu mostro quanto guardar por dia e se você chega lá.'),
            for (final p in planos) _CartaoPlano(p),
            if (sugestoes.isNotEmpty) ...[
              const Titulo('Reservas sugeridas (gás, água...)'),
              for (final s in sugestoes) _CartaoSugestao(s),
            ],
            const SizedBox(height: 6),
            const Aviso(
              'São estimativas com base nos seus aportes e compras. Quanto mais você registra, mais certa fica. O dinheiro NÃO fica separado no banco: é uma organização dentro do app.',
              icone: Icons.info_outline,
              cor: Cores.azul,
              fundo: Cores.azulClaro,
            ),
          ]);
        },
      ),
    );
  }
}

class _CartaoPlano extends StatelessWidget {
  final Map<String, dynamic> p;
  const _CartaoPlano(this.p);

  @override
  Widget build(BuildContext context) {
    final st = _status(p['status'] as String?);
    final chance = p['chance'] as num?;
    final podeGuardar = p['status'] != 'concluida' && (p['falta'] as num? ?? 0) > 0;
    final sugerido = (p['sugeridoHoje'] as num?)?.toDouble() ?? 0;
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${p['reposicao'] == true ? 'Reserva: ' : ''}${p['nome']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Etiqueta(st.texto, cor: st.cor, fundo: st.fundo),
        ]),
        const SizedBox(height: 6),
        Text('${reais(p['acumulado'] as num?)} de ${reais(p['alvo'] as num?)}'
            '${p['prazo'] != null ? ' · prazo ${_data(p['prazo'] as String?)}' : ''}',
            style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
        const SizedBox(height: 8),
        Progresso(((p['percentual'] as num?) ?? 0) / 100, cor: st.cor),
        const SizedBox(height: 10),
        Text('${p['texto']}', style: const TextStyle(fontSize: 13.5, height: 1.4)),
        if (chance != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('Chance no prazo', style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
            const SizedBox(width: 10),
            Expanded(child: Progresso(chance.toDouble(), cor: st.cor)),
            const SizedBox(width: 10),
            Text('${(chance * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ],
        if (podeGuardar) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (sugerido > 0)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => tentar(context, () => Api.post('/metas/${p['id']}/aportes', {'valor': sugerido}),
                      ok: 'Guardado ${reais(sugerido)} em "${p['nome']}".'),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: Text('Guardar ${reais(sugerido)} agora'),
                ),
              ),
            if (sugerido > 0) const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _outroValor(context), child: const Text('Outro valor')),
          ]),
        ],
      ]),
    );
  }

  Future<void> _outroValor(BuildContext context) async {
    final r = await pedir(context, 'Guardar em "${p['nome']}"', [
      const Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
    ]);
    if (r == null || !context.mounted) return;
    final valor = (r['valor'] as num).toDouble();
    if (valor <= 0) return;
    await tentar(context, () => Api.post('/metas/${p['id']}/aportes', {'valor': valor}), ok: 'Guardado ${reais(valor)}.');
  }
}

class _CartaoSugestao extends StatelessWidget {
  final Map<String, dynamic> s;
  const _CartaoSugestao(this.s);

  @override
  Widget build(BuildContext context) {
    final possivel = s['possivel'] == true;
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s['nome']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${s['texto']}', style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5, height: 1.4)),
        if (possivel) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => tentar(context, () => Api.post('/plano-metas/reposicao', {'itemId': s['itemId']}),
                  ok: 'Reserva criada para ${s['nome']}.'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Criar reserva'),
            ),
          ),
        ],
      ]),
    );
  }
}
