# Backup no Google Drive — configuração (uma vez só)

O app funciona normalmente sem isso; só o botão **Conectar** do backup no Drive depende desta configuração.
Exportar/Importar cópia em arquivo funciona sem Google.

O app se chama **Estudo Bíblico** (antes "Meu Diário"); o pacote continua `com.helio.diario`, então atualiza por cima sem perder dados.
Se você já criou o cliente OAuth com o nome antigo, não precisa mudar nada.

Dados do app:

- **Nome do pacote:** `com.helio.diario`
- **SHA-1 da chave de debug** (desenvolvimento): `B8:E5:DC:70:AA:2B:43:F2:CD:7A:FB:C1:A6:DE:44:61:94:02:FD:4B`
- **SHA-1 da chave de release** (APK em `releases/EstudoBiblico.apk`): `DD:2C:5C:49:0F:97:D9:81:FB:1E:0B:6D:4F:70:9E:81:4E:80:4D:53`

Cadastre **os dois** SHA-1 no Google Cloud (dois clientes Android, mesmo pacote `com.helio.diario`). Sem o SHA-1 de release, o login do Drive falha no APK publicado.
  (chave usada no APK atual: `~/.android/debug.keystore`, alias `androiddebugkey`)
- **Permissão usada:** `https://www.googleapis.com/auth/drive.appdata` (só a pasta oculta do app, o app não vê seus outros arquivos)

## Passo a passo

1. Acesse https://console.cloud.google.com/ com a sua conta Gmail.
2. **Criar projeto:** no topo, clique no seletor de projetos → **Novo projeto** → nome `Estudo Biblico` → **Criar**. Deixe-o selecionado.
3. **Ativar a API do Drive:** menu ☰ → **APIs e serviços → Biblioteca** → procure **Google Drive API** → **Ativar**.
4. **Tela de consentimento OAuth** (menu **APIs e serviços → Tela de consentimento OAuth**, ou "Google Auth Platform"):
   - Tipo de usuário: **Externo** → Criar.
   - Nome do app: `Estudo Bíblico`; e-mail de suporte e e-mail do desenvolvedor: seu Gmail → Salvar.
   - **Escopos (Acesso a dados):** adicione `.../auth/drive.appdata` → Salvar.
   - **Público / Usuários de teste:** deixe o status **Em teste** e adicione **o seu Gmail** como usuário de teste → Salvar.
5. **Criar o cliente Android:** **APIs e serviços → Credenciais → Criar credenciais → ID do cliente OAuth**:
   - Tipo de aplicativo: **Android**
   - Nome: `Estudo Bíblico Android`
   - Nome do pacote: `com.helio.diario`
   - Impressão digital SHA-1: primeiro o de debug (`B8:E5:DC:70:AA:2B:43:F2:CD:7A:FB:C1:A6:DE:44:61:94:02:FD:4B`), depois **crie outro cliente Android igual** com o SHA-1 de release (`DD:2C:5C:49:0F:97:D9:81:FB:1E:0B:6D:4F:70:9E:81:4E:80:4D:53`).
   - **Criar.** (Não precisa baixar arquivo nem mudar o app — o Google reconhece pelo pacote + SHA-1.)
6. Espere alguns minutos, abra o app → **Ajustes → Backup no Google Drive → Conectar** e escolha sua conta.
   Como o app está "em teste", o Google mostra um aviso "app não verificado": toque em **Continuar**.

## Observações

- Se o APK for assinado com outra chave no futuro, adicione o novo SHA-1 (ou crie outro cliente Android).
  SHA-1 de um APK: `apksigner verify --print-certs caminho/do.apk`
  SHA-1 da chave de debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
- O backup é cifrado (AES-256-GCM, chave derivada da senha do app com PBKDF2-SHA256, 100 mil iterações).
  **Para restaurar é preciso a senha do app usada quando o backup foi feito.** Sem ela não há como recuperar.
- A senha do app em si **não** vai no backup.
- Erro "10" / "DEVELOPER_ERROR" ao conectar = pacote ou SHA-1 errado no passo 5.
