// =====================================================================
// main.dart — onde o app COMEÇA.
// 1) prepara datas em português  2) recupera o login guardado  3) abre o app
// =====================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'api.dart';
import 'tema.dart';
import 'telas/auth.dart';
import 'telas/principal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await Api.carregarSessao();
  runApp(const OrganizaApp());
}

class OrganizaApp extends StatelessWidget {
  const OrganizaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Organiza+',
        debugShowCheckedModeBanner: false,
        theme: temaApp(),
        // Deixa calendários e botões do Flutter em português
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Splash(),
      );
}

/// Tela de carregamento: vê se já existe login válido e decide para onde ir.
class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    Widget destino = const TelaLogin();
    if (Api.logado) {
      try {
        await Api.eu(); // confirma que o login ainda vale
        destino = const Principal();
      } on ApiErro catch (e) {
        // 402 = teste acabou | 403 = conta bloqueada | outros = volta ao login
        if (e.status == 402 || e.status == 403) destino = TelaBloqueio(mensagem: e.mensagem);
      }
    }
    await Future.delayed(const Duration(milliseconds: 500)); // só para a splash aparecer
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Cores.verde,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Organiza+', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Casa, veículos e finanças', style: TextStyle(color: Color(0xFFB9CFC5))),
            SizedBox(height: 28),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          ]),
        ),
      );
}
