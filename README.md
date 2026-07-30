# Meu Treino

App pessoal para acompanhamento de treinos de musculação. Roda quase 100% no navegador — a única peça de servidor é uma integração opcional com o Strava, pra puxar dados do Garmin automaticamente.

**→ [Abrir o app](https://gll86.github.io/app-treino)**

---

## O que é

Um app de academia que cabe num único arquivo HTML. Você abre no celular, inicia o treino guiado, confirma exercício por exercício (com a carga usada) e o progresso fica salvo localmente. Edições nos treinos, cargas e histórico de evolução sincronizam entre dispositivos via Firebase quando você está logado com o Google.

É um **PWA (Progressive Web App)**: pode ser instalado direto do browser e abre em tela cheia como um app nativo, sem barra de endereço.

**Para instalar:**
- **Android (Chrome):** abre a URL → menu ⋮ → "Adicionar à tela inicial"
- **iPhone (Safari):** abre a URL → compartilhar → "Adicionar à Tela de Início"

---

## Como funciona

### Stack intencional: zero dependências de build

O app é um único arquivo `index.html` com HTML, CSS e JavaScript embutidos. Sem React, sem Vue, sem bundler, sem `npm install`. Essa foi uma escolha deliberada:

- **Portabilidade total** — o arquivo funciona aberto direto no browser, sem servidor local
- **Simples de entender** — qualquer pessoa que sabe HTML/CSS/JS consegue ler e modificar
- **Deploy trivial** — um `git push` publica uma nova versão via GitHub Pages

As únicas dependências externas são carregadas via CDN: Google Fonts e o Firebase SDK (Authentication + Realtime Database).

### Persistência e sync entre dispositivos

O progresso do dia (exercícios marcados como concluídos) é salvo no `localStorage` com a chave `done_{treino}_{data}`. Funciona offline, persiste entre sessões, e é por dispositivo — não sincroniza entre celular e notebook (faz sentido: o treino de hoje no celular não precisa aparecer no notebook).

As edições nos treinos (nomes, séries, ordem dos exercícios) sincronizam entre dispositivos via **Firebase Realtime Database**. O fluxo é:

1. O app carrega do `localStorage` imediatamente (rápido, sem esperar rede)
2. Se o usuário estiver logado, busca os treinos do Firebase e atualiza o app
3. Ao salvar edições ("✅ Salvar alterações"), escreve em ambos: localStorage e Firebase

A autenticação usa **Google Sign-In** — o botão "☁ Entrar" no header abre um popup de login. Os dados ficam em `/users/{uid}/treinos`, `/users/{uid}/cargas` e `/users/{uid}/historico` no Firebase, com regras que garantem que cada usuário só lê e escreve os próprios dados.

### Sessão guiada, carga e histórico

Cada exercício tem um campo de carga (kg): começa vazio e, depois de preenchido uma vez, sempre recarrega o último valor salvo (`cargas[treino][nomeExercício]`).

O progresso não é mais marcado livremente tocando em qualquer exercício. O botão "▶ Iniciar treino" liga uma sessão guiada que destaca visualmente (borda, sombra, tag "AGORA") o próximo exercício pendente — só ele responde ao toque. Confirmar aquele exercício:

1. marca como concluído
2. grava um ponto de histórico (`historico[treino][nomeExercício]`) com a data e a carga preenchida, se houver
3. avança automaticamente o destaque para o próximo pendente

Ao concluir todos, aparece a tela de "TREINO CONCLUÍDO!". Durante a sessão, o botão vira "■ Encerrar treino": aborta e reseta o progresso do dia sem gravar nada (mesma ação do ↺ de reset que já existia).

O histórico por enquanto é só persistência (Firebase + localStorage) — ainda não tem uma tela própria de gráfico/evolução.

### Integração com Garmin (via Strava)

Quem treina com um relógio Garmin no perfil "Strength Training" pode conectar a conta do Strava (menu ☰ → "🔗 Strava") pra enriquecer automaticamente o histórico com duração, frequência cardíaca e calorias de cada sessão — sem digitar nada. Como a Garmin não sincroniza retroativamente, só pega treinos gravados **depois** de conectar as contas.

A Garmin não tem API pública pra pessoa física, então o caminho é: Garmin sincroniza nativamente com o Strava, e o app usa a API do Strava (exige assinatura paga deles) pra buscar os dados. Como o `client_secret` do OAuth não pode ficar exposto num arquivo estático, isso precisou da primeira peça de back-end do projeto: duas functions serverless na **Vercel**, publicadas a partir do mesmo repositório GitHub, sem afetar o deploy do front-end (GitHub Pages continua servindo só o `index.html`, como sempre).

Uma vez conectado, uma sincronização automática roda uma vez por noite (Vercel Cron) e grava o resumo do dia anterior em `sessoes[data]` — sem precisar apertar nada. Detalhes técnicos completos (variáveis de ambiente, arquitetura, uma particularidade encontrada com variáveis "Sensitive" na Vercel) estão no `CLAUDE.md`.

### Os treinos ficam no código

Os 6 treinos (A–F) são um objeto JavaScript hardcoded no arquivo:

```js
const TREINOS_DATA = {
  "A": {
    label: "TREINO A — Peito + Tríceps",
    grupos: [
      { nome: "Peito", exercicios: [{ nome: "Supino reto", series: 4, reps: 12 }, ...] }
    ]
  },
  // ...até F
}
```

Em runtime isso é clonado para uma variável mutável (`treinos`), que recebe as edições da sessão.

### Editar e salvar

O modo de edição permite renomear exercícios e grupos, ajustar séries, reordenar via drag-and-drop (funciona no touch também) e adicionar/remover itens — tudo em memória. O botão "✅ Salvar alterações" persiste as mudanças no `localStorage` e, se o usuário estiver logado, sincroniza com o Firebase em seguida.

---

## Deploy: do notebook ao celular sem WhatsApp

Antes, o fluxo era: editar o arquivo no notebook → enviar via WhatsApp → salvar no celular → abrir no Chrome. Funcionava, mas era chato.

A solução foi publicar via **GitHub Pages**: o repositório é público e o GitHub serve o `index.html` direto em `https://gll86.github.io/app-treino`. O celular acessa essa URL, e o `localStorage` persiste entre sessões porque a origem é sempre a mesma.

O back-end da integração com Strava (pasta `/api`) é publicado separadamente via **Vercel**, conectada ao mesmo repositório — um `git push` atualiza os dois deploys ao mesmo tempo, sem passo manual extra.

---

## Pipeline de desenvolvimento

Cada mudança no app segue este fluxo:

### 1. Editar
Modificar o `index.html` localmente. Visualizar abrindo o arquivo no browser ou com Live Server.

### 2. Validar
Rodar o script de validação antes de commitar:

```powershell
powershell -ExecutionPolicy Bypass -File validate.ps1
```

O script verifica:
- **Divs balanceados** — número de `<div>` abrindo igual ao de `</div>` fechando
- **IDs obrigatórios presentes** — `#panels`, `#tabs`, cada painel de `#panel-A` a `#panel-F`
- **Contagem de exercícios** — bate com o snapshot salvo em `validate.snapshot.json`
- **Padrões proibidos** — funcionalidades removidas não voltaram por engano

Se a mudança alterou intencionalmente a contagem de exercícios, atualizar o snapshot antes:

```powershell
powershell -ExecutionPolicy Bypass -File validate.ps1 -Update
```

### 3. Commitar
```bash
git add index.html
git commit -m "descrição da mudança"
```

Se o snapshot foi atualizado, incluir no commit:
```bash
git add index.html validate.snapshot.json
git commit -m "descrição da mudança"
```

### 4. Publicar
```bash
git push
```

O GitHub Pages atualiza em ~1 minuto. Recarregar no celular para ver as mudanças.

### 5. Atualizar a documentação
Se a mudança adicionou, removeu ou alterou alguma funcionalidade relevante, atualizar este README e o `CLAUDE.md`:

```bash
git add README.md CLAUDE.md
git commit -m "docs: atualiza documentação"
git push
```

---

## Decisões ao longo do caminho

### O que foi removido (e por quê)

**Histórico por exercício** — o app tinha um diário completo com calendário de sessões, gráfico de evolução de carga/volume e análise por IA. Ficou complexo demais para o uso real no dia a dia. Removido em favor de uma interface mais limpa e direta.

**Sub-linhas de série** — cada exercício expandia para mostrar inputs de peso e reps por série individual, com botão para marcar cada série como concluída e botão para replicar os valores da primeira série para todas. Na prática não era usado. Simplificado para uma única linha por exercício com marcação pelo círculo de check.

**Análise por IA** — chamava a API da Anthropic para sugestões de progressão baseadas no histórico do exercício. Dependia de um contexto específico (rodava dentro do Claude.ai artifacts, que injeta autenticação automaticamente) e foi removida junto com o histórico.

**Marcação livre de exercícios** — originalmente qualquer exercício podia ser marcado como concluído tocando em qualquer ordem. Substituído por uma sessão guiada obrigatória (só o exercício em destaque responde ao toque, avançando automaticamente ao confirmar) porque a marcação livre não deixava claro qual exercício fazer em seguida, e passou a ser o ponto de entrada natural para registrar a carga usada em cada um.

### Por que não usar um framework

A pergunta natural ao ver um app de interface interativa é "por que não React/Vue?". A resposta é custo-benefício: o app tem uma tela, sem roteamento, sem estado global complexo, sem server-side rendering, sem time trabalhando nele. Adicionar um framework significaria build step, `node_modules`, configuração de bundler e uma camada extra de abstração — tudo isso para resolver problemas que esse app não tem.

Vanilla JS com funções pequenas e diretas cobre 100% do que é necessário aqui.

### Por que arquivo único

Facilita o backup (um arquivo), facilita compartilhar (um arquivo), e mantém o deploy simples: um `git push` publica uma nova versão via GitHub Pages sem build step ou pipeline de CI.

---

## Estrutura do arquivo

```
index.html
├── <head>
│   ├── Google Fonts (Bebas Neue + DM Sans) via @import
│   ├── CSS embutido com custom properties (--accent, --bg, --card, ...)
│   └── Firebase SDK (app-compat, auth-compat, database-compat) via CDN
├── <body>
│   ├── <header>       título, data e botão ☰ que abre o menu (editar/login/Strava)
│   ├── #hdr-menu      menu suspenso com Editar, Entrar e Strava
│   ├── #edit-banner   banner visível apenas no modo de edição
│   ├── #tabs          abas A–F
│   ├── #panels        painéis de cada treino (pré-renderizados no HTML)
│   └── footer-note    instrução de uso no rodapé
└── <script>
    ├── TREINOS_DATA        objeto com os 6 treinos (hardcoded)
    ├── treinos             deep clone mutável de TREINOS_DATA
    ├── cargas/historico/sessoes  carga por exercício, evolução e resumo Strava
    ├── Firebase init       config + auth + db (Realtime Database)
    ├── handleAuth          login/logout com Google via popup
    ├── loadFromFirebase    carrega treinos/cargas/historico/sessoes e reconstrói painéis
    ├── saveToCloud         escreve treinos em /users/{uid}/treinos
    ├── saveCargas/Historico/Sessoes  escrevem em /users/{uid}/cargas, /historico, /sessoes
    ├── handleStrava/handleStravaCallback  inicia OAuth e processa o retorno do Strava
    ├── toggleHdrMenu       abre/fecha o menu ☰ do header
    ├── buildAll/Panel      renderizam os painéis dinamicamente
    ├── shortDesc           extrai só a descrição do label do treino (sem repetir o nome)
    ├── makeExItem          cria o elemento DOM de cada exercício (com input de carga)
    ├── toggleEditMode      alterna modo uso ↔ edição (salva ao sair)
    ├── startSession        liga a sessão guiada (destaca o próximo exercício)
    ├── updateSessionHighlight  aplica/move a classe .current entre exercícios
    ├── quickCompleteEx     confirma o exercício em destaque (só ele é clicável)
    ├── logHistorico        grava um ponto de histórico ao confirmar um exercício
    ├── loadDone/saveDone   leem/escrevem localStorage (progresso diário)
    └── initDrag            drag-and-drop para reordenação (mouse + touch)

api/  (functions serverless, publicadas na Vercel — ver CLAUDE.md)
├── strava-exchange.js       troca o code do OAuth por tokens, grava no Firebase
└── strava-nightly-sync.js   roda 1x/dia (Vercel Cron), sincroniza o treino do dia anterior
```

---

## Arquivos do repositório

| Arquivo | Descrição |
|---|---|
| `index.html` | O app completo |
| `manifest.json` | Manifesto PWA (nome, ícones, cor de tema, modo standalone) |
| `sw.js` | Service worker — cache offline e atualização em background |
| `icon-192.png` | Ícone PWA 192×192 |
| `icon-512.png` | Ícone PWA 512×512 |
| `api/strava-exchange.js` | Function (Vercel) — troca o code do OAuth do Strava por tokens |
| `api/strava-nightly-sync.js` | Function (Vercel) — sincronização noturna via Vercel Cron |
| `vercel.json` | Configuração do Vercel Cron |
| `package.json` | Dependência (`firebase-admin`) usada pelas functions da Vercel |
| `validate.ps1` | Script PowerShell de validação estrutural do HTML |
| `validate.snapshot.json` | Snapshot da contagem esperada de exercícios |
| `CLAUDE.md` | Instruções e contexto para o assistente de IA (Claude Code) |
| `README.md` | Este arquivo |
