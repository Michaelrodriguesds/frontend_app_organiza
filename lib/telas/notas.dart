// =====================================================================
// notas.dart — bloco de notas / diário: título, texto, categoria,
// fixar no topo e marcar como favorita.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../formulario.dart';
import '../tema.dart';

const Map<String, String> categoriasNota = {
  'pessoal': 'Pessoal',
  'financeiro': 'Financeiro',
  'casa': 'Casa',
  'veiculo': 'Veículo',
  'viagem': 'Viagem',
  'trabalho': 'Trabalho',
  'outros': 'Outros',
};

Future<bool> editarNota(BuildContext context, {Map<String, dynamic>? registro}) => salvarForm(
      context,
      titulo: registro == null ? 'Nova nota' : 'Editar nota',
      rota: 'notas',
      registro: registro,
      campos: const [
        Campo('titulo', 'Título', obrigatorio: true),
        Campo('texto', 'Escreva aqui', linhas: 8),
        Campo('categoria', 'Categoria', tipo: TipoCampo.opcoes, opcoes: categoriasNota),
      ],
    );

class TelaNotas extends StatefulWidget {
  const TelaNotas({super.key});
  @override
  State<TelaNotas> createState() => _TelaNotasState();
}

class _TelaNotasState extends State<TelaNotas> {
  String _filtro = 'todas'; // todas | favoritas

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Notas',
      fab: botaoMais(() => editarNota(context), dica: 'Nova nota'),
      corpo: Carregador<List<Map<String, dynamic>>>(
        carregar: () => Api.lista('notas'),
        construir: (c, todas) {
          final notas = _filtro == 'favoritas' ? todas.where((n) => n['favorita'] == true).toList() : todas;
          return listaPadrao([
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'todas', label: Text('Todas')),
                ButtonSegment(value: 'favoritas', label: Text('Favoritas')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
            const SizedBox(height: 14),
            if (notas.isEmpty) const Vazio('Nenhuma nota. Toque no + para escrever.'),
            for (final n in notas) _cartao(c, n),
          ]);
        },
      ),
    );
  }

  Widget _cartao(BuildContext context, Map<String, dynamic> n) {
    final fixada = n['fixada'] == true;
    final favorita = n['favorita'] == true;
    return Cartao(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      aoToque: () => editarNota(context, registro: n),
      filho: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (fixada) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 16, color: Cores.verde)),
                Flexible(child: Text(n['titulo'], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
                Etiqueta(categoriasNota[n['categoria']] ?? 'Outros', cor: Cores.azul, fundo: Cores.azulClaro),
              ]),
              if ((n['texto'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(n['texto'], maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoSuave)),
                ),
            ]),
          ),
        ),
        Column(children: [
          IconButton(
            tooltip: favorita ? 'Tirar dos favoritos' : 'Favoritar',
            icon: Icon(favorita ? Icons.star : Icons.star_border, color: favorita ? Cores.ambar : Cores.textoSuave),
            onPressed: () => tentar(context, () => Api.put('/notas/${n['_id']}', {'favorita': !favorita})),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'fixar') tentar(context, () => Api.put('/notas/${n['_id']}', {'fixada': !fixada}));
              if (v == 'excluir') excluir(context, 'notas', n['_id'], nome: '"${n['titulo']}"');
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'fixar', child: Text(fixada ? 'Desafixar' : 'Fixar no topo')),
              const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
            ],
          ),
        ]),
      ]),
    );
  }
}
