# Meu Treino

App pessoal de acompanhamento de treinos de musculação. Hoje é um único arquivo HTML
autocontido (`meu_treino.html`) com HTML + CSS + JavaScript embutidos, sem build step
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

Histórico de execuções é salvo por exercício individual no `localStorage`, com chave
`hist_{treino}_{grupoIndex}_{exercicioIndex}`, contendo um array de sessões
(data + séries executadas com peso/reps reais). Progresso "feito hoje" é salvo
separadamente com chave `done_{treino}_{data-do-dia}`.

## Funcionalidades existentes
- 6 treinos (A–F) organizados por grupo muscular, navegáveis por abas.
- Marcar exercício/série como concluído, com barra de progresso por treino.
- Modo de edição: renomear exercícios/grupos, ajustar séries×reps, reordenar via
  drag-and-drop (mouse e touch), adicionar/remover exercícios e grupos.
- Histórico por exercício: calendário de sessões e gráfico de evolução (carga, volume).
- Cálculo de tendência (progressão/estagnação/regressão) comparando sessões.
- Botão "Download" que serializa o estado atual de `treinos` de volta no HTML e baixa
  um novo arquivo — essa é a forma atual de "salvar" mudanças permanentemente.
- Botão de "análise por IA" que monta um prompt com o histórico do exercício e chama
  a API da Anthropic para sugestões de progressão.

## ⚠️ Atenção: chamada de IA precisa de backend
O código hoje faz `fetch` direto para `https://api.anthropic.com/v1/messages` sem
nenhuma chave de API no client. Isso só funciona dentro do ambiente do Claude.ai
(artifacts), que injeta a autenticação por trás dos panos. **Fora desse ambiente essa
chamada falha**, e não se deve colocar uma API key direto no código client-side de um
app real (qualquer pessoa que abrir o site consegue roubá-la).
Quando formos evoluir esse recurso para funcionar fora do Claude.ai, a chamada de IA
precisa passar por um backend simples (serverless function ou servidor pequeno) que
guarda a chave em segredo. Não mexer nisso sem alinhar a abordagem antes.

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

## Comandos
Não há build/test automatizado ainda — é um único arquivo HTML aberto direto no
navegador. Para visualizar mudanças, basta abrir `meu_treino.html` no navegador
(ou usar a extensão "Live Server" / similar para auto-reload).
