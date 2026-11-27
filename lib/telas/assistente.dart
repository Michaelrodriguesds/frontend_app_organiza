// =====================================================================
// assistente.dart — o ASSISTENTE do Organiza+: sugestões e previsões feitas
// com o que você mesmo registrou (gás/água acabando, conta vencendo, troca de
// óleo, meta atrasando, quantos dias o dinheiro aguenta...).
//
// São ESTIMATIVAS, nunca certeza. Cada sugestão mostra:
//   • a confiança (baixa/média/alta): cresce com o número de registros;
//   • a chance (%) quando dá para calcular;
//   • quantos registros faltam para a previsão ficar mais firme.
// Tudo é calculado no seu servidor, sem IA externa e sem custo.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'casa.dart';
import 'corridas.dart';
import 'plano_metas.dart';
import 'recorrentes.dart';
import 'financas.dart';
import 'metas.dart';
import 'relatorios.dart';
import 'veiculos.dart';

/// Abre a tela onde a sugestão pode ser resolvida (ex.: estoque → Casa).
void abrirDestino(BuildContext context, String? destino) {
  final Widget? tela = switch (destino) {
    'casa' => const TelaCasa(),
    'financas' => const TelaFinancas(),
    'veiculos' => const TelaVeiculos(),
    'metas' => const TelaMetas(),
    'relatorios' => const TelaRelatorios(),
    'corridas' => const TelaCorridas(),
    'plano' => const TelaPlanoMetas(),
    'recorrentes' => const TelaRecorrentes(),
    _ => null,
  };
  if (tela != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
}

IconData _icone(String? tipo) => switch (tipo) {
      'estoque' => Icons.inventory_2_outlined,
      'preco' => Icons.trending_up,
      'conta' => Icons.receipt_long_outlined,
      'veiculo' => Icons.directions_car_outlined,
      'meta' => Icons.flag_outlined,
      'gasto' => Icons.show_chart,
      'corridas' => Icons.local_taxi_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };

Color _corPrioridade(String? p) => p == 'alta' ? Cores.vermelho : p == 'media' ? Cores.ambar : Cores.azul;
Color _fundoPrioridade(String? p) => p == 'alta' ? Cores.vermelhoClaro : p == 'media' ? Cores.ambarClaro : Cores.azulClaro;

/// Um cartão de sugestão (usado na tela do assistente e no resumo da carteira).
class CartaoSugestao extends StatelessWidget {
  final Map<String, dynamic> s;
  final bool detalhado;
  const CartaoSugestao(this.s, {super.key, this.detalhado = true});

  @override
  Widget build(BuildContext context) {
    final p = s['prioridade'] as String?;
    final conf = s['confianca'] as String?;
    final chance = s['chance7'] as num?;
    final faltam = (s['faltam'] as num?)?.toInt() ?? 0;
    final tipo = s['tipo'] as String?;
    return Cartao(
      aoToque: () => abrirDestino(context, s['destino'] as String?),
      filho: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: _fundoPrioridade(p), borderRadius: BorderRadius.circular(12)),
          child: Icon(_icone(tipo), color: _corPrioridade(p), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['titulo']}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
            if (detalhado) ...[
              const SizedBox(height: 4),
              Text('${s['texto']}', style: const TextStyle(color: Cores.textoSuave, fontSize: 13, height: 1.35)),
              if (chance != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Progresso(chance.toDouble(), cor: _corPrioridade(p))),
                  const SizedBox(width: 10),
                  Text('${(chance * 100).round()}% em 7 dias', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ],
              const SizedBox(height: 6),
              Row(children: [
                if (conf != null) _etiquetaConfianca(conf),
                if (faltam > 0 && (tipo == 'estoque' || tipo == 'conta' || tipo == 'veiculo'))
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('faltam $faltam registro(s) p/ ficar mais firme',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Cores.textoSuave)),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _etiquetaConfianca(String c) {
    final txt = 'CONFIANÇA ${c == 'media' ? 'MÉDIA' : c.toUpperCase()}';
    return c == 'alta'
        ? Etiqueta(txt, cor: Cores.ok, fundo: Cores.verdeClaro)
        : c == 'media'
            ? Etiqueta(txt, cor: Cores.ambar, fundo: Cores.ambarClaro)
            : Etiqueta(txt, cor: Cores.textoSuave, fundo: Cores.linha);
  }
}

class TelaAssistente extends StatelessWidget {
  const TelaAssistente({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Assistente',
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () => Api.mapa('/insights'),
        construir: (c, d) {
          final lista = (d['insights'] as List).cast<Map<String, dynamic>>();
          final r = d['resumo'] as Map<String, dynamic>;
          final urgentes = lista.where((s) => s['prioridade'] != 'info').toList();
          final resto = lista.where((s) => s['prioridade'] == 'info').toList();
          final cobertura = r['coberturaDias'];
          return listaPadrao([
            const Aviso(
              'Estas são ESTIMATIVAS feitas com os seus próprios registros, sem internet e sem custo. '
              'Quanto mais você registra (compras, trocas, contas pagas), mais precisas elas ficam.',
              icone: Icons.auto_awesome_outlined,
              cor: Cores.azul,
              fundo: Cores.azulClaro,
            ),
            if (cobertura != null || r['sobraMedia'] != null || (r['fixasMes'] as num) > 0) ...[
              const SizedBox(height: 12),
              Cartao(
                filho: Row(children: [
                  if (cobertura != null) Expanded(child: Estatistica('Dinheiro livre dura', '$cobertura dias')),
                  if (r['sobraMedia'] != null) Expanded(child: Estatistica('Sobra média/mês', reais(r['sobraMedia']), cor: (r['sobraMedia'] as num) >= 0 ? Cores.ok : Cores.vermelho)),
                  if ((r['fixasMes'] as num) > 0) Expanded(child: Estatistica('Contas fixas/mês', reais(r['fixasMes']))),
                ]),
              ),
            ],
            if (lista.isEmpty)
              const Vazio(
                'Ainda não tenho dados suficientes para sugerir algo. Vá registrando e eu começo a avisar:\n'
                '• Casa: compre gás/água pelo estoque e toque em "Acabou 1" quando acabar (a partir de 2 registros eu calculo).\n'
                '• Contas: lance a mesma conta por 3 meses seguidos (internet, luz, aluguel…).\n'
                '• Veículos: registre serviços com data e km (a partir de 2 iguais).\n'
                '• Metas: guarde dinheiro de vez em quando para eu ver seu ritmo.',
              ),
            if (urgentes.isNotEmpty) const Titulo('Precisa de atenção'),
            for (final s in urgentes) CartaoSugestao(s),
            if (resto.isNotEmpty) const Titulo('Para ficar de olho'),
            for (final s in resto) CartaoSugestao(s),
            const SizedBox(height: 8),
            const Text(
              'Não é recomendação de investimento nem garantia: é só a leitura dos seus hábitos. Você decide.',
              style: TextStyle(color: Cores.textoSuave, fontSize: 12),
            ),
          ]);
        },
      ),
    );
  }
}

/// Resumo curto para a tela da Carteira: as 3 sugestões mais importantes.
/// Se der erro ou não houver nada, simplesmente não aparece (não atrapalha a carteira).
class ResumoAssistente extends StatefulWidget {
  const ResumoAssistente({super.key});
  @override
  State<ResumoAssistente> createState() => _ResumoAssistenteState();
}

class _ResumoAssistenteState extends State<ResumoAssistente> {
  List<Map<String, dynamic>> _lista = [];
  bool _tem = false;

  @override
  void initState() {
    super.initState();
    recargaGlobal.addListener(_buscar);
    _buscar();
  }

  @override
  void dispose() {
    recargaGlobal.removeListener(_buscar);
    super.dispose();
  }

  Future<void> _buscar() async {
    try {
      final d = await Api.mapa('/insights');
      if (!mounted) return;
      setState(() {
        _lista = (d['insights'] as List).cast<Map<String, dynamic>>();
        _tem = true;
      });
    } catch (_) {
      // o assistente é um extra: se falhar, a carteira continua normal
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_tem) return const SizedBox.shrink();
    final top = _lista.where((s) => s['prioridade'] != 'info').take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Titulo('Assistente')),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaAssistente())),
          child: Text(_lista.length > top.length ? 'Ver tudo (${_lista.length})' : 'Abrir'),
        ),
      ]),
      if (top.isEmpty)
        Cartao(
          aoToque: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaAssistente())),
          filho: Text(_lista.isEmpty ? 'Sem sugestões ainda. Quanto mais você registra, mais eu aprendo.' : 'Nada urgente. Toque para ver as previsões.',
              style: const TextStyle(color: Cores.textoSuave)),
        ),
      for (final s in top) CartaoSugestao(s, detalhado: false),
    ]);
  }
}
