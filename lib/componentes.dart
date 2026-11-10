// =====================================================================
// componentes.dart — peças visuais e ferramentas reutilizadas em todas as telas.
// (Pense em peças de LEGO: Cartao, Etiqueta, Pagina, Carregador...)
// =====================================================================
import 'package:flutter/material.dart';
import 'api.dart';
import 'formulario.dart';
import 'tema.dart';
import 'telas/auth.dart';

// ---------------------------------------------------------------------
// RECARGA GLOBAL
// Sempre que algo é salvo ou excluído, chamamos recargaGlobal.recarregar().
// Todas as telas que estão abertas (Carregador) buscam os dados de novo.
// ---------------------------------------------------------------------
class Recarga extends ChangeNotifier {
  void recarregar() => notifyListeners();
}

final Recarga recargaGlobal = Recarga();

// ---------------------------------------------------------------------
// CARREGADOR: busca dados na API e mostra "carregando", "erro" ou o conteúdo.
//   Carregador<List<Map<String,dynamic>>>(
//     carregar: () => Api.lista('veiculos'),
//     construir: (context, dados) => ListView(...),
//   )
// Puxar a tela para baixo recarrega.
// ---------------------------------------------------------------------
class Carregador<T> extends StatefulWidget {
  final Future<T> Function() carregar;
  final Widget Function(BuildContext context, T dados) construir;
  // Use "titulo" quando o Carregador é a tela inteira: assim "carregando" e
  // "erro" também aparecem dentro de uma Página (com botão de voltar).
  final String? titulo;
  const Carregador({super.key, required this.carregar, required this.construir, this.titulo});

  @override
  State<Carregador<T>> createState() => _CarregadorState<T>();
}

class _CarregadorState<T> extends State<Carregador<T>> {
  T? _dados;
  bool _temDados = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    recargaGlobal.addListener(_buscar); // recarrega quando algo muda no app
    _buscar();
  }

  @override
  void dispose() {
    recargaGlobal.removeListener(_buscar);
    super.dispose();
  }

  Future<void> _buscar() async {
    try {
      final d = await widget.carregar();
      if (!mounted) return;
      setState(() {
        _dados = d;
        _temDados = true;
        _erro = null;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (tratarErroSessao(context, e)) return; // sessão caiu / teste acabou
      setState(() => _erro = e.mensagem);
    }
  }

  Widget _envolver(Widget w) => widget.titulo == null ? w : Pagina(titulo: widget.titulo!, corpo: w);

  @override
  Widget build(BuildContext context) {
    if (!_temDados && _erro == null) return _envolver(const Center(child: CircularProgressIndicator()));
    if (!_temDados) {
      return _envolver(Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(color: Cores.vermelho)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _erro = null);
                _buscar();
              },
              child: const Text('Tentar de novo'),
            ),
          ]),
        ),
      ));
    }
    return RefreshIndicator(onRefresh: _buscar, child: widget.construir(context, _dados as T));
  }
}

// ---------------------------------------------------------------------
// tentar(): executa uma ação na API, mostra a mensagem de sucesso/erro
// e manda as telas recarregarem. Devolve true se deu certo.
// ---------------------------------------------------------------------
Future<bool> tentar(BuildContext context, Future<dynamic> Function() acao, {String? ok}) async {
  try {
    await acao();
    recargaGlobal.recarregar();
    if (ok != null && context.mounted) aviso(context, ok);
    return true;
  } on ApiErro catch (e) {
    if (context.mounted && !tratarErroSessao(context, e)) {
      // Em erros de dados (400/404/500) mostra também qual chamada falhou: facilita achar o problema.
      final extra = (e.detalhe != null && e.status >= 400) ? '\n(${e.detalhe})' : '';
      aviso(context, '${e.mensagem}$extra', erro: true);
    }
    return false;
  }
}

/// Abre o formulário e salva (POST se for novo, PUT se for edição).
///  registro: se informado, é uma EDIÇÃO e os campos vêm preenchidos.
///  extras:   valores fixos enviados junto (ex.: {'veiculoId': '...'}).
Future<bool> salvarForm(
  BuildContext context, {
  required String titulo,
  required String rota,
  required List<Campo> campos,
  Map<String, dynamic>? registro,
  Map<String, dynamic> extras = const {},
  String? ok,
}) async {
  final lista = registro == null ? campos : [for (final c in campos) c.comInicial(registro[c.chave])];
  final r = await pedir(context, titulo, lista);
  if (r == null || !context.mounted) return false;
  final corpo = {...r, ...extras};
  return tentar(
    context,
    () => registro == null ? Api.post('/$rota', corpo) : Api.put('/$rota/${registro['_id']}', corpo),
    ok: ok ?? (registro == null ? 'Salvo!' : 'Alterado!'),
  );
}

/// Manda para a lixeira (pedindo confirmação).
Future<bool> excluir(BuildContext context, String rota, String id, {String nome = 'este item'}) async {
  if (!await confirmar(context, 'Excluir?', 'Enviar $nome para a lixeira? Você pode restaurar depois.', botao: 'Excluir')) return false;
  if (!context.mounted) return false;
  return tentar(context, () => Api.apagar('/$rota/$id'), ok: 'Movido para a lixeira.');
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String botao = 'Confirmar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(botao)),
      ],
    ),
  );
  return r == true;
}

/// Mostra uma lista de opções e devolve a chave escolhida (ou null).
Future<String?> escolher(BuildContext context, String titulo, Map<String, String> opcoes) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Cores.fundo,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        Padding(padding: const EdgeInsets.all(18), child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        for (final e in opcoes.entries) ListTile(title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// Busca uma lista e, se falhar, mostra o erro e devolve null.
Future<List<Map<String, dynamic>>?> listaOuAviso(BuildContext context, String rota) async {
  try {
    return await Api.lista(rota);
  } on ApiErro catch (e) {
    if (context.mounted && !tratarErroSessao(context, e)) aviso(context, e.mensagem, erro: true);
    return null;
  }
}

// ---------------------------------------------------------------------
// PÁGINA: moldura padrão de toda tela (barra de título + conteúdo centralizado).
// ---------------------------------------------------------------------
class Pagina extends StatelessWidget {
  final String titulo;
  final Widget corpo;
  final Widget? fab;
  final List<Widget>? acoes;
  const Pagina({super.key, required this.titulo, required this.corpo, this.fab, this.acoes});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          backgroundColor: Cores.fundo,
          foregroundColor: Cores.texto,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: acoes,
        ),
        floatingActionButton: fab,
        // maxWidth: no computador a tela não fica esticada demais
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: corpo)),
      );
}

/// Botão redondo "+" padrão.
Widget botaoMais(VoidCallback aoApertar, {String dica = 'Adicionar'}) => FloatingActionButton(
      backgroundColor: Cores.verde,
      foregroundColor: Colors.white,
      tooltip: dica,
      onPressed: aoApertar,
      child: const Icon(Icons.add),
    );

/// Lista rolável com espaço para o botão "+" não cobrir o último item.
Widget listaPadrao(List<Widget> filhos) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
      children: filhos,
    );

// ---------------------------------------------------------------------
// Peças visuais
// ---------------------------------------------------------------------
class Cartao extends StatelessWidget {
  final Widget filho;
  final EdgeInsets padding;
  final VoidCallback? aoToque;
  const Cartao({super.key, required this.filho, this.padding = const EdgeInsets.all(16), this.aoToque});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: aoToque,
            child: Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Cores.linha)),
              padding: padding,
              child: filho,
            ),
          ),
        ),
      );
}

/// Selinho de texto ("PENDENTE", "PREVISTO"...). Não depende só da cor: tem texto.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor, fundo;
  const Etiqueta(this.texto, {super.key, required this.cor, required this.fundo});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(6)),
        child: Text(texto, style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

class Titulo extends StatelessWidget {
  final String texto;
  const Titulo(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Cores.texto)),
      );
}

/// Texto de "nada por aqui".
class Vazio extends StatelessWidget {
  final String texto;
  const Vazio(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Cartao(filho: Text(texto, style: const TextStyle(color: Cores.textoSuave)));
}

/// Caixa colorida de aviso (ex.: "Você precisa de mais R$ 200...").
class Aviso extends StatelessWidget {
  final String texto;
  final Color cor, fundo;
  final IconData icone;
  const Aviso(this.texto, {super.key, this.cor = Cores.ambar, this.fundo = Cores.ambarClaro, this.icone = Icons.info_outline});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600, height: 1.35))),
        ]),
      );
}

/// Barra de progresso (0 a 1).
class Progresso extends StatelessWidget {
  final double valor;
  final Color cor;
  const Progresso(this.valor, {super.key, this.cor = Cores.verde});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: valor.clamp(0, 1).toDouble(), minHeight: 8, color: cor, backgroundColor: Cores.linha),
      );
}

/// Número grande com legenda (ex.: "Gasto total / R$ 1.200").
class Estatistica extends StatelessWidget {
  final String rotulo, valor;
  final Color? cor;
  const Estatistica(this.rotulo, this.valor, {super.key, this.cor});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo, style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cor ?? Cores.texto)),
      ]);
}

// ---------------------------------------------------------------------
// ALERTAS / ITENS DA AGENDA (usado no Início e na Agenda)
// ---------------------------------------------------------------------
IconData iconeTipo(String? tipo) {
  switch (tipo) {
    case 'conta':
      return Icons.receipt_long;
    case 'divida':
      return Icons.handshake_outlined;
    case 'receber':
      return Icons.savings_outlined;
    case 'manutencao':
      return Icons.build_outlined;
    case 'estoque':
      return Icons.inventory_2_outlined;
    case 'evento':
      return Icons.celebration_outlined;
    case 'lembrete':
      return Icons.notifications_none;
    case 'meta':
      return Icons.flag_outlined;
    case 'risco':
      return Icons.warning_amber_rounded;
    default:
      return Icons.circle_outlined;
  }
}

class ItemAlerta extends StatelessWidget {
  final Map<String, dynamic> a;
  final VoidCallback? aoToque;
  const ItemAlerta(this.a, {super.key, this.aoToque});

  @override
  Widget build(BuildContext context) {
    final nivel = a['nivel'];
    final cor = nivel == 'urgente' ? Cores.vermelho : nivel == 'atencao' ? Cores.ambar : nivel == 'info' ? Cores.azul : Cores.verde;
    final fundo = nivel == 'urgente' ? Cores.vermelhoClaro : nivel == 'atencao' ? Cores.ambarClaro : Cores.azulClaro;
    String? etiqueta;
    if (a['tipo'] == 'conta' && (a['dias'] ?? 0) < 0) {
      etiqueta = 'PENDENTE';
    } else if (nivel == 'urgente') {
      etiqueta = 'URGENTE';
    } else if (nivel == 'atencao') {
      etiqueta = 'ATENÇÃO';
    } else if (nivel == 'info') {
      etiqueta = 'INFO';
    }
    final valor = a['valor'];
    return Cartao(
      aoToque: aoToque,
      padding: const EdgeInsets.all(14),
      filho: Row(children: [
        Container(width: 4, height: 44, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Icon(iconeTipo(a['tipo']), color: cor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(a['titulo'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
              if (etiqueta != null) Etiqueta(etiqueta, cor: cor, fundo: fundo),
            ]),
            const SizedBox(height: 2),
            Text(a['detalhe'].toString(), style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
          ]),
        ),
        if (valor != null)
          Text('${a['estimado'] == true ? '~' : ''}${reais(valor as num)}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
