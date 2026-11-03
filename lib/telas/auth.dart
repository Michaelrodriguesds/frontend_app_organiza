// =====================================================================
// auth.dart — telas de acesso: Login, Cadastro, Esqueci a senha, Bloqueio.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';
import 'principal.dart';

bool _navegando = false;

/// Chamada quando a API responde que a sessão caiu (401), o teste acabou (402)
/// ou a conta está bloqueada (403). Leva o usuário para a tela certa.
/// Devolve true se tratou o erro.
bool tratarErroSessao(BuildContext context, ApiErro e) {
  if (e.status != 401 && e.status != 402 && e.status != 403) return false;
  if (!_navegando) {
    _navegando = true; // evita abrir a tela várias vezes se várias chamadas falharem juntas
    final Widget destino = e.status == 401 ? const TelaLogin() : TelaBloqueio(mensagem: e.mensagem);
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => destino), (_) => false);
    Future.delayed(const Duration(seconds: 1), () => _navegando = false);
  }
  return true;
}

void _irParaApp(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Principal()), (_) => false);
}

/// Moldura comum das telas de acesso (centralizada, largura máxima).
class _Moldura extends StatelessWidget {
  final Widget filho;
  final bool voltar;
  const _Moldura({required this.filho, this.voltar = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: voltar ? AppBar(backgroundColor: Cores.fundo, elevation: 0, scrolledUnderElevation: 0) : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: filho),
            ),
          ),
        ),
      );
}

Widget _botao(String texto, VoidCallback? aoApertar, {bool carregando = false}) => FilledButton(
      onPressed: carregando ? null : aoApertar,
      style: FilledButton.styleFrom(
        backgroundColor: Cores.verde,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: carregando
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(texto),
    );

Widget _erro(String? msg) =>
    msg == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 12), child: Text(msg, style: const TextStyle(color: Cores.vermelho)));

// ---------------------------------------------------------------------
// LOGIN
// ---------------------------------------------------------------------
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false, _ver = false;
  String? _msg;

  Future<void> _entrar() async {
    setState(() { _carregando = true; _msg = null; });
    try {
      await Api.login(_email.text.trim(), _senha.text);
      if (mounted) _irParaApp(context);
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (e.status == 402 || e.status == 403) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaBloqueio(mensagem: e.mensagem)));
      }
      setState(() => _msg = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Moldura(
        filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Organiza+', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Cores.verde)),
          const SizedBox(height: 22),
          const Text('Entrar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const Text('Bem-vindo de volta', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 22),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: decoracao('E-mail')),
          const SizedBox(height: 12),
          TextField(
            controller: _senha,
            obscureText: !_ver,
            onSubmitted: (_) => _entrar(),
            decoration: decoracao('Senha',
                sufixo: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver))),
          ),
          _erro(_msg),
          const SizedBox(height: 18),
          _botao('Entrar', _entrar, carregando: _carregando),
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEsqueci())), child: const Text('Esqueci minha senha')),
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCadastro())), child: const Text('Criar conta — 1 mês grátis')),
        ]),
      );
}

// ---------------------------------------------------------------------
// CADASTRO
// ---------------------------------------------------------------------
class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});
  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  String? _msg;

  Future<void> _criar() async {
    setState(() { _carregando = true; _msg = null; });
    try {
      await Api.cadastro(_nome.text.trim(), _email.text.trim(), _senha.text);
      if (mounted) _irParaApp(context);
    } on ApiErro catch (e) {
      setState(() => _msg = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Moldura(
        voltar: true,
        filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Criar conta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const Text('Você ganha 1 mês de uso grátis.', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 22),
          TextField(controller: _nome, textCapitalization: TextCapitalization.words, decoration: decoracao('Nome')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: decoracao('E-mail')),
          const SizedBox(height: 12),
          TextField(controller: _senha, obscureText: true, decoration: decoracao('Senha (mínimo 6 caracteres)')),
          _erro(_msg),
          const SizedBox(height: 18),
          _botao('Criar conta', _criar, carregando: _carregando),
        ]),
      );
}

// ---------------------------------------------------------------------
// ESQUECI A SENHA + REDEFINIR (as duas etapas na mesma tela)
// ---------------------------------------------------------------------
class TelaEsqueci extends StatefulWidget {
  const TelaEsqueci({super.key});
  @override
  State<TelaEsqueci> createState() => _TelaEsqueciState();
}

class _TelaEsqueciState extends State<TelaEsqueci> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _nova = TextEditingController();
  bool _enviado = false, _carregando = false;
  String? _msg;

  Future<void> _pedirCodigo() async {
    setState(() { _carregando = true; _msg = null; });
    try {
      await Api.esqueci(_email.text.trim());
      setState(() => _enviado = true);
    } on ApiErro catch (e) {
      setState(() => _msg = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _redefinir() async {
    setState(() { _carregando = true; _msg = null; });
    try {
      await Api.redefinir(_email.text.trim(), _codigo.text.trim(), _nova.text);
      if (!mounted) return;
      aviso(context, 'Senha alterada! Entre com a nova senha.');
      Navigator.of(context).pop();
    } on ApiErro catch (e) {
      setState(() => _msg = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Moldura(
        voltar: true,
        filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Recuperar senha', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          Text(_enviado ? 'Digite o código e a nova senha.' : 'Informe seu e-mail para gerar um código.', style: const TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 22),
          TextField(controller: _email, enabled: !_enviado, keyboardType: TextInputType.emailAddress, decoration: decoracao('E-mail')),
          if (_enviado) ...[
            const SizedBox(height: 12),
            TextField(controller: _codigo, keyboardType: TextInputType.number, decoration: decoracao('Código de 6 dígitos')),
            const SizedBox(height: 12),
            TextField(controller: _nova, obscureText: true, decoration: decoracao('Nova senha')),
          ],
          _erro(_msg),
          const SizedBox(height: 18),
          _botao(_enviado ? 'Redefinir senha' : 'Gerar código', _enviado ? _redefinir : _pedirCodigo, carregando: _carregando),
          if (!_enviado)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'Por enquanto o app não envia e-mail: o código aparece na janela do terminal onde a API está rodando. '
                'Se você perdeu o acesso, peça ao administrador uma senha temporária.',
                style: TextStyle(color: Cores.textoSuave, fontSize: 12.5),
              ),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------
// BLOQUEIO: teste acabou ou conta bloqueada
// ---------------------------------------------------------------------
class TelaBloqueio extends StatelessWidget {
  final String mensagem;
  const TelaBloqueio({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) => _Moldura(
        filho: Column(children: [
          const Icon(Icons.lock_clock, size: 56, color: Cores.ambar),
          const SizedBox(height: 16),
          Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 24),
          _botao('Voltar ao login', () async {
            await Api.sair();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false);
            }
          }),
        ]),
      );
}
