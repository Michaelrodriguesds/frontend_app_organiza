// =====================================================================
// recorrentes.dart — "Contas do mês": contas que se repetem (aluguel, luz,
// internet...). Cadastre UMA vez e o app:
//   • lança sozinho a conta "a pagar" de cada mês (você não lança mais);
//   • mostra o vencimento e QUANTO GUARDAR POR DIA até lá para não se enrolar;
//   • avisa no Assistente quando uma conta está chegando sem o valor separado.
//
// "Guardar" aqui é organização dentro do app: o dinheiro NÃO sai da sua conta
// do banco. Conta de valor variável (luz, água) usa a média das últimas contas
// pagas e aparece como "estimado".
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

String _data(String? iso) => iso == null || iso.length < 10 ? '' : '${iso.substring(8, 10)}/${iso.substring(5, 7)}';

({String texto, Color cor, Color fundo}) _status(String? s) => switch (s) {
      'garantida' => (texto: 'GARANTIDA', cor: Cores.ok, fundo: Cores.verdeClaro),
      'atrasada' => (texto: 'ATRASADA', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
      'vence_hoje' => (texto: 'VENCE HOJE', cor: Cores.vermelho, fundo: Cores.vermelhoClaro),
      _ => (texto: 'GUARDANDO', cor: Cores.azul, fundo: Cores.azulClaro),
    };

Future<bool> _editar(BuildContext context, {Map<String, dynamic>? p}) async {
  final r = await pedir(context, p == null ? 'Nova conta do mês' : 'Editar conta', [
    Campo('descricao', 'Nome (ex.: Aluguel, Luz, Internet)', obrigatorio: true, inicial: p?['nome']),
    Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true, inicial: p?['valorBase']),
    Campo('dia', 'Dia do vencimento (1 a 31)', tipo: TipoCampo.numero, obrigatorio: true, inicial: p?['dia']),
    Campo('tipoValor', 'O valor muda todo mês?', tipo: TipoCampo.opcoes,
        opcoes: const {'fixo': 'Não, é sempre igual', 'variavel': 'Sim (luz, água...): usar a média'},
        inicial: p?['variavel'] == true ? 'variavel' : 'fixo'),
  ]);
  if (r == null || !context.mounted) return false;
  final corpo = {
    'descricao': r['descricao'],
    'valor': r['valor'],
    'dia': (r['dia'] as num).toInt(),
    'variavel': r['tipoValor'] == 'variavel',
  };
  return tentar(
    context,
    () => p == null ? Api.post('/recorrentes', corpo) : Api.put('/recorrentes/${p['id']}', corpo),
    ok: p == null ? 'Conta cadastrada. O app lança todo mês.' : 'Conta atualizada.',
  );
}

class TelaRecorrentes extends StatelessWidget {
  const TelaRecorrentes({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Contas do mês',
      fab: botaoMais(() => _editar(context), dica: 'Nova conta'),
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () => Api.mapa('/recorrentes'),
        construir: (c, d) {
          final planos = (d['planos'] as List).cast<Map<String, dynamic>>();
          final resumo = (d['resumo'] as Map).cast<String, dynamic>();
          return listaPadrao([
            if (planos.isNotEmpty)
              Cartao(
                filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Para chegar nos vencimentos sem aperto', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Estatistica('Guardar por dia', reais(resumo['porDiaTotal'] as num?), cor: Cores.verde)),
                    Expanded(child: Estatistica('Contas do mês', reais(resumo['mesTotal'] as num?))),
                    Expanded(child: Estatistica('Vencem em 7 dias', '${resumo['proximos7']}')),
                  ]),
                  if ((resumo['atrasadas'] as num? ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Text('${resumo['atrasadas']} conta(s) atrasada(s).', style: const TextStyle(color: Cores.vermelho, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            if (planos.isEmpty)
              const Vazio('Cadastre aqui o que se repete todo mês (aluguel, luz, internet...). O app lança a conta sozinho e diz quanto guardar por dia. Toque no +.'),
            for (final p in planos) _CartaoConta(p),
            const SizedBox(height: 6),
            const Aviso(
              'Guardar é só organização dentro do app: o dinheiro continua na sua conta do banco. Para contas de valor variável, o valor é uma estimativa pela média das últimas pagas.',
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

class _CartaoConta extends StatelessWidget {
  final Map<String, dynamic> p;
  const _CartaoConta(this.p);

  @override
  Widget build(BuildContext context) {
    final st = _status(p['status'] as String?);
    final valor = (p['valor'] as num).toDouble();
    final guardado = (p['guardado'] as num).toDouble();
    final falta = (p['falta'] as num).toDouble();
    final porDia = (p['porDia'] as num).toDouble();
    final dias = (p['dias'] as num).toInt();
    return Cartao(
      aoToque: () => _menu(context),
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${p['nome']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Etiqueta(st.texto, cor: st.cor, fundo: st.fundo),
        ]),
        const SizedBox(height: 6),
        Text('${p['estimado'] == true ? '~' : ''}${reais(valor)} · vence ${_data(p['vencimento'] as String?)}'
            '${dias >= 0 ? ' (em $dias dia${dias == 1 ? '' : 's'})' : ''}',
            style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
        const SizedBox(height: 8),
        Progresso(valor > 0 ? guardado / valor : 0, cor: st.cor),
        const SizedBox(height: 10),
        Text('${p['texto']}', style: const TextStyle(fontSize: 13.5, height: 1.4)),
        if (falta > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (porDia > 0 && dias >= 0)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _guardar(context, porDia),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: Text('Guardar ${reais(porDia)} hoje'),
                ),
              ),
            if (porDia > 0 && dias >= 0) const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _outroValor(context), child: const Text('Outro valor')),
          ]),
        ],
      ]),
    );
  }

  Future<void> _guardar(BuildContext context, double v) =>
      tentar(context, () => Api.post('/recorrentes/${p['id']}/guardar', {'valor': v}), ok: 'Guardado ${reais(v)} para "${p['nome']}".');

  Future<void> _outroValor(BuildContext context) async {
    final r = await pedir(context, 'Guardar para "${p['nome']}"', [
      const Campo('valor', 'Valor (R\$)', tipo: TipoCampo.numero, obrigatorio: true),
    ]);
    if (r == null || !context.mounted) return;
    final v = (r['valor'] as num).toDouble();
    if (v <= 0) return;
    await tentar(context, () => Api.post('/recorrentes/${p['id']}/guardar', {'valor': v}), ok: 'Guardado ${reais(v)}.');
  }

  Future<void> _menu(BuildContext context) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar'), onTap: () => Navigator.pop(ctx, 'editar')),
          ListTile(leading: const Icon(Icons.stop_circle_outlined), title: const Text('Parar de repetir'), onTap: () => Navigator.pop(ctx, 'parar')),
        ]),
      ),
    );
    if (acao == null || !context.mounted) return;
    if (acao == 'editar') {
      await _editar(context, p: p);
    } else if (await confirmar(context, 'Parar de repetir?', '"${p['nome']}" não será mais lançada todo mês. Contas já pagas continuam no histórico.', botao: 'Parar')) {
      if (!context.mounted) return;
      await tentar(context, () => Api.apagar('/recorrentes/${p['id']}'), ok: 'Conta removida.');
    }
  }
}
