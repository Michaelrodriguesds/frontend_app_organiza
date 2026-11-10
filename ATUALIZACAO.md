# Atualização — digital, ícone e correção dos lembretes

## O que mudou
1. **Login por digital** (Configurações → Login por digital).
   - Ativar: o aparelho pede a digital uma vez.
   - Depois, ao abrir o app, aparece "Confirme sua digital para entrar".
   - "Entrar com e-mail e senha" apaga o login guardado e volta ao login.
   - Funciona no celular com leitor de digital/biometria e tela de bloqueio configurada, em HTTPS (o Netlify é).
   - Arquivos: `web/digital.js`, `lib/digital.dart`, `lib/telas/auth.dart` (TelaDesbloqueio), `lib/main.dart`, `lib/telas/config.dart`.
2. **Ícone e nome do app**: ícone "O+" verde, nome "Organiza+" (`web/icons/*`, `web/favicon.png`, `web/manifest.json`, `web/index.html`).
3. **Erro "Valor inválido no campo: _id" nos lembretes**: as abas "Próximos 90 dias" e "Lembretes" (e "Estoque"/"Despesas" na Casa) reaproveitavam os dados uma da outra. Cada aba agora tem sua chave (`agenda.dart`, `casa.dart`).
4. Mensagens de erro ficam 10 s na tela, com botão de fechar, e mostram qual chamada falhou (ex.: `PUT /lembretes/...`), para facilitar achar problemas.

## Como publicar
```powershell
git add .
git commit -m "Digital, icone e correcao dos lembretes"
git push
```
O Netlify compila e publica sozinho (netlify.toml).

## No celular depois do deploy
- Feche e abra o app (ou limpe os dados do site) para pegar a versão nova.
- Para trocar o ícone: remova o atalho da tela inicial e adicione de novo (Chrome → menu → Instalar app / Adicionar à tela inicial).
