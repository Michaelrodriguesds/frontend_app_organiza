// =====================================================================
// principal.dart — a "casca" do app depois do login: barra de navegação
// embaixo com 5 abas (Início, Finanças, Veículos, Agenda, Mais).
// A aba "Mais" abre o resto das áreas, para a barra não ficar lotada.
// =====================================================================
import 'package:flutter/material.dart';
import '../componentes.dart';
import '../tema.dart';
import 'agenda.dart';
import 'assistente.dart';
import 'atividade.dart';
import 'busca.dart';
import 'calculadora.dart';
import 'carteira.dart';
import 'corridas.dart';
import 'plano_metas.dart';
import 'recorrentes.dart';
import 'casa.dart';
import 'config.dart';
import 'contas.dart';
import 'dividas.dart';
import 'eventos.dart';
import 'extrato.dart';
import 'financas.dart';
import 'inicio.dart';
import 'lixeira.dart';
import 'metas.dart';
import 'notas.dart';
import 'pix.dart';
import 'relatorios.dart';
import 'veiculos.dart';

class Principal extends StatefulWidget {
  const Principal({super.key});
  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  int _aba = 0;

  // Cada aba é uma tela. Ao trocar de aba ela é recriada e busca dados novos.
  static const _telas = <Widget>[
    TelaCarteira(key: ValueKey('carteira')),
    TelaFinancas(key: ValueKey('financas')),
    TelaVeiculos(key: ValueKey('veiculos')),
    TelaAgenda(key: ValueKey('agenda')),
    TelaMais(key: ValueKey('mais')),
  ];

  static const _destinos = <(IconData, IconData, String)>[
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Carteira'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Finanças'),
    (Icons.directions_car_outlined, Icons.directions_car, 'Veículos'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Agenda'),
    (Icons.grid_view_outlined, Icons.grid_view, 'Mais'),
  ];

  @override
  Widget build(BuildContext context) {
    // Computador (tela larga): menu na lateral. Celular: barra embaixo.
    final largo = MediaQuery.of(context).size.width >= 900;
    if (largo) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: Cores.fundo,
            indicatorColor: Cores.verdeClaro,
            selectedIndex: _aba,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _aba = i),
            destinations: [
              for (final (icone, selecionado, rotulo) in _destinos)
                NavigationRailDestination(icon: Icon(icone), selectedIcon: Icon(selecionado), label: Text(rotulo)),
            ],
          ),
          const VerticalDivider(width: 1, color: Cores.linha),
          Expanded(child: _telas[_aba]),
        ]),
      );
    }
    return Scaffold(
      body: _telas[_aba],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Cores.fundo,
        indicatorColor: Cores.verdeClaro,
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: [
          for (final (icone, selecionado, rotulo) in _destinos)
            NavigationDestination(icon: Icon(icone), selectedIcon: Icon(selecionado), label: rotulo),
        ],
      ),
    );
  }
}

/// Menu "Mais": todas as outras áreas do app.
class TelaMais extends StatelessWidget {
  const TelaMais({super.key});

  @override
  Widget build(BuildContext context) {
    // título, subtítulo, ícone e a tela que abre
    final itens = <(String, String, IconData, Widget)>[
      ('Corridas (app)', 'Melhores dias, meses e feriados para rodar', Icons.local_taxi_outlined, const TelaCorridas()),
      ('Assistente', 'Previsões e sugestões com base nos seus registros', Icons.auto_awesome_outlined, const TelaAssistente()),
      ('Pix', 'Receber (QR Code) e preparar envio', Icons.pix, const TelaPix()),
      ('Extrato', 'Entradas e saídas por mês · importar do banco', Icons.receipt_long_outlined, const TelaExtrato()),
      ('Contas do mês', 'Aluguel, luz, internet: lança sozinho e diz quanto guardar por dia', Icons.event_repeat_outlined, const TelaRecorrentes()),
      ('Plano das metas', 'Quanto guardar hoje, reservas de gás/água e chance no prazo', Icons.track_changes_outlined, const TelaPlanoMetas()),
      ('Meu dinheiro guardado', 'Objetivos e reservas (organização virtual)', Icons.savings_outlined, const TelaMetas()),
      ('Situação financeira', 'A pagar, previsões e alertas', Icons.insights_outlined, const TelaInicio()),
      ('Casa e estoque', 'Gás, água e despesas da casa', Icons.home_work_outlined, const TelaCasa()),
      ('Eventos', 'Orçamento previsto x realizado', Icons.celebration_outlined, const TelaEventos()),
      ('Notas', 'Bloco de notas e diário', Icons.sticky_note_2_outlined, const TelaNotas()),
      ('Dívidas e empréstimos', 'O que você deve e o que devem a você', Icons.handshake_outlined, const TelaDividas()),
      ('Contas e cartões', 'Onde está o seu dinheiro', Icons.account_balance_outlined, const TelaContas()),
      ('Relatórios', 'Gastos por mês, categoria e veículo', Icons.bar_chart, const TelaRelatorios()),
      ('Buscar', 'Procurar em todo o app', Icons.search, const TelaBusca()),
      ('Calculadora', 'Básica, %, regra de três, parcelas', Icons.calculate_outlined, const TelaCalculadora()),
      ('Lixeira', 'Restaurar o que foi excluído', Icons.delete_outline, const TelaLixeira()),
      ('Registro de atividade', 'Logins, importações e Pix da sua conta', Icons.verified_user_outlined, const TelaAtividade()),
      ('Configurações', 'Conta, avisos, senha e dados', Icons.settings_outlined, const TelaConfig()),
    ];

    return Pagina(
      titulo: 'Mais',
      corpo: listaPadrao([
        for (final (titulo, sub, icone, tela) in itens)
          Cartao(
            aoToque: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela)),
            filho: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Cores.verdeClaro, borderRadius: BorderRadius.circular(12)),
                child: Icon(icone, color: Cores.verde),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(sub, style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Cores.textoSuave),
            ]),
          ),
      ]),
    );
  }
}
