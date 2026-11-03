// =====================================================================
// contas.dart — onde está o seu dinheiro: conta bancária, carteira, cartão.
// Ao lançar uma despesa você pode escolher de qual conta ela saiu.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> tiposConta = {
  'conta': 'Conta bancária',
  'carteira': 'Carteira (dinheiro)',
  'cartao': 'Cartão',
  'outro': 'Outro',
};

Future<bool> editarConta(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Nova conta' : 'Editar conta',
      rota: 'contas',
      registro: registro,
      campos: const [
        Campo('nome', 'Nome (ex.: Nubank, Carteira)', obrigatorio: true),
        Campo('tipo', 'Tipo', tipo: TipoCampo.opcoes, opcoes: tiposConta),
        Campo('saldoInicial', 'Saldo inicial (R\$)', tipo: TipoCampo.numero, inicial: 0),
      ],
    );

class TelaContas extends StatelessWidget {
  const TelaContas({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Contas e cartões',
      fab: botaoMais(() => editarConta(context), dica: 'Nova conta'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('contas'),
        construir: (c, lista) => listaPadrao([
          const Text(
            'Cadastre de onde vem e para onde vai o seu dinheiro. O saldo inicial é o que você tem hoje em cada conta.',
            style: TextStyle(color: Cores.textoSuave),
          ),
          const SizedBox(height: 14),
          if (lista.isEmpty) const Vazio('Nenhuma conta ainda. Toque no + para cadastrar.'),
          for (final k in lista)
            Cartao(
              aoToque: () => editarConta(context, registro: k),
              filho: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Cores.verde),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k['nome'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(tiposConta[k['tipo']] ?? '', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  ]),
                ),
                Text(reais(k['saldoAtual'] ?? k['saldoInicial']), style: const TextStyle(fontWeight: FontWeight.w700)),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'editar'
                      ? editarConta(context, registro: k)
                      : excluir(context, 'contas', k['_id'], nome: '"${k['nome']}"'),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                  ],
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
