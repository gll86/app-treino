# Meu Treino

App pessoal de acompanhamento de treinos de musculação. Hoje é um único arquivo HTML
autocontido (`index.html`) com HTML + CSS + JavaScript embutidos, sem build step
e sem backend. Roda 100% no navegador.

## Stack atual
- HTML/CSS/JS puro (vanilla), tudo em um arquivo único.
- Fonte: Google Fonts (Bebas Neue + DM Sans), importada via `@import` no CSS.
- Persistência: `localStorage` do navegador (não há banco de dados nem servidor).
- Sem dependências externas de JS (nenhum framework, nenhum bundler).

## Estrutura de dados
Os treinos ficam num objeto `TREINOS_DATA` (JS, hardcoded no arquivo), com a forma:
```js
{
  "A": {
    label: "TREINO A — Peito + Tríceps",
    grupos: [
      { nome: "Peito", exercicios: [{ nome: "Supino reto", series: 4, reps: 12 }, ...] },
      ...
    ]
  },
  "B": { ... }, ... até "F"
}
```
Em runtime, isso é copiado para a variável `treinos` (deep clone de `TREINOS_DATA`),
que é o estado mutável da sessão atual.

Progresso "feito hoje" é salvo no `localStorage` com chave `done_{treino}_{data-do-dia}`.

## Funcionalidades existentes
- 6 treinos (A–F) organizados por grupo muscular, navegáveis por abas.
- Marcar exercício/série como concluído, com barra de progresso por treino.
- Modo de edição: renomear exercícios/grupos, ajustar séries×reps, reordenar via
  drag-and-drop (mouse e touch), adicionar/remover exercícios e grupos.
- Botão "Download" que serializa o estado atual de `treinos` de volta no HTML e baixa
  um novo arquivo (backup/exportação).

## Deploy
- Repositório público: https://github.com/gll86/app-treino
- App publicado via GitHub Pages: https://gll86.github.io/app-treino
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
- Não remover a função de download/exportação do HTML sem ter um substituto definido
  (é a única forma de persistência fora do localStorage hoje).
- Não comitar nenhuma API key real no código ou no histórico do git.

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
