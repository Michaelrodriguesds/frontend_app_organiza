// =====================================================================
// principal.dart — a "casca" do app depois do login: barra de navegação
// embaixo com 5 abas (Início, Finanças, Veículos, Agenda, Mais).
// A aba "Mais" abre o resto das áreas, para a barra não ficar lotada.
// =====================================================================
import 'package:flutter/material.dart';
import '../componentes.dart';
import '../tema.dart';
import 'agenda.dart';
import 'busca.dart';
import 'calculadora.dart';
import 'casa.dart';
import 'config.dart';
import 'contas.dart';
import 'dividas.dart';
import 'eventos.dart';
import 'financas.dart';
import 'inicio.dart';
import 'lixeira.dart';
import 'metas.dart';
import 'notas.dart';
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
    TelaInicio(key: ValueKey('inicio')),
    TelaFinancas(key: ValueKey('financas')),
    TelaVeiculos(key: ValueKey('veiculos')),
    TelaAgenda(key: ValueKey('agenda')),
    TelaMais(key: ValueKey('mais')),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _telas[_aba],
        bottomNavigationBar: NavigationBar(
          backgroundColor: Cores.fundo,
          indicatorColor: Cores.verdeClaro,
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finanças'),
            NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Veículos'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Mais'),
          ],
        ),
      );
}

/// Menu "Mais": todas as outras áreas do app.
class TelaMais extends StatelessWidget {
  const TelaMais({super.key});

  @override
  Widget build(BuildContext context) {
    // título, subtítulo, ícone e a tela que abre
    final itens = <(String, String, IconData, Widget)>[
      ('Metas', 'Viagem, compras futuras, reserva', Icons.flag_outlined, const TelaMetas()),
      ('Casa e estoque', 'Gás, água e despesas da casa', Icons.home_work_outlined, const TelaCasa()),
      ('Eventos', 'Orçamento previsto x realizado', Icons.celebration_outlined, const TelaEventos()),
      ('Notas', 'Bloco de notas e diário', Icons.sticky_note_2_outlined, const TelaNotas()),
      ('Dívidas e empréstimos', 'O que você deve e o que devem a você', Icons.handshake_outlined, const TelaDividas()),
      ('Contas e cartões', 'Onde está o seu dinheiro', Icons.account_balance_outlined, const TelaContas()),
      ('Relatórios', 'Gastos por mês, categoria e veículo', Icons.bar_chart, const TelaRelatorios()),
      ('Buscar', 'Procurar em todo o app', Icons.search, const TelaBusca()),
      ('Calculadora', 'Básica, %, regra de três, parcelas', Icons.calculate_outlined, const TelaCalculadora()),
      ('Lixeira', 'Restaurar o que foi excluído', Icons.delete_outline, const TelaLixeira()),
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
