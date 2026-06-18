# Meu Treino

App pessoal para acompanhamento de treinos de musculação. Roda 100% no navegador, sem servidor, sem banco de dados, sem instalação.

**→ [Abrir o app](https://gll86.github.io/app-treino)**

---

## O que é

Um app de academia que cabe num único arquivo HTML. Você abre no celular, marca os exercícios concluídos, e o progresso fica salvo localmente. Nada é enviado para nenhum servidor.

---

## Como funciona

### Stack intencional: zero dependências

O app é um único arquivo `index.html` com HTML, CSS e JavaScript embutidos. Sem React, sem Vue, sem bundler, sem `npm install`. Essa foi uma escolha deliberada:

- **Portabilidade total** — o arquivo funciona aberto direto no browser, sem servidor local
- **Sem ponto de falha externo** — não depende de CDN, de API, de nada que possa sair do ar
- **Simples de entender** — qualquer pessoa que sabe HTML/CSS/JS consegue ler e modificar

### Persistência sem banco de dados

O progresso do dia é salvo no `localStorage` do browser com a chave `done_{treino}_{data}`. Funciona offline, persiste entre sessões, e não precisa de conta ou login. A contrapartida: o progresso fica no dispositivo — não sincroniza entre celular e notebook.

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

### Editar sem backend

O modo de edição permite renomear exercícios e grupos, ajustar séries×reps, reordenar via drag-and-drop (funciona no touch também) e adicionar/remover itens — tudo em memória. Para salvar permanentemente, o botão "Download" serializa o estado atual de volta num novo `index.html` e baixa o arquivo.

---

## Deploy: do notebook ao celular sem WhatsApp

Antes, o fluxo era: editar o arquivo no notebook → enviar via WhatsApp → salvar no celular → abrir no Chrome. Funcionava, mas era chato.

A solução foi publicar via **GitHub Pages**: o repositório é público e o GitHub serve o `index.html` direto em `https://gll86.github.io/app-treino`. O celular acessa essa URL, e o `localStorage` persiste entre sessões porque a origem é sempre a mesma.

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

### Por que não usar um framework

A pergunta natural ao ver um app de interface interativa é "por que não React/Vue?". A resposta é custo-benefício: o app tem uma tela, sem roteamento, sem estado global complexo, sem server-side rendering, sem time trabalhando nele. Adicionar um framework significaria build step, `node_modules`, configuração de bundler e uma camada extra de abstração — tudo isso para resolver problemas que esse app não tem.

Vanilla JS com funções pequenas e diretas cobre 100% do que é necessário aqui.

### Por que arquivo único

Facilita o backup (um arquivo), facilita compartilhar (um arquivo), e o botão de "Download" consegue serializar o estado atual dos treinos de volta no próprio HTML — um mecanismo de exportação que só funciona porque tudo está num lugar só.

---

## Estrutura do arquivo

```
index.html
├── <head>
│   ├── Google Fonts (Bebas Neue + DM Sans) via @import
│   └── CSS embutido com custom properties (--accent, --bg, --card, ...)
├── <body>
│   ├── <header>       barra superior com título, botão editar e data
│   ├── #edit-banner   banner visível apenas no modo de edição
│   ├── #tabs          abas A–F
│   ├── #panels        painéis de cada treino (pré-renderizados no HTML)
│   └── footer-note    instrução de uso no rodapé
└── <script>
    ├── TREINOS_DATA      objeto com os 6 treinos (hardcoded)
    ├── treinos           deep clone mutável de TREINOS_DATA
    ├── buildAll/Panel    renderizam os painéis dinamicamente no carregamento
    ├── makeExItem        cria o elemento DOM de cada exercício
    ├── toggleEditMode    alterna modo uso ↔ edição
    ├── quickCompleteEx   marca/desmarca exercício como concluído
    ├── loadDone/saveDone leem/escrevem localStorage
    ├── initDrag          drag-and-drop para reordenação (mouse + touch)
    └── downloadFile      serializa estado atual → novo index.html para download
```

---

## Arquivos do repositório

| Arquivo | Descrição |
|---|---|
| `index.html` | O app completo |
| `validate.ps1` | Script PowerShell de validação estrutural do HTML |
| `validate.snapshot.json` | Snapshot da contagem esperada de exercícios |
| `CLAUDE.md` | Instruções e contexto para o assistente de IA (Claude Code) |
| `README.md` | Este arquivo |
