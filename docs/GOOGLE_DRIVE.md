# Backup no Google Drive — configuração (uma vez só)

O app funciona normalmente sem isso; só o botão **Conectar** do backup no Drive depende desta configuração.
Exportar/Importar cópia em arquivo funciona sem Google.

Dados do app:

- **Nome do pacote:** `com.helio.diario`
- **SHA-1 do certificado de assinatura:** `B8:E5:DC:70:AA:2B:43:F2:CD:7A:FB:C1:A6:DE:44:61:94:02:FD:4B`
  (chave usada no APK atual: `~/.android/debug.keystore`, alias `androiddebugkey`)
- **Permissão usada:** `https://www.googleapis.com/auth/drive.appdata` (só a pasta oculta do app, o app não vê seus outros arquivos)

## Passo a passo

1. Acesse https://console.cloud.google.com/ com a sua conta Gmail.
2. **Criar projeto:** no topo, clique no seletor de projetos → **Novo projeto** → nome `Meu Diario` → **Criar**. Deixe-o selecionado.
3. **Ativar a API do Drive:** menu ☰ → **APIs e serviços → Biblioteca** → procure **Google Drive API** → **Ativar**.
4. **Tela de consentimento OAuth** (menu **APIs e serviços → Tela de consentimento OAuth**, ou "Google Auth Platform"):
   - Tipo de usuário: **Externo** → Criar.
   - Nome do app: `Meu Diário`; e-mail de suporte e e-mail do desenvolvedor: seu Gmail → Salvar.
   - **Escopos (Acesso a dados):** adicione `.../auth/drive.appdata` → Salvar.
   - **Público / Usuários de teste:** deixe o status **Em teste** e adicione **o seu Gmail** como usuário de teste → Salvar.
5. **Criar o cliente Android:** **APIs e serviços → Credenciais → Criar credenciais → ID do cliente OAuth**:
   - Tipo de aplicativo: **Android**
   - Nome: `Meu Diário Android`
   - Nome do pacote: `com.helio.diario`
   - Impressão digital SHA-1: `B8:E5:DC:70:AA:2B:43:F2:CD:7A:FB:C1:A6:DE:44:61:94:02:FD:4B`
   - **Criar.** (Não precisa baixar arquivo nem mudar o app — o Google reconhece pelo pacote + SHA-1.)
6. Espere alguns minutos, abra o app → **Ajustes → Backup no Google Drive → Conectar** e escolha sua conta.
   Como o app está "em teste", o Google mostra um aviso "app não verificado": toque em **Continuar**.

## Observações

- Se o APK for assinado com outra chave no futuro, adicione o novo SHA-1 (ou crie outro cliente Android). Ver o SHA-1:
  `~/jdk17/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
- O backup é cifrado (AES-256-GCM, chave derivada da senha do diário com PBKDF2-SHA256, 100 mil iterações).
  **Para restaurar é preciso a senha do diário usada quando o backup foi feito.** Sem ela não há como recuperar.
- A senha do diário em si **não** vai no backup.
- Erro "10" / "DEVELOPER_ERROR" ao conectar = pacote ou SHA-1 errado no passo 5.
