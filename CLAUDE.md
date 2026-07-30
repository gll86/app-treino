# Meu Treino

App pessoal de acompanhamento de treinos de musculação. Único arquivo HTML
autocontido (`index.html`) com HTML + CSS + JavaScript embutidos, sem build step.
Roda 100% no navegador, com sync entre dispositivos via Firebase.

## Stack atual
- HTML/CSS/JS puro (vanilla), tudo em um arquivo único.
- Fonte: Google Fonts (Bebas Neue + DM Sans), importada via `@import` no CSS.
- Persistência local: `localStorage` do navegador.
- Sync entre dispositivos: Firebase Realtime Database + Google Authentication (CDN compat v10).
- Sem framework JS, sem bundler.
- Back-end mínimo na Vercel (`/api`, Node.js) só para a integração com Strava —
  ver seção "Integração Garmin → Strava" abaixo.

## Estrutura de dados
Os treinos ficam num objeto `TREINOS_DATA` (JS, hardcoded no arquivo), com a forma:
```js
{
  "A": {
    label: "PUSH — Peito, Ombros e Tríceps",
    grupos: [
      { nome: "Peito", exercicios: [{ nome: "Supino inclinado com halteres", series: 4, reps: 8 }, ...] },
      ...
    ]
  },
  "B": { ... }, ... até "D"
}
```
Em runtime, isso é copiado para a variável `treinos` (deep clone de `TREINOS_DATA`),
que é o estado mutável da sessão atual.

Progresso "feito hoje" é salvo no `localStorage` com chave `done_{treino}_{data-do-dia}`
(permanece por dispositivo — não sincroniza entre celular e notebook). O mesmo vale
para o estado da sessão guiada, em `session_{treino}_{data-do-dia}`.

Edições de treinos (`treinos`) são salvas em:
- `localStorage` com chave `treinos_saved` (cache local imediato)
- Firebase Realtime Database em `/users/{uid}/treinos` (sync entre dispositivos)

**IMPORTANTE — sempre que o `TREINOS_DATA` hardcoded mudar de forma intencional**
(troca de plano de treino, não edição feita pelo usuário via UI), incrementar
`TREINOS_VERSION` (perto do `STORAGE_KEY`, no `<script>`). O app carrega
`treinos` do `localStorage`/Firebase antes do `TREINOS_DATA` do código — sem
esse bump, quem já usou o app antes continua vendo o plano antigo (cache local
e nuvem têm prioridade). O bump força um reset local único e reenvia o plano
novo pro Firebase na próxima sincronização, sobrescrevendo a versão antiga na
nuvem. Isso também **apaga qualquer edição manual** que o usuário tenha feito
nos treinos antes do bump — é o comportamento esperado numa troca de plano,
mas vale avisar o usuário antes.

Carga (peso) por exercício e histórico de evolução seguem o mesmo padrão, com
identificação pelo **nome do exercício** (não há sistema de IDs no app — renomear um
exercício "perde" o histórico associado ao nome antigo):
```js
cargas["A"]["Supino inclinado com halteres"]      // número (kg), último valor
historico["A"]["Supino inclinado com halteres"]   // [{data:'YYYY-MM-DD', carga}, ...]
```
- `localStorage`: `cargas_saved` e `historico_saved`
- Firebase: `/users/{uid}/cargas` e `/users/{uid}/historico`

Resumo de sessão de treino vindo do Garmin/Strava (duração, FC, calorias), plano por
**data** (não por treino — só existe um treino por dia no ciclo atual):
```js
sessoes["2026-07-29"]   // {duracaoMin, fcMedia, fcMax, calorias, stravaId}
```
- `localStorage`: `sessoes_saved`
- Firebase: `/users/{uid}/sessoes`
- Preenchido automaticamente pela sincronização noturna (ver seção "Integração
  Garmin → Strava") — o app só lê, nunca escreve esse dado diretamente.
- Ainda **sem UI própria** para exibir isso no app — só persistência por enquanto,
  UI é uma decisão em aberto (não adicionar tela/exibição sem alinhar antes).

## Funcionalidades existentes
- 4 treinos (A–D) organizados por grupo muscular, navegáveis por abas: ciclo
  infinito 3 ON / 1 OFF — Push, Pull, Legs & Core, Cardio (dia de folga, sem
  variação B; os 4 dias se repetem em sequência continuamente).
- Input de carga (kg) por exercício, sempre recarregando o último valor salvo.
- Sessão guiada obrigatória: botão "▶ Iniciar treino" destaca o próximo exercício
  pendente (borda, sombra, tag "AGORA"); só ele responde ao toque, e confirmar avança
  automaticamente para o seguinte, registrando um ponto de histórico se houver carga
  preenchida. Não existe mais marcação livre fora de ordem — é o fluxo obrigatório.
  Durante a sessão o botão vira "■ Encerrar treino": aborta e reseta o progresso do
  dia sem gravar nada (mesma ação do ↺ de reset).
- Barra de progresso por treino, com tela de "TREINO CONCLUÍDO!" ao final.
- Modo de edição: renomear exercícios/grupos, ajustar séries, reordenar via
  drag-and-drop (mouse e touch), adicionar/remover exercícios e grupos.
- Botão "✅ Salvar alterações" salva edições no localStorage e no Firebase.
- Header compacto: só título, data e um botão "☰" que abre um menu suspenso
  (canto superior direito) com "✏️ Editar", "☁ Entrar" e "🔗 Strava" — evita quebra
  de layout em telas estreitas (o menu fecha ao clicar fora ou em qualquer opção).
- "☁ Entrar": login com Google via popup; quando logado mostra o nome do usuário e
  sincroniza treinos, cargas, histórico e sessões do Firebase automaticamente.
- "🔗 Strava": só aparece logado no Google. Inicia OAuth com o Strava pra permitir a
  sincronização noturna de dados do Garmin — ver "Integração Garmin → Strava".

## Integração Garmin → Strava

O usuário treina com o Garmin (perfil "Strength Training", sem registrar séries —
só duração/FC/calorias). A Garmin não tem API pública pra pessoa física, então o
caminho é: Garmin sincroniza nativamente com o Strava (feito uma vez, nas
configurações de cada conta), e o app usa a API do Strava pra puxar esses dados.
Precisa de assinatura Strava paga pra liberar a API (mudança de política deles).

Arquitetura (duas hospedagens a partir do mesmo repo):
- **GitHub Pages** continua servindo só o `index.html`, sem mudança nenhuma no deploy.
- **Vercel** (projeto `app-treino`, time `GLL`, domínio de produção
  `app-treino-wine.vercel.app`) serve as functions em `/api`, conectada ao mesmo
  repo GitHub — todo `git push` faz deploy automático lá também.

Fluxo:
1. Botão "🔗 Strava" no menu do header inicia OAuth (`STRAVA_CLIENT_ID` é público,
   hardcoded no `index.html` igual ao `firebaseConfig`).
2. `api/strava-exchange.js` troca o `code` do OAuth por tokens e grava em
   `/users/{uid}/strava_auth` via Firebase Admin SDK — o client nunca vê esse token.
3. `api/strava-nightly-sync.js` roda 1x/dia via **Vercel Cron** (`vercel.json`,
   ~6h da manhã BRT), autenticado por `CRON_SECRET`. Renova o token se necessário,
   busca a atividade tipo `WeightTraining` do dia anterior no Strava, e grava o
   resumo em `/users/{uid}/sessoes/{data}`. Aceita `?date=YYYY-MM-DD` opcional pra
   rodar manualmente num dia específico (backfill ou teste), fora do agendamento.

Variáveis de ambiente (painel da Vercel → projeto → Environments):
`STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `FIREBASE_SERVICE_ACCOUNT_KEY`,
`FIREBASE_DATABASE_URL`, `CRON_SECRET`.

**IMPORTANTE — não marcar essas variáveis como "Sensitive" na Vercel.** Foi
observado nesse projeto que variáveis marcadas "Sensitive" simplesmente não chegam
em `process.env` das functions (mesmo corretamente configuradas para "Production"),
sem erro nenhum — silenciosamente `undefined`. Provável bug/particularidade da
Vercel nesse projeto/plano. Todas as 5 variáveis acima foram recriadas sem o toggle
"Sensitive" pra funcionar. Se precisar recriar alguma no futuro, manter assim.

## Deploy
- Repositório público: https://github.com/gll86/app-treino
- App publicado via GitHub Pages: https://gll86.github.io/app-treino
- Back-end (`/api`) publicado via Vercel: https://app-treino-wine.vercel.app
- Fluxo para atualizar o celular: editar `index.html` no notebook → `git push` → aguardar ~1 min → recarregar no celular

## Convenções de código observadas no arquivo atual
- Nomes de variáveis e funções em português/inglês misturado (ex: `treinos`,
  `buildPanel`, `currentTab`) — manter o padrão existente em vez de forçar
  padronização agressiva, a menos que seja pedido explicitamente.
- Funções pequenas e diretas, sem classes; tudo em escopo global de `<script>`.
- CSS usa custom properties (`--accent`, `--bg`, etc.) definidas em `:root` — reusar
  essas variáveis em vez de cores hardcoded ao adicionar novos estilos.
- Tema escuro fixo (sem alternância dark/light).

## O que NÃO fazer sem perguntar antes
- Não reescrever o app inteiro num framework (React, Vue etc.) sem alinhamento —
  qualquer migração de stack é uma decisão grande, não uma "melhoria" pontual.
- Não remover ou substituir o Firebase sem definir alternativa de sync entre dispositivos.
- Não comitar nenhuma API key real no código ou no histórico do git.
  (Nota: a `apiKey` do Firebase no `index.html` é pública por design — o Firebase
  usa regras de segurança e domínios autorizados para proteção, não segredo da key.)
- Segredos da integração Strava (`STRAVA_CLIENT_SECRET`, `FIREBASE_SERVICE_ACCOUNT_KEY`,
  `CRON_SECRET`) só existem como variáveis de ambiente na Vercel — nunca digitar ou
  colar esses valores em código, chat, ou qualquer lugar fora do painel da Vercel.
- Não adicionar UI pra exibir os dados de `sessoes` (duração/FC/calorias do Strava)
  sem alinhar antes — é uma decisão de design em aberto, discutida mas não decidida.

## Pipeline de desenvolvimento
Todo change segue esta ordem obrigatória:
1. **Editar** `index.html`
2. **Validar** — `powershell -ExecutionPolicy Bypass -File validate.ps1`
   - Se a contagem de exercícios mudou intencionalmente: rodar com `-Update` primeiro
   - Só prosseguir se todos os checks passarem
3. **Commitar** — propor commit ao usuário
4. **Push** — só após aprovação do usuário
5. **Atualizar documentação** — se a mudança afetou funcionalidade, atualizar
   `README.md` e este `CLAUDE.md`, commitar e pushar

## Comandos
Para visualizar mudanças localmente: abrir `index.html` no navegador (ou usar a
extensão "Live Server" / similar para auto-reload).

URL do app: https://gll86.github.io/app-treino
