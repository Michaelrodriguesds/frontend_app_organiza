// =====================================================================
// busca.dart — busca global: digite "óleo" e veja tudo relacionado
// (serviço do veículo, despesa, nota, etc.).
// =====================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'auth.dart';

class TelaBusca extends StatefulWidget {
  const TelaBusca({super.key});
  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  final _controle = TextEditingController();
  Timer? _espera; // "debounce": só busca quando você para de digitar
  List<Map<String, dynamic>> _grupos = [];
  bool _carregando = false;
  String? _msg;
  String _ultima = '';

  @override
  void dispose() {
    _espera?.cancel();
    _controle.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () => _buscar(texto.trim()));
  }

  Future<void> _buscar(String q) async {
    if (q.length < 2) {
      setState(() { _grupos = []; _msg = null; _ultima = q; });
      return;
    }
    setState(() { _carregando = true; _msg = null; });
    try {
      final d = await Api.get('/busca?q=${Uri.encodeQueryComponent(q)}') as List;
      if (!mounted) return;
      setState(() {
        _grupos = d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _ultima = q;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (!tratarErroSessao(context, e)) setState(() => _msg = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Buscar',
      corpo: ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 40), children: [
        TextField(
          controller: _controle,
          autofocus: true,
          onChanged: _aoDigitar,
          decoration: decoracao('Buscar em todo o app', dica: 'Ex.: óleo, gás, aniversário', sufixo: const Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        if (_carregando) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        if (_msg != null) Text(_msg!, style: const TextStyle(color: Cores.vermelho)),
        if (!_carregando && _ultima.length >= 2 && _grupos.isEmpty && _msg == null) const Vazio('Nada encontrado.'),
        for (final g in _grupos) ...[
          Titulo(g['grupo']),
          for (final i in (g['itens'] as List))
            Cartao(
              padding: const EdgeInsets.all(12),
              filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i['titulo'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((i['detalhe'] ?? '').toString().isNotEmpty)
                  Text(i['detalhe'].toString(), style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
              ]),
            ),
        ],
      ]),
    );
  }
}
