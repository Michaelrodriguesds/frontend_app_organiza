// =====================================================================
// digital.js — login por digital (WebAuthn) para o app no navegador/celular.
// Usa o leitor de digital (ou rosto/PIN) do próprio aparelho. Nada de
// biometria sai do aparelho: o navegador só responde "confirmado" ou não.
// O app Flutter chama estas 3 funções: suportado, registrar, verificar.
// Precisa de HTTPS (o Netlify já é) ou localhost.
// =====================================================================
window.organizaDigital = (function () {
  // converte bytes <-> texto (base64url) para guardar o id da credencial
  const paraTexto = (buf) =>
    btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const paraBytes = (s) => {
    s = s.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4) s += '=';
    const bin = atob(s), a = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) a[i] = bin.charCodeAt(i);
    return a;
  };
  const aleatorio = (n) => crypto.getRandomValues(new Uint8Array(n));

  return {
    // O aparelho tem leitor de digital/biometria? (true/false)
    suportado: async function () {
      try {
        return !!(window.PublicKeyCredential &&
          PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable &&
          (await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()));
      } catch (e) { return false; }
    },

    // Ativar: pede a digital uma vez e devolve o id da credencial (texto) ou null.
    registrar: async function (nome) {
      try {
        const c = await navigator.credentials.create({
          publicKey: {
            challenge: aleatorio(32),
            rp: { name: 'Organiza+' },
            user: { id: aleatorio(16), name: nome || 'usuario', displayName: nome || 'Usuário' },
            pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
            authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required', residentKey: 'discouraged' },
            timeout: 60000,
            attestation: 'none',
          },
        });
        return paraTexto(c.rawId);
      } catch (e) { return null; }
    },

    // Desbloquear: pede a digital e devolve true (confirmou) ou false.
    verificar: async function (id) {
      try {
        const r = await navigator.credentials.get({
          publicKey: {
            challenge: aleatorio(32),
            allowCredentials: [{ type: 'public-key', id: paraBytes(id), transports: ['internal'] }],
            userVerification: 'required',
            timeout: 60000,
          },
        });
        return !!r;
      } catch (e) { return false; }
    },
  };
})();
