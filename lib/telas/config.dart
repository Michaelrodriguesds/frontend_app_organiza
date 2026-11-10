// =====================================================================
// config.dart — Configurações: perfil, avisos, senha, exportar dados,
// feedback, excluir conta e sair.
// =====================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../componentes.dart';
import '../digital.dart';
import '../formulario.dart';
import '../tema.dart';
import 'auth.dart';

class TelaConfig extends StatelessWidget {
  const TelaConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Configurações',
      corpo: Carregador<Map<String, dynamic>>(
        carregar: Api.eu, // sempre busca os dados mais novos (dias de teste, config)
        construir: (c, u) {
          final liberado = u['liberado'] == true;
          final cfg = u['config'] as Map<String, dynamic>;
          return listaPadrao([
            // ----- perfil e situação do teste -----
            Cartao(
              filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u['nome']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${u['email']}', style: const TextStyle(color: Cores.textoSuave)),
                const SizedBox(height: 10),
                Text(
                  liberado ? 'Conta liberada' : 'Teste grátis: ${u['diasRestantes']} dia(s) restante(s)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: liberado ? Cores.ok : Cores.ambar),
                ),
                if (!liberado)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Quando o teste acabar, fale com myshelrodrigues@gmail.com para liberar.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                  ),
              ]),
            ),

            const Titulo('Avisos e projeção'),
            _opcao(c, Icons.person_outline, 'Meu nome', '${u['nome']}', () async {
              final r = await pedir(c, 'Meu nome', [Campo('nome', 'Nome', obrigatorio: true, inicial: u['nome'])]);
              if (r != null && c.mounted) await tentar(c, () => Api.put('/eu/config', r), ok: 'Nome alterado!');
            }),
            _opcao(c, Icons.shield_outlined, 'Reserva mínima', 'Avisa quando a projeção ficar abaixo de ${reais(cfg['reservaMinima'])}', () async {
              final r = await pedir(c, 'Reserva mínima', [
                Campo('reservaMinima', 'Valor que você não quer ficar abaixo (R\$)', tipo: TipoCampo.numero, obrigatorio: true, inicial: cfg['reservaMinima']),
              ]);
              if (r != null && c.mounted) await tentar(c, () => Api.put('/eu/config', r), ok: 'Salvo!');
            }),
            _opcao(c, Icons.notifications_active_outlined, 'Antecedência dos avisos', 'Avisar ${cfg['lembreteDias']} dia(s) antes do vencimento', () async {
              final r = await pedir(c, 'Antecedência dos avisos', [
                Campo('lembreteDias', 'Quantos dias antes avisar? (1 a 60)', tipo: TipoCampo.numero, obrigatorio: true, inicial: cfg['lembreteDias']),
              ]);
              if (r != null && c.mounted) await tentar(c, () => Api.put('/eu/config', r), ok: 'Salvo!');
            }),

            const Titulo('Segurança e dados'),
            _opcao(c, Icons.lock_outline, 'Trocar senha', 'Use pelo menos 6 caracteres', () async {
              final r = await pedir(c, 'Trocar senha', const [
                Campo('senhaAtual', 'Senha atual', tipo: TipoCampo.senha, obrigatorio: true),
                Campo('novaSenha', 'Nova senha', tipo: TipoCampo.senha, obrigatorio: true),
              ]);
              if (r != null && c.mounted) await tentar(c, () => Api.put('/eu/senha', r), ok: 'Senha alterada!');
            }),
            _CartaoDigital(nome: '${u['nome']}'), // ativar/desativar a digital
            _opcao(c, Icons.download_outlined, 'Exportar meus dados', 'Copia uma cópia de segurança (JSON) para a área de transferência', () async {
              try {
                final d = await Api.get('/exportar');
                await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(d)));
                if (c.mounted) aviso(c, 'Dados copiados! Cole num bloco de notas para guardar.');
              } on ApiErro catch (e) {
                if (c.mounted) aviso(c, e.mensagem, erro: true);
              }
            }),
            _opcao(c, Icons.chat_bubble_outline, 'Enviar feedback', 'Sugestões, dúvidas ou problemas', () async {
              final r = await pedir(c, 'Enviar feedback', const [Campo('texto', 'Sua mensagem', obrigatorio: true, linhas: 5)], botao: 'Enviar');
              if (r != null && c.mounted) await tentar(c, () => Api.post('/feedback', r), ok: 'Obrigado pelo feedback!');
            }),

            const Titulo('Conta'),
            _opcao(c, Icons.logout, 'Sair', 'Encerrar a sessão neste aparelho', () async {
              await Api.sair();
              if (c.mounted) Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false);
            }),
            _opcao(c, Icons.delete_forever_outlined, 'Excluir minha conta', 'Apaga a conta e todos os dados, sem volta', () async {
              final r = await pedir(c, 'Excluir conta', const [Campo('senha', 'Digite sua senha para confirmar', tipo: TipoCampo.senha, obrigatorio: true)], botao: 'Excluir tudo');
              if (r == null || !c.mounted) return;
              if (!await confirmar(c, 'Tem certeza?', 'Todos os seus dados serão apagados de vez.', botao: 'Excluir')) return;
              if (!c.mounted) return;
              final ok = await tentar(c, () => Api.apagar('/eu', r));
              if (ok) {
                await Api.sair();
                if (c.mounted) Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false);
              }
            }, perigo: true),
          ]);
        },
      ),
    );
  }

  Widget _opcao(BuildContext context, IconData icone, String titulo, String sub, VoidCallback? aoToque, {bool perigo = false}) => Cartao(
        aoToque: aoToque,
        filho: Row(children: [
          Icon(icone, color: perigo ? Cores.vermelho : Cores.verde),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, color: perigo ? Cores.vermelho : Cores.texto)),
              Text(sub, style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
            ]),
          ),
        ]),
      );
}

/// Cartão "Login por digital": liga e desliga o desbloqueio por digital neste aparelho.
class _CartaoDigital extends StatefulWidget {
  final String nome;
  const _CartaoDigital({required this.nome});
  @override
  State<_CartaoDigital> createState() => _CartaoDigitalState();
}

class _CartaoDigitalState extends State<_CartaoDigital> {
  bool _suportado = false, _ativa = false, _pronto = false;

  @override
  void initState() {
    super.initState();
    _ler();
  }

  Future<void> _ler() async {
    final sup = await Digital.suportado();
    final at = await Digital.ativa();
    if (mounted) setState(() { _suportado = sup; _ativa = at; _pronto = true; });
  }

  Future<void> _alternar() async {
    if (!_suportado) {
      aviso(context, 'Este aparelho/navegador não tem digital disponível (ou a tela não está em HTTPS).', erro: true);
      return;
    }
    if (_ativa) {
      if (!await confirmar(context, 'Desativar digital?', 'O app voltará a abrir direto, sem pedir a digital.', botao: 'Desativar')) return;
      await Digital.desativar();
      if (mounted) { setState(() => _ativa = false); aviso(context, 'Digital desativada.'); }
      return;
    }
    aviso(context, 'Toque no leitor de digital quando o aparelho pedir…');
    final ok = await Digital.ativar(widget.nome);
    if (!mounted) return;
    setState(() => _ativa = ok);
    aviso(context, ok ? 'Digital ativada! Na próxima vez que abrir o app ela será pedida.' : 'Não foi possível ativar a digital. Tente de novo.', erro: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final sub = !_pronto
        ? 'Verificando o aparelho…'
        : !_suportado
            ? 'Indisponível neste aparelho/navegador'
            : _ativa
                ? 'Ativada: o app pede a digital ao abrir'
                : 'Toque para ativar o desbloqueio por digital';
    return Cartao(
      aoToque: _pronto ? _alternar : null,
      filho: Row(children: [
        const Icon(Icons.fingerprint, color: Cores.verde),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Login por digital', style: TextStyle(fontWeight: FontWeight.w600, color: Cores.texto)),
            Text(sub, style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
        if (_pronto && _suportado) Switch(value: _ativa, onChanged: (_) => _alternar(), activeThumbColor: Cores.verde),
      ]),
    );
  }
}
