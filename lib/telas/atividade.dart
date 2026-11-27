// =====================================================================
// atividade.dart — "Registro de atividade": o histórico de segurança da sua
// conta (logins, falhas, importações e Pix). Nunca mostra senhas nem chaves.
// =====================================================================
import 'package:flutter/material.dart';
import '../api.dart';
import '../componentes.dart';
import '../tema.dart';

const Map<String, String> _nomes = {
  'login.ok': 'Login realizado',
  'login.falha': 'Tentativa de login com senha incorreta',
  'extrato.importar': 'Extrato importado',
  'pix.envio.registrado': 'Pix a pagar registrado',
  'pix.cobranca.criar': 'Cobrança Pix criada',
  'pix.cobranca.confirmada': 'Pix recebido (confirmado pelo provedor)',
  'pix.cobranca.valor_divergente': 'Pix com valor diferente do cobrado (recusado)',
  'pix.webhook.segredo_invalido': 'Aviso de pagamento com senha inválida (recusado)',
  'pix.webhook.falha': 'Falha ao conferir aviso de pagamento',
};

class TelaAtividade extends StatelessWidget {
  const TelaAtividade({super.key});

  @override
  Widget build(BuildContext context) => Pagina(
        titulo: 'Registro de atividade',
        corpo: Carregador<List<Map<String, dynamic>>>(
          carregar: () => Api.lista('auditoria'),
          construir: (c, lista) => listaPadrao([
            const Text('As últimas ações da sua conta. Guardamos por 180 dias. Se vir algo que você não fez, troque a senha.', style: TextStyle(color: Cores.textoSuave)),
            const SizedBox(height: 12),
            if (lista.isEmpty) const Vazio('Nada registrado ainda.'),
            for (final a in lista)
              Cartao(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                filho: Row(children: [
                  Icon(a['ok'] == true ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: a['ok'] == true ? Cores.ok : Cores.vermelho, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_nomes[a['acao']] ?? '${a['acao']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(_quando(a['quando']), style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      );

  String _quando(dynamic v) {
    final d = lerIso(v);
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }
}
