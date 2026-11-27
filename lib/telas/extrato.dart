// =====================================================================
// extrato.dart — o EXTRATO da carteira: tudo que realmente entrou e saiu,
// por mês, com filtros. Também tem a importação do extrato do seu banco.
//
// Importante: o extrato mostra o que está REGISTRADO no Organiza+ (lançado
// por você ou importado do banco). Não é consultado direto no banco.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'auth.dart';

bool _entrada(Map m) => m['tipo'] == 'receita' || m['tipo'] == 'a_receber';

/// Uma linha de movimentação (usada no extrato e na tela da carteira).
class LinhaExtrato extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool oculto;
  const LinhaExtrato(this.m, {super.key, this.oculto = false});

  @override
  Widget build(BuildContext context) {
    final entrada = _entrada(m);
    final pix = m['meio'] == 'pix';
    return Cartao(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      aoToque: () => _detalhe(context),
      filho: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: entrada ? Cores.verdeClaro : Cores.vermelhoClaro, shape: BoxShape.circle),
          child: Icon(pix ? Icons.pix : (entrada ? Icons.south_west : Icons.north_east), size: 19, color: entrada ? Cores.ok : Cores.vermelho),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${m['descricao']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (m['importado'] == true) const Etiqueta('IMPORTADO', cor: Cores.azul, fundo: Cores.azulClaro),
            ]),
            Text('${dataBR(m['data'])} · ${rotuloCategoria(m['categoria'])}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(oculto ? '••••' : '${entrada ? '+' : '-'} ${reais(m['valor'])}',
            style: TextStyle(fontWeight: FontWeight.w700, color: entrada ? Cores.ok : Cores.texto)),
      ]),
    );
  }

  void _detalhe(BuildContext context) {
    final entrada = _entrada(m);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Cores.fundo,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entrada ? 'Entrada' : 'Saída', style: const TextStyle(color: Cores.textoSuave)),
            Text(reais(m['valor']), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: entrada ? Cores.ok : Cores.texto)),
            const SizedBox(height: 10),
            Text('${m['descricao']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Data: ${dataBR(m['data'])}'),
            Text('Categoria: ${rotuloCategoria(m['categoria'])}'),
            if (m['meio'] == 'pix') const Text('Forma: Pix'),
            Text(m['importado'] == true ? 'Origem: importado do extrato do banco' : 'Origem: registrado no Organiza+'),
            const SizedBox(height: 10),
            const Text('Este registro não é um comprovante bancário. Para comprovante oficial, use o app do seu banco.',
                style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class TelaExtrato extends StatefulWidget {
  const TelaExtrato({super.key});
  @override
  State<TelaExtrato> createState() => _TelaExtratoState();
}

class _TelaExtratoState extends State<TelaExtrato> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _tipo = 'todos'; // todos | entrada | saida
  String _q = '';
  int _pagina = 1;
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  String _rota() {
    final f = DateFormat('yyyy-MM-dd');
    final ate = DateTime(_mes.year, _mes.month + 1, 0);
    final p = <String>['de=${f.format(_mes)}', 'ate=${f.format(ate)}', 'pagina=$_pagina', 'limite=30'];
    if (_tipo != 'todos') p.add('tipo=$_tipo');
    if (_q.isNotEmpty) p.add('q=${Uri.encodeQueryComponent(_q)}');
    return '/extrato?${p.join('&')}';
  }

  void _mudarMes(int delta) => setState(() {
        _mes = DateTime(_mes.year, _mes.month + delta, 1);
        _pagina = 1;
      });

  @override
  Widget build(BuildContext context) {
    final rotuloMes = toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'pt_BR').format(_mes)) ?? '';
    final ehAtual = _mes.year == DateTime.now().year && _mes.month == DateTime.now().month;
    return Pagina(
      titulo: 'Extrato',
      acoes: [
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: 'Importar extrato do banco',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportar())),
        ),
      ],
      corpo: Carregador<Map<String, dynamic>>(
        key: ValueKey('extrato|${_rota()}'),
        carregar: () => Api.mapa(_rota()),
        construir: (c, d) {
          final itens = (d['itens'] as List).cast<Map<String, dynamic>>();
          final paginas = (d['paginas'] as num).toInt();
          return listaPadrao([
            Row(children: [
              IconButton(onPressed: () => _mudarMes(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Mês anterior'),
              Expanded(child: Center(child: Text(rotuloMes, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
              IconButton(onPressed: ehAtual ? null : () => _mudarMes(1), icon: const Icon(Icons.chevron_right), tooltip: 'Próximo mês'),
            ]),
            Cartao(
              filho: Row(children: [
                Expanded(child: Estatistica('Entradas', reais(d['entradas']), cor: Cores.ok)),
                Expanded(child: Estatistica('Saídas', reais(d['saidas']), cor: Cores.vermelho)),
                Expanded(child: Estatistica('Resultado', reais(d['saldoPeriodo']))),
              ]),
            ),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Tudo')),
                ButtonSegment(value: 'entrada', label: Text('Entradas')),
                ButtonSegment(value: 'saida', label: Text('Saídas')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() {
                _tipo = s.first;
                _pagina = 1;
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _busca,
              textInputAction: TextInputAction.search,
              decoration: decoracao('Buscar no extrato', sufixo: IconButton(icon: const Icon(Icons.search), onPressed: () => _aplicarBusca())),
              onSubmitted: (_) => _aplicarBusca(),
            ),
            const SizedBox(height: 12),
            if (itens.isEmpty) const Vazio('Nenhuma movimentação neste período. Registre uma entrada/saída ou importe o extrato do seu banco.'),
            for (final m in itens) LinhaExtrato(m),
            if (paginas > 1)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: _pagina > 1 ? () => setState(() => _pagina--) : null, child: const Text('Anterior')),
                Text('$_pagina / $paginas'),
                TextButton(onPressed: _pagina < paginas ? () => setState(() => _pagina++) : null, child: const Text('Próxima')),
              ]),
          ]);
        },
      ),
    );
  }

  void _aplicarBusca() => setState(() {
        _q = _busca.text.trim();
        _pagina = 1;
      });
}

// =====================================================================
// IMPORTAR EXTRATO: cole o CSV ou OFX que você baixou no app/site do banco.
// Grátis, funciona com qualquer banco que deixe exportar e não guarda senha.
// =====================================================================
class TelaImportar extends StatefulWidget {
  const TelaImportar({super.key});
  @override
  State<TelaImportar> createState() => _TelaImportarState();
}

class _TelaImportarState extends State<TelaImportar> {
  final _texto = TextEditingController();
  bool _invertido = false, _ocupado = false;
  Map<String, dynamic>? _previa;
  String? _resultado;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _enviar(bool simular) async {
    setState(() => _ocupado = true);
    try {
      final d = await Api.post('/extrato/importar', {'texto': _texto.text, 'invertido': _invertido, 'simular': simular});
      return Map<String, dynamic>.from(d as Map);
    } on ApiErro catch (e) {
      if (mounted && !tratarErroSessao(context, e)) aviso(context, e.mensagem, erro: true);
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _ver() async {
    final d = await _enviar(true);
    if (d != null && mounted) setState(() { _previa = d; _resultado = null; });
  }

  Future<void> _importar() async {
    final d = await _enviar(false);
    if (d == null || !mounted) return;
    recargaGlobal.recarregar();
    setState(() {
      _previa = null;
      _resultado = '${d['gravadas']} movimentação(ões) importada(s). ${d['duplicadas']} já existiam e foram ignoradas.';
      _texto.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _previa;
    return Pagina(
      titulo: 'Importar extrato',
      corpo: listaPadrao([
        const Cartao(
          filho: Text(
            'Como fazer:\n'
            '1. No app ou site do seu banco, abra o Extrato e exporte em CSV ou OFX.\n'
            '2. Abra o arquivo no Bloco de Notas, copie tudo e cole abaixo.\n'
            '3. Toque em "Ver o que será importado" e depois em "Importar".\n\n'
            'Você pode importar o mesmo período de novo: o que já existe é ignorado. '
            'Importante: se importar o extrato, NÃO marque o mesmo Pix como "pago" à mão, senão ele aparece duas vezes.',
            style: TextStyle(height: 1.4),
          ),
        ),
        if (_resultado != null) Aviso(_resultado!, cor: Cores.ok, fundo: Cores.verdeClaro, icone: Icons.check_circle_outline),
        const SizedBox(height: 12),
        TextField(controller: _texto, minLines: 6, maxLines: 12, decoration: decoracao('Cole aqui o CSV ou OFX do extrato')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sinais invertidos'),
          subtitle: const Text('Ligue se as entradas aparecerem como saídas (comum em fatura de cartão).'),
          value: _invertido,
          activeThumbColor: Cores.verde,
          onChanged: (v) => setState(() { _invertido = v; _previa = null; }),
        ),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _ocupado ? null : _ver, child: const Text('Ver o que será importado'))),
        ]),
        if (p != null) ...[
          const Titulo('Pré-visualização'),
          Cartao(
            filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['lidas']} linha(s) lidas · ${p['novas']} nova(s) · ${p['duplicadas']} já existem · ${p['ignoradas']} ignorada(s)'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Estatistica('Entradas novas', reais(p['entradas']), cor: Cores.ok)),
                Expanded(child: Estatistica('Saídas novas', reais(p['saidas']), cor: Cores.vermelho)),
              ]),
              const SizedBox(height: 8),
              for (final a in (p['amostra'] as List).cast<Map>())
                Text('${dataBR(a['data'])}  ${a['tipo'] == 'receita' ? '+' : '-'} ${reais(a['valor'])}  ${a['descricao']}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.verde, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _ocupado || (p['novas'] as num) == 0 ? null : _importar,
            child: Text(_ocupado ? 'Importando…' : 'Importar ${p['novas']} movimentação(ões)'),
          ),
        ],
      ]),
    );
  }
}
