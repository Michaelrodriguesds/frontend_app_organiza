// =====================================================================
// lixeira.dart — nada é apagado na hora: vai para cá primeiro.
// Dá para restaurar ou apagar de vez. Depois de 30 dias a API apaga sozinha.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';

const Map<String, String> _tipos = {
  'contas': 'Conta',
  'veiculos': 'Veículo',
  'manutencoes': 'Serviço',
  'movimentacoes': 'Lançamento',
  'dividas': 'Dívida',
  'metas': 'Meta',
  'estoque': 'Estoque',
  'eventos': 'Evento',
  'notas': 'Nota',
  'lembretes': 'Lembrete',
};

class TelaLixeira extends StatelessWidget {
  const TelaLixeira({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Lixeira',
      acoes: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Esvaziar lixeira',
          onPressed: () async {
            if (await confirmar(context, 'Esvaziar a lixeira?', 'Tudo será apagado de vez e não dá para desfazer.', botao: 'Esvaziar') && context.mounted) {
              await tentar(context, () => Api.apagar('/lixeira'), ok: 'Lixeira esvaziada.');
            }
          },
        ),
      ],
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () async => (await Api.get('/lixeira') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        construir: (c, itens) => listaPadrao([
          const Text('Itens excluídos ficam aqui por 30 dias.', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 14),
          if (itens.isEmpty) const Vazio('A lixeira está vazia.'),
          for (final i in itens)
            Cartao(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              filho: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i['titulo'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${_tipos[i['rota']] ?? i['rota']} · excluído em ${dataBR(i['excluidoEm'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Restaurar',
                  icon: const Icon(Icons.restore, color: Cores.verde),
                  onPressed: () => tentar(c, () => Api.post('/lixeira/${i['rota']}/${i['id']}/restaurar'), ok: 'Restaurado!'),
                ),
                IconButton(
                  tooltip: 'Apagar de vez',
                  icon: const Icon(Icons.delete_forever_outlined, color: Cores.vermelho),
                  onPressed: () async {
                    if (await confirmar(c, 'Apagar de vez?', 'Não dá para desfazer.', botao: 'Apagar') && c.mounted) {
                      await tentar(c, () => Api.apagar('/lixeira/${i['rota']}/${i['id']}'), ok: 'Apagado.');
                    }
                  },
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
