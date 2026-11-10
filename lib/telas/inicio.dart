// =====================================================================
// inicio.dart — a tela inicial (painel). Em segundos você entende:
//   Quanto tenho? Quanto vou receber? Quanto preciso pagar? Quanto falta?
//   O que está perto de vencer? O que está atrasado? Existe algum risco?
//
// Os números vêm prontos da API (/api/dashboard). Aqui só desenhamos.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'busca.dart';
import 'registro_rapido.dart';

class TelaInicio extends StatelessWidget {
  const TelaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Início',
      acoes: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Buscar',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca())),
        ),
      ],
      fab: botaoMais(() => registroRapido(context), dica: 'Registrar'),
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () async {
          final d = await Api.mapa('/dashboard');
          await Api.eu(); // atualiza dias de teste restantes
          return d;
        },
        construir: (c, d) => _Painel(d: d),
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  final Map<String, dynamic> d;
  const _Painel({required this.d});

  Widget _mini(String rotulo, String valor) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rotulo, style: const TextStyle(color: Color(0xFFB9CFC5), fontSize: 12)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      );

  /// Linha da seção "Previsto e planejado".
  Widget _linhaPlano(String nome, num valor, String etiqueta, Color cor, Color fundo) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Row(children: [Flexible(child: Text(nome)), Etiqueta(etiqueta, cor: cor, fundo: fundo)])),
          Text(reais(valor), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  /// Texto do aviso de contas vencidas (exemplo do enunciado:
  /// "Você precisa de R$ 850... Próximo compromisso: Internet..."). 
  String _textoPendencia(Map<String, dynamic> p) {
    final linhas = <String>[
      'PENDENTE: ${p['quantidade']} conta(s) vencida(s) somando ${reais(p['atrasado'])}.',
    ];
    if (p['proximoTitulo'] != null) {
      final dias = p['proximoDias'];
      final quando = dias == 0 ? 'hoje' : dias == 1 ? 'amanhã' : 'em $dias dias';
      linhas.add('Próximo compromisso: ${p['proximoTitulo']} — ${reais(p['proximoValor'])} $quando.');
    }
    linhas.add('Total necessário considerando os próximos compromissos: ${reais(p['total'])}.');
    return linhas.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final nome = (Api.usuario?['nome'] ?? '').toString().split(' ').first;
    final diasTeste = Api.usuario?['diasRestantes'];
    final status = d['status'] as String;
    final rotuloStatus = status == 'risco' ? 'Risco' : status == 'atencao' ? 'Atenção' : 'Controlado';
    final corStatus = status == 'controlado' ? const Color(0xFF7FD9A3) : const Color(0xFFEFC373);

    final falta = (d['falta'] as num).toDouble();
    final periodo = d['periodo'] as Map<String, dynamic>;
    final pendencia = d['pendencia'] as Map<String, dynamic>?;
    final previsto = d['previsto'] as Map<String, dynamic>;
    final planejado = d['planejado'] as Map<String, dynamic>;
    final alertas = (d['alertas'] as List).cast<Map<String, dynamic>>();
    final metas = (d['metas'] as List).cast<Map<String, dynamic>>();

    final temPlano = (previsto['manutencoes'] as num) > 0 ||
        (previsto['compras'] as num) > 0 ||
        (planejado['metas'] as num) > 0 ||
        (planejado['eventos'] as num) > 0;

    return listaPadrao([
      Text('Olá, $nome', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
      if (diasTeste != null && diasTeste <= 7)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Seu teste grátis termina em $diasTeste dia(s).', style: const TextStyle(color: Cores.ambar, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 14),

      // ----- Cartão principal: o que é REAL, o que vai entrar e o que vai sair -----
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Cores.verde, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Saldo disponível', style: TextStyle(color: Color(0xFFB9CFC5))),
          const SizedBox(height: 4),
          Text(reais(d['saldo']), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 9, color: corStatus),
              const SizedBox(width: 6),
              // Flexible: se o espaço for pequeno, o texto encurta em vez de estourar a tela.
              Flexible(
                child: Text('Situação: $rotuloStatus',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ]),
          ),
          const Divider(color: Color(0x40FFFFFF), height: 28),
          Row(children: [_mini('A receber', reais(d['aReceber'])), _mini('A pagar', reais(d['aPagar']))]),
          const SizedBox(height: 14),
          Row(children: [
            _mini('Depois dos compromissos', reais(d['projetado'])),
            _mini('Reserva mínima', reais(d['reservaMinima'])),
          ]),
        ]),
      ),

      // ----- Quanto falta (considera as datas dos próximos 30 dias) -----
      if (falta > 0)
        Aviso(
          'Você precisa de mais ${reais(falta)} para cobrir seus compromissos dos próximos ${periodo['dias']} dias.',
          cor: Cores.vermelho,
          fundo: Cores.vermelhoClaro,
          icone: Icons.warning_amber_rounded,
        ),

      // ----- Contas vencidas (PENDENTE) + o que vem logo depois -----
      if (pendencia != null) Aviso(_textoPendencia(pendencia), cor: Cores.vermelho, fundo: Cores.vermelhoClaro, icone: Icons.error_outline),

      // ----- Alertas por prioridade -----
      const Titulo('O que merece atenção'),
      if (alertas.isEmpty) const Vazio('Nada urgente. Sua projeção indica tranquilidade por enquanto.'),
      for (final a in alertas) ItemAlerta(a),

      // ----- Previsto e planejado: NÃO são despesas reais -----
      const Titulo('Previsto e planejado'),
      const Text('Estes valores ainda não saíram do seu bolso e não entram no saldo.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
      const SizedBox(height: 8),
      Cartao(
        filho: temPlano
            ? Column(children: [
                if ((previsto['manutencoes'] as num) > 0) _linhaPlano('Manutenções previstas', previsto['manutencoes'], 'PREVISTO', Cores.azul, Cores.azulClaro),
                if ((previsto['compras'] as num) > 0) _linhaPlano('Próximas compras (estoque)', previsto['compras'], 'PREVISTO', Cores.azul, Cores.azulClaro),
                if ((planejado['metas'] as num) > 0) _linhaPlano('Metas e compras futuras', planejado['metas'], 'PLANEJADO', Cores.ambar, Cores.ambarClaro),
                if ((planejado['eventos'] as num) > 0) _linhaPlano('Eventos planejados', planejado['eventos'], 'PLANEJADO', Cores.ambar, Cores.ambarClaro),
              ])
            : const Text('Nada previsto no momento.', style: TextStyle(color: Cores.textoSuave)),
      ),

      // ----- Metas -----
      if (metas.isNotEmpty) ...[
        const Titulo('Metas'),
        for (final m in metas)
          Cartao(
            filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['nome'], style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${m['percentual']}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Cores.verde)),
              ]),
              const SizedBox(height: 8),
              Progresso((m['percentual'] as num) / 100),
              const SizedBox(height: 6),
              Text('${reais(m['acumulado'])} de ${reais(m['alvo'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
            ]),
          ),
      ],
    ]);
  }
}