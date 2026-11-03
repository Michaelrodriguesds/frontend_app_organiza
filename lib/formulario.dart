// =====================================================================
// formulario.dart — formulário "inteligente" reutilizável.
// Em vez de criar uma tela de formulário para cada coisa, descrevemos os
// campos numa lista e a função pedir() abre uma folha com tudo pronto:
//
//   final r = await pedir(context, 'Nova despesa', [
//     Campo('descricao', 'O que foi?', obrigatorio: true),
//     Campo('valor', 'Valor', tipo: TipoCampo.numero, obrigatorio: true),
//   ]);
//   // r = {'descricao': 'Mercado', 'valor': 350.0}  (ou null se cancelou)
// =====================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tema.dart';

enum TipoCampo { texto, numero, data, opcoes, senha }

class Campo {
  final String chave;                 // nome do campo na API (ex.: 'valor')
  final String rotulo;                // texto mostrado ao usuário
  final TipoCampo tipo;
  final Map<String, String> opcoes;   // para tipo "opcoes": valor guardado -> texto mostrado
  final bool obrigatorio;
  final dynamic inicial;              // valor já preenchido (usado ao EDITAR)
  final int linhas;                   // para textos grandes (notas)

  const Campo(this.chave, this.rotulo,
      {this.tipo = TipoCampo.texto, this.opcoes = const {}, this.obrigatorio = false, this.inicial, this.linhas = 1});

  /// Cópia do campo com outro valor inicial (usado para editar um registro).
  Campo comInicial(dynamic v) =>
      Campo(chave, rotulo, tipo: tipo, opcoes: opcoes, obrigatorio: obrigatorio, inicial: v, linhas: linhas);
}

/// Abre o formulário. Devolve os valores digitados, ou null se o usuário cancelar.
/// Campos vazios voltam como null.
Future<Map<String, dynamic>?> pedir(BuildContext context, String titulo, List<Campo> campos, {String botao = 'Salvar'}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Cores.fundo,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _Formulario(titulo: titulo, campos: campos, botao: botao),
  );
}

class _Formulario extends StatefulWidget {
  final String titulo, botao;
  final List<Campo> campos;
  const _Formulario({required this.titulo, required this.campos, required this.botao});
  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final Map<String, TextEditingController> _textos = {};
  final Map<String, DateTime?> _datas = {};
  final Map<String, String> _escolhas = {};
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Prepara o estado de cada campo conforme o tipo.
    for (final c in widget.campos) {
      switch (c.tipo) {
        case TipoCampo.texto:
        case TipoCampo.senha:
          _textos[c.chave] = TextEditingController(text: c.inicial?.toString() ?? '');
        case TipoCampo.numero:
          final ini = c.inicial;
          _textos[c.chave] = TextEditingController(text: ini is num ? numeroParaCampo(ini) : (ini?.toString() ?? ''));
        case TipoCampo.data:
          DateTime? d = lerIso(c.inicial);
          if (d == null && c.obrigatorio && c.inicial == null) d = DateTime.now(); // obrigatória começa em "hoje"
          _datas[c.chave] = d;
        case TipoCampo.opcoes:
          final sel = c.inicial?.toString();
          _escolhas[c.chave] = (sel != null && c.opcoes.containsKey(sel))
              ? sel
              : (c.opcoes.isNotEmpty ? c.opcoes.keys.first : '');
      }
    }
  }

  @override
  void dispose() {
    for (final t in _textos.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherData(Campo c) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _datas[c.chave] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _datas[c.chave] = d);
  }

  /// Confere os campos e devolve os valores.
  void _salvar() {
    final saida = <String, dynamic>{};
    for (final c in widget.campos) {
      dynamic v;
      switch (c.tipo) {
        case TipoCampo.texto:
        case TipoCampo.senha:
          final txt = _textos[c.chave]!.text.trim();
          v = txt.isEmpty ? null : txt;
        case TipoCampo.numero:
          final digitado = _textos[c.chave]!.text.trim();
          if (digitado.isNotEmpty) {
            v = lerNumero(digitado);
            if (v == null) {
              setState(() => _erro = 'Número inválido em: ${c.rotulo}');
              return;
            }
          }
        case TipoCampo.data:
          final d = _datas[c.chave];
          v = d == null ? null : isoDoDia(d);
        case TipoCampo.opcoes:
          final s = _escolhas[c.chave]!;
          v = s.isEmpty ? null : s;
      }
      if (c.obrigatorio && v == null) {
        setState(() => _erro = 'Preencha: ${c.rotulo}');
        return;
      }
      saida[c.chave] = v;
    }
    Navigator.of(context).pop(saida);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets.bottom = altura do teclado, para o formulário subir junto
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Cores.linha, borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 14),
          Text(widget.titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final c in widget.campos) ...[
            _campo(c),
            const SizedBox(height: 12),
          ],
          if (_erro != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_erro!, style: const TextStyle(color: Cores.vermelho))),
          FilledButton(
            onPressed: _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: Cores.verde,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(widget.botao),
          ),
        ]),
      ),
    );
  }

  /// Desenha o campo certo para cada tipo.
  Widget _campo(Campo c) {
    final rotulo = c.obrigatorio ? c.rotulo : '${c.rotulo} (opcional)';
    switch (c.tipo) {
      case TipoCampo.data:
        final d = _datas[c.chave];
        return InkWell(
          onTap: () => _escolherData(c),
          child: InputDecorator(
            decoration: decoracao(
              rotulo,
              sufixo: (!c.obrigatorio && d != null)
                  ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _datas[c.chave] = null))
                  : const Icon(Icons.calendar_today, size: 20),
            ),
            child: Text(d == null ? 'Toque para escolher' : DateFormat('dd/MM/yyyy').format(d),
                style: TextStyle(color: d == null ? Cores.textoSuave : Cores.texto)),
          ),
        );
      case TipoCampo.opcoes:
        return InputDecorator(
          decoration: decoracao(rotulo),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _escolhas[c.chave],
              isExpanded: true,
              items: [for (final e in c.opcoes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _escolhas[c.chave] = v ?? ''),
            ),
          ),
        );
      case TipoCampo.numero:
        return TextField(
          controller: _textos[c.chave],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoracao(rotulo),
        );
      case TipoCampo.senha:
        return TextField(controller: _textos[c.chave], obscureText: true, decoration: decoracao(rotulo));
      case TipoCampo.texto:
        return TextField(
          controller: _textos[c.chave],
          minLines: c.linhas,
          maxLines: c.linhas,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoracao(rotulo),
        );
    }
  }
}
