// =====================================================================
// pix.dart — Pix no Organiza+, com HONESTIDADE sobre o que é possível:
//
//  • RECEBER: gera QR Code e "copia e cola" pelo provedor (Mercado Pago),
//    se estiver ativado no servidor. O Pix só aparece como RECEBIDO depois
//    que o provedor confirma (a tela consulta sozinha a cada poucos segundos).
//  • ENVIAR: o app NÃO move dinheiro do seu banco. Ele REGISTRA o Pix como
//    "conta a pagar"; você paga no app do seu banco e depois marca como pago.
//    (Enviar Pix de dentro de um app exige instituição autorizada pelo Banco
//    Central e normalmente é pago — veja INTEGRACAO-PIX.md.)
// =====================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'auth.dart';

void _copiar(BuildContext context, String texto, String msg) {
  Clipboard.setData(ClipboardData(text: texto));
  aviso(context, msg);
}

// ---------------------------------------------------------------------
// HUB do Pix
// ---------------------------------------------------------------------
class TelaPix extends StatelessWidget {
  const TelaPix({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Pix',
      corpo: Carregador<List<dynamic>>(
        carregar: () async => [await Api.mapa('/pix/status'), await Api.lista('pix/cobrancas')],
        construir: (c, d) {
          final status = d[0] as Map<String, dynamic>;
          final cobrancas = d[1] as List<Map<String, dynamic>>;
          final recebe = (status['receber'] as Map)['ativo'] == true;
          return listaPadrao([
            Cartao(
              aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const TelaPixReceber())),
              filho: _linhaAcao(Icons.qr_code_2, 'Receber Pix', recebe ? 'Gerar QR Code e copia e cola' : 'Ainda não ativado — veja como ativar'),
            ),
            Cartao(
              aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const TelaPixEnviar())),
              filho: _linhaAcao(Icons.send_outlined, 'Enviar Pix', 'Prepara o Pix e registra como conta a pagar'),
            ),
            const Titulo('Cobranças recentes'),
            if (cobrancas.isEmpty) const Vazio('Nenhuma cobrança Pix criada ainda.'),
            for (final x in cobrancas)
              Cartao(
                aoToque: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => TelaCobranca(cobrancaId: x['_id']))),
                filho: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${x['descricao']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(dataBR(x['criadoEm']), style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                  Text(reais(x['valor']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  _etiquetaStatus('${x['status']}'),
                ]),
              ),
          ]);
        },
      ),
    );
  }

  Widget _linhaAcao(IconData i, String t, String s) => Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Cores.verdeClaro, borderRadius: BorderRadius.circular(12)),
          child: Icon(i, color: Cores.verde),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(s, style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Cores.textoSuave),
      ]);
}

Widget _etiquetaStatus(String s) {
  switch (s) {
    case 'confirmado':
      return const Etiqueta('CONFIRMADO', cor: Cores.ok, fundo: Cores.verdeClaro);
    case 'pendente':
      return const Etiqueta('AGUARDANDO', cor: Cores.ambar, fundo: Cores.ambarClaro);
    case 'expirado':
      return const Etiqueta('EXPIRADO', cor: Cores.textoSuave, fundo: Cores.linha);
    case 'cancelado':
      return const Etiqueta('CANCELADO', cor: Cores.vermelho, fundo: Cores.vermelhoClaro);
    default:
      return const Etiqueta('FALHOU', cor: Cores.vermelho, fundo: Cores.vermelhoClaro);
  }
}

// ---------------------------------------------------------------------
// RECEBER
// ---------------------------------------------------------------------
class TelaPixReceber extends StatefulWidget {
  const TelaPixReceber({super.key});
  @override
  State<TelaPixReceber> createState() => _TelaPixReceberState();
}

class _TelaPixReceberState extends State<TelaPixReceber> {
  final _valor = TextEditingController();
  final _desc = TextEditingController();
  bool _ocupado = false;
  String? _chaveUsada, _corpoUsado; // reaproveita a mesma chave se o pedido for repetido (rede caiu, etc.)

  @override
  void dispose() {
    _valor.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _novaChave() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}-${Random().nextInt(1 << 30)}';

  Future<void> _gerar() async {
    final v = lerNumero(_valor.text);
    if (v == null || v < 0.01) {
      aviso(context, 'Informe um valor válido.', erro: true);
      return;
    }
    final corpo = {'valor': v, 'descricao': _desc.text.trim().isEmpty ? 'Pix recebido' : _desc.text.trim()};
    final assinatura = jsonEncode(corpo);
    // Mesmo pedido = mesma chave (a API devolve a MESMA cobrança, sem duplicar).
    if (_corpoUsado != assinatura || _chaveUsada == null) {
      _chaveUsada = _novaChave();
      _corpoUsado = assinatura;
    }
    setState(() => _ocupado = true);
    try {
      final r = await Api.post('/pix/cobrancas', corpo, {'Idempotency-Key': _chaveUsada!}) as Map;
      if (!mounted) return;
      recargaGlobal.recarregar();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaCobranca(cobrancaId: '${r['_id']}', inicial: Map<String, dynamic>.from(r))));
    } on ApiErro catch (e) {
      if (mounted && !tratarErroSessao(context, e)) aviso(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Receber Pix',
      corpo: Carregador<Map<String, dynamic>>(
        carregar: () => Api.mapa('/pix/status'),
        construir: (c, st) {
          final ativo = (st['receber'] as Map)['ativo'] == true;
          return listaPadrao([
            if (ativo) ...[
              Cartao(
                filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Criar cobrança Pix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(controller: _valor, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: decoracao('Valor (R\$)')),
                  const SizedBox(height: 10),
                  TextField(controller: _desc, decoration: decoracao('Descrição (opcional)')),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Cores.verde, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _ocupado ? null : _gerar,
                      icon: const Icon(Icons.qr_code_2),
                      label: Text(_ocupado ? 'Gerando…' : 'Gerar QR Code'),
                    ),
                  ),
                ]),
              ),
              const Aviso(
                'O dinheiro cai na sua conta do Mercado Pago (não direto no banco). O valor só aparece como recebido no Organiza+ depois que o Mercado Pago confirmar o pagamento.',
                icone: Icons.info_outline,
              ),
            ] else
              const Aviso(
                'Receber Pix pelo app ainda não está ativado. Para ligar é preciso ter uma conta no Mercado Pago e configurar o servidor (passo a passo no arquivo INTEGRACAO-PIX.md). '
                'Enquanto isso, você pode guardar suas chaves Pix aqui abaixo para copiar e passar para quem vai pagar — e depois importar o extrato do banco.',
                icone: Icons.info_outline,
              ),
            const Titulo('Minhas chaves Pix'),
            const _MinhasChaves(),
            const Titulo('Como receber'),
            const Cartao(
              filho: Text(
                '1. Passe sua chave Pix (ou o QR Code / copia e cola) para quem vai pagar.\n'
                '2. A pessoa paga pelo app do banco dela.\n'
                '3. O Organiza+ registra a entrada quando o pagamento for confirmado (cobranças) ou quando você importar o extrato do banco.',
                style: TextStyle(height: 1.4),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Chaves Pix do próprio usuário. Ficam SÓ neste aparelho (para copiar rápido);
/// chave Pix não é senha, mas também não enviamos ao servidor.
class _MinhasChaves extends StatefulWidget {
  const _MinhasChaves();
  @override
  State<_MinhasChaves> createState() => _MinhasChavesState();
}

class _MinhasChavesState extends State<_MinhasChaves> {
  List<String> _chaves = [];

  @override
  void initState() {
    super.initState();
    _ler();
  }

  Future<void> _ler() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _chaves = p.getStringList('minhas_chaves_pix') ?? []);
  }

  Future<void> _gravar(List<String> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('minhas_chaves_pix', l);
    if (mounted) setState(() => _chaves = l);
  }

  Future<void> _adicionar() async {
    final ctl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar chave Pix'),
        content: TextField(controller: ctl, autofocus: true, decoration: decoracao('CPF, telefone, e-mail ou chave aleatória')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    ctl.dispose();
    if (r == null || r.isEmpty) return;
    if (!_chaves.contains(r)) await _gravar([..._chaves, r]);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final k in _chaves)
          Cartao(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            filho: Row(children: [
              const Icon(Icons.key_outlined, color: Cores.verde, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(k, overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.copy, size: 19), tooltip: 'Copiar', onPressed: () => _copiar(context, k, 'Chave copiada.')),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20), tooltip: 'Remover', onPressed: () => _gravar(_chaves.where((x) => x != k).toList())),
            ]),
          ),
        if (_chaves.isEmpty) const Vazio('Nenhuma chave guardada. Elas ficam só neste aparelho.'),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _adicionar, icon: const Icon(Icons.add), label: const Text('Guardar uma chave'))),
      ]);
}

// ---------------------------------------------------------------------
// COBRANÇA (QR Code + acompanhamento do status)
// ---------------------------------------------------------------------
class TelaCobranca extends StatefulWidget {
  final String cobrancaId;
  final Map<String, dynamic>? inicial;
  const TelaCobranca({super.key, required this.cobrancaId, this.inicial});
  @override
  State<TelaCobranca> createState() => _TelaCobrancaState();
}

class _TelaCobrancaState extends State<TelaCobranca> {
  Map<String, dynamic>? _c;
  String? _erro;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = widget.inicial;
    _consultar();
    // Pergunta ao servidor (que pergunta ao provedor) a cada 5 s enquanto estiver pendente.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_c == null || _c!['status'] == 'pendente') _consultar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final r = await Api.mapa('/pix/cobrancas/${widget.cobrancaId}');
      if (!mounted) return;
      final mudou = _c != null && _c!['status'] != r['status'];
      setState(() {
        _c = {...?_c, ...r};
        _erro = r['aviso']?.toString();
      });
      if (mudou) recargaGlobal.recarregar(); // atualiza carteira/extrato
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (tratarErroSessao(context, e)) return;
      setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Pagina(titulo: 'Pix', corpo: Center(child: _erro == null ? const CircularProgressIndicator() : Text(_erro!, style: const TextStyle(color: Cores.vermelho))));
    }
    final status = '${c['status']}';
    return Pagina(
      titulo: status == 'confirmado' ? 'Pix recebido' : 'Cobrança Pix',
      corpo: listaPadrao([
        if (status == 'confirmado') _comprovante(c) else _qr(c, status),
        if (_erro != null) Aviso(_erro!, cor: Cores.ambar, fundo: Cores.ambarClaro),
      ]),
    );
  }

  Widget _qr(Map<String, dynamic> c, String status) {
    final b64 = c['qrBase64']?.toString();
    final copia = c['copiaECola']?.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Cartao(
        filho: Column(children: [
          Text(reais(c['valor']), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          Text('${c['descricao']}', style: const TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 8),
          _etiquetaStatus(status),
          const SizedBox(height: 14),
          if (status == 'pendente' && b64 != null && b64.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Image.memory(base64Decode(b64), width: 230, height: 230, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          if (status == 'pendente') ...[
            const SizedBox(height: 10),
            Text('Vence em ${dataBR(c['expiraEm'])}. Aguardando o pagamento…', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ],
          if (status == 'expirado') const Text('Esta cobrança expirou. Gere outra.', style: TextStyle(color: Cores.textoSuave)),
          if (status == 'falhou' || status == 'cancelado') const Text('Esta cobrança não foi concluída. Nenhum valor foi lançado.', style: TextStyle(color: Cores.vermelho)),
        ]),
      ),
      if (status == 'pendente' && copia != null && copia.isNotEmpty) ...[
        Cartao(
          filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pix copia e cola', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(copia, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoSuave, fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => _copiar(context, copia, 'Código copiado.'), icon: const Icon(Icons.copy), label: const Text('Copiar código')),
          ]),
        ),
        const Aviso('Só aparece como RECEBIDO quando o Mercado Pago confirmar. Esta tela confere sozinha a cada poucos segundos.', icone: Icons.hourglass_bottom),
      ],
    ]);
  }

  /// Comprovante: só existe porque o PROVEDOR confirmou o pagamento.
  Widget _comprovante(Map<String, dynamic> c) => Cartao(
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: Icon(Icons.check_circle, color: Cores.ok, size: 54)),
          const SizedBox(height: 8),
          const Center(child: Text('Pix recebido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          Center(child: Text(reais(c['valor']), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Cores.ok))),
          const Divider(height: 28),
          Text('Descrição: ${c['descricao']}'),
          Text('Confirmado em: ${dataBR(c['confirmadoEm'])}'),
          Text('Confirmado por: ${c['provedor'] ?? 'Mercado Pago'}'),
          Text('Código: ${c['_id']}', style: const TextStyle(fontSize: 12.5, color: Cores.textoSuave)),
          const SizedBox(height: 10),
          const Text('Entrada já lançada no seu extrato.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
        ]),
      );
}

// ---------------------------------------------------------------------
// ENVIAR (prepara e REGISTRA — quem paga é o app do seu banco)
// ---------------------------------------------------------------------
class TelaPixEnviar extends StatefulWidget {
  const TelaPixEnviar({super.key});
  @override
  State<TelaPixEnviar> createState() => _TelaPixEnviarState();
}

class _TelaPixEnviarState extends State<TelaPixEnviar> {
  final _chave = TextEditingController();
  final _nome = TextEditingController();
  final _valor = TextEditingController();
  int _etapa = 0; // 0 dados | 1 revisão | 2 registrado
  bool _ocupado = false;
  Map<String, dynamic>? _resp;
  bool _pago = false;

  @override
  void dispose() {
    _chave.dispose();
    _nome.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _revisar() {
    final v = lerNumero(_valor.text);
    if (_chave.text.trim().isEmpty) return aviso(context, 'Informe a chave Pix.', erro: true);
    if (_nome.text.trim().length < 2) return aviso(context, 'Informe o nome de quem vai receber.', erro: true);
    if (v == null || v < 0.01) return aviso(context, 'Informe um valor válido.', erro: true);
    setState(() => _etapa = 1);
  }

  Future<void> _registrar({bool forcar = false}) async {
    setState(() => _ocupado = true);
    try {
      final r = await Api.post('/pix/envios', {
        'chave': _chave.text.trim(),
        'nome': _nome.text.trim(),
        'valor': lerNumero(_valor.text),
        if (forcar) 'forcar': true,
      });
      if (!mounted) return;
      recargaGlobal.recarregar();
      setState(() {
        _resp = Map<String, dynamic>.from(r as Map);
        _etapa = 2;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        if (await confirmar(context, 'Pix repetido?', e.mensagem, botao: 'É outro Pix')) await _registrar(forcar: true);
      } else if (!tratarErroSessao(context, e)) {
        aviso(context, e.mensagem, erro: true);
        setState(() => _etapa = 0);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _marcarPago() async {
    final id = (_resp?['movimentacao'] as Map?)?['_id'];
    if (!await confirmar(context, 'Você já pagou no banco?', 'Só marque se o Pix realmente saiu do seu banco. O Organiza+ não consegue conferir isso sozinho.', botao: 'Já paguei')) return;
    if (!mounted) return;
    if (await tentar(context, () => Api.put('/movimentacoes/$id', {'pago': true}), ok: 'Marcado como pago.')) setState(() => _pago = true);
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Enviar Pix',
      corpo: listaPadrao([
        const Aviso(
          'O Organiza+ não envia dinheiro: ele prepara e registra o Pix. Quem paga é o app do seu banco.',
          icone: Icons.info_outline,
        ),
        const SizedBox(height: 12),
        if (_etapa == 0) _dados(),
        if (_etapa == 1) _revisao(),
        if (_etapa == 2) _registrado(),
      ]),
    );
  }

  Widget _dados() => Cartao(
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _chave, decoration: decoracao('Chave Pix', dica: 'CPF, CNPJ, +55…, e-mail ou chave aleatória')),
          const SizedBox(height: 10),
          TextField(controller: _nome, decoration: decoracao('Nome de quem vai receber')),
          const SizedBox(height: 10),
          TextField(controller: _valor, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: decoracao('Valor (R\$)')),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cores.verde, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _revisar,
              child: const Text('Revisar'),
            ),
          ),
        ]),
      );

  Widget _revisao() => Cartao(
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Revise antes de confirmar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          Text(reais(lerNumero(_valor.text)), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Para: ${_nome.text.trim()}'),
          Text('Chave: ${_chave.text.trim()}'),
          const SizedBox(height: 10),
          const Text(
            'Atenção: o app não consegue consultar de quem é essa chave (isso só o banco faz). O nome acima foi digitado por você. '
            'Confira o nome do destinatário na tela do seu banco antes de pagar.',
            style: TextStyle(color: Cores.ambar, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _ocupado ? null : () => setState(() => _etapa = 0), child: const Text('Voltar'))),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Cores.verde),
                onPressed: _ocupado ? null : () => _registrar(),
                child: Text(_ocupado ? 'Registrando…' : 'Registrar como a pagar'),
              ),
            ),
          ]),
        ]),
      );

  Widget _registrado() {
    final chave = '${_resp?['chave'] ?? _chave.text.trim()}';
    return Cartao(
      filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_pago ? Icons.check_circle : Icons.hourglass_bottom, color: _pago ? Cores.ok : Cores.ambar),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_pago ? 'Marcado como pago por você' : 'AGUARDANDO você pagar no banco',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${reais(lerNumero(_valor.text))} para ${_nome.text.trim()}'),
        const SizedBox(height: 10),
        if (!_pago) ...[
          const Text('Próximos passos:\n1. Copie a chave abaixo.\n2. Abra o app do seu banco e faça o Pix.\n3. Volte e toque em "Já paguei".', style: TextStyle(height: 1.4)),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => _copiar(context, chave, 'Chave copiada.'), icon: const Icon(Icons.copy), label: const Text('Copiar chave')),
          const SizedBox(height: 8),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Cores.verde), onPressed: _marcarPago, child: const Text('Já paguei')),
        ] else
          const Text(
            'Sem comprovante bancário: o Organiza+ não tem como confirmar. O comprovante oficial está no app do seu banco.',
            style: TextStyle(color: Cores.textoSuave, fontSize: 12.5),
          ),
      ]),
    );
  }
}
