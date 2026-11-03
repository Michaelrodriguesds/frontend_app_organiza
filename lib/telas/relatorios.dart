// =====================================================================
// relatorios.dart — para onde foi o seu dinheiro no ano.
// Responde, por exemplo: "Quanto gastei com meu carro em 2026?"
// Os gráficos são barrinhas simples (sem biblioteca extra).
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';

const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

class TelaRelatorios extends StatefulWidget {
  const TelaRelatorios({super.key});
  @override
  State<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<TelaRelatorios> {
  int _ano = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Relatórios',
      corpo: Carregador<Map<String, dynamic>>(
        key: ValueKey(_ano), // trocou o ano -> carrega de novo
        carregar: () => Api.mapa('/relatorios?ano=$_ano'),
        construir: (c, r) {
          final porMes = (r['porMes'] as List).cast<Map<String, dynamic>>();
          final categoriasLista = (r['porCategoria'] as List).cast<Map<String, dynamic>>();
          final veiculos = (r['gastoVeiculos'] as List).cast<Map<String, dynamic>>();
          final eventos = (r['porEvento'] as List).cast<Map<String, dynamic>>();
          final comp = r['comparacao'] as Map<String, dynamic>;

          final maxMes = porMes.fold<double>(0, (m, x) {
            final a = (x['receitas'] as num).toDouble(), b = (x['despesas'] as num).toDouble();
            return [m, a, b].reduce((p, q) => p > q ? p : q);
          });
          final maxCat = categoriasLista.isEmpty ? 0.0 : (categoriasLista.first['total'] as num).toDouble();
          final maxVei = veiculos.fold<double>(0, (m, v) => (v['total'] as num) > m ? (v['total'] as num).toDouble() : m);

          final saldoAno = (r['totalReceitas'] as num) - (r['totalDespesas'] as num);
          final mesAtual = (comp['mesAtual'] as num).toDouble();
          final mesAnterior = (comp['mesAnterior'] as num).toDouble();

          return listaPadrao([
            // ----- escolher o ano -----
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _ano--)),
              Text('$_ano', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _ano++)),
            ]),
            // ----- resumo do ano -----
            Cartao(
              filho: Row(children: [
                Expanded(child: Estatistica('Receitas', reais(r['totalReceitas']), cor: Cores.ok)),
                Expanded(child: Estatistica('Despesas', reais(r['totalDespesas']), cor: Cores.vermelho)),
                Expanded(child: Estatistica('Resultado', reais(saldoAno), cor: saldoAno >= 0 ? Cores.ok : Cores.vermelho)),
              ]),
            ),
            if (_ano == DateTime.now().year && (mesAtual > 0 || mesAnterior > 0))
              Cartao(
                filho: Text(
                  mesAnterior == 0
                      ? 'Neste mês você gastou ${reais(mesAtual)}.'
                      : 'Neste mês você gastou ${reais(mesAtual)}, '
                          '${mesAtual > mesAnterior ? 'acima' : 'abaixo'} do mês passado (${reais(mesAnterior)}).',
                ),
              ),

            // ----- mês a mês -----
            const Titulo('Mês a mês'),
            const Row(children: [
              Icon(Icons.circle, size: 10, color: Cores.ok),
              SizedBox(width: 4),
              Text('Receitas', style: TextStyle(fontSize: 12)),
              SizedBox(width: 14),
              Icon(Icons.circle, size: 10, color: Cores.vermelho),
              SizedBox(width: 4),
              Text('Despesas', style: TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Cartao(
              filho: Column(children: [
                for (final m in porMes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text(_meses[(m['mes'] as int) - 1], style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5))),
                      Expanded(
                        child: Column(children: [
                          Progresso(maxMes > 0 ? (m['receitas'] as num) / maxMes : 0.0, cor: Cores.ok),
                          const SizedBox(height: 3),
                          Progresso(maxMes > 0 ? (m['despesas'] as num) / maxMes : 0.0, cor: Cores.vermelho),
                        ]),
                      ),
                      SizedBox(width: 92, child: Text(reais(m['despesas']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
                    ]),
                  ),
              ]),
            ),

            // ----- por categoria -----
            const Titulo('Despesas por categoria'),
            if (categoriasLista.isEmpty) const Vazio('Sem despesas neste ano.'),
            if (categoriasLista.isNotEmpty)
              Cartao(
                filho: Column(children: [
                  for (final cat in categoriasLista)
                    _barra(rotuloCategoria(cat['categoria']), (cat['total'] as num).toDouble(), maxCat, Cores.verde),
                ]),
              ),

            // ----- por veículo -----
            const Titulo('Gastos por veículo'),
            if (veiculos.isEmpty) const Vazio('Nenhum veículo cadastrado.'),
            if (veiculos.isNotEmpty)
              Cartao(
                filho: Column(children: [
                  for (final v in veiculos)
                    _barra('${v['veiculo']} (${v['servicos']} serviço(s))', (v['total'] as num).toDouble(), maxVei, Cores.azul),
                ]),
              ),

            // ----- eventos -----
            const Titulo('Eventos: previsto x realizado'),
            if (eventos.isEmpty) const Vazio('Nenhum evento neste ano.'),
            for (final e in eventos)
              Cartao(
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e['nome'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Previsto ${reais(e['previsto'])} · Realizado ${reais(e['real'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                  Text(
                    '${(e['diferenca'] as num) > 0 ? '+' : ''}${reais(e['diferenca'])}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: (e['diferenca'] as num) > 0 ? Cores.vermelho : Cores.ok),
                  ),
                ]),
              ),
          ]);
        },
      ),
    );
  }

  /// Uma linha: nome, barra e valor.
  Widget _barra(String nome, double valor, double maximo, Color cor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(reais(valor), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Progresso(maximo > 0 ? valor / maximo : 0.0, cor: cor),
        ]),
      );
}
