# Protocolo de design com Paper MCP

Referência para iterar no design do fractal viewer usando o Paper MCP. Usado durante
`/fractal:patch` ou `/fractal:delivery` quando o deliverable é UI.

---

## Ferramentas relevantes

| Ferramenta | Uso |
|---|---|
| `get_basic_info` | Entender estrutura do arquivo antes de modificar |
| `create_artboard` | Criar nova superfície de design |
| `write_html` | Adicionar conteúdo — um grupo visual por chamada, máx ~15 linhas |
| `get_screenshot` | Checkpoint visual — obrigatório a cada 2-3 modificações |
| `get_jsx` | Exportar estrutura do componente como código |
| `get_selection`, `get_tree_summary`, `get_children`, `get_node_info` | Explorar design existente |
| `get_computed_styles` | Extrair valores CSS precisos de elementos existentes |
| `update_styles`, `set_text_content` | Modificar elementos existentes |
| `duplicate_nodes` | Reutilizar padrões de forma eficiente |
| `finish_working_on_nodes` | **Obrigatório** ao terminar qualquer sessão de edição |

---

## Brief de design (antes de qualquer trabalho)

Gerar antes de abrir o Paper:

- **Paleta** — 5-6 hex com papéis definidos (background, surface, primary, muted, text, border)
- **Tipografia** — fonte, pesos, escala de tamanhos (body, label, heading, mono)
- **Ritmo de espaçamento** — gaps por nível: seção / grupo / elemento
- **Direção visual** — uma frase (ex: "terminal minimalista, alta densidade, sem ornamento")

---

## Estágios do workflow

### Estágio 1 — Wireframe

Objetivo: estrutura do layout no canvas, sem polish visual.

1. `create_artboard` com dimensões do viewport alvo
2. `write_html` — blocos estruturais (header, tree area, status bar, etc.) com cores neutras
3. `get_screenshot` — validar proporções e hierarquia antes de continuar

### Estágio 2 — Refinamento

Objetivo: tipografia, cores, espaçamento, polish visual.

1. `update_styles` para aplicar paleta e tipografia
2. `write_html` para adicionar detalhes visuais — uma região por chamada
3. `get_screenshot` a cada 2-3 modificações — nunca pular
4. `duplicate_nodes` para padrões repetidos (nodes, badges, separadores)

### Estágio 3 — Checkpoint de revisão

Executar o checklist abaixo a partir do último screenshot:

| Critério | Verificar |
|---|---|
| Espaçamento | Gaps uniformes, ritmo visual consistente |
| Tipografia | Tamanhos legíveis, hierarquia clara |
| Contraste | Legibilidade do texto, distinção entre elementos |
| Alinhamento | Eixos verticais e horizontais respeitados |
| Clipping | Nenhum conteúdo cortado ou escondido |
| Repetição | Variação de escala/peso/espaçamento — sem monotonia |

Se algum critério falhar: `update_styles` ou `write_html` para corrigir, depois novo screenshot.

### Estágio 4 — Gate humano

Apresentar screenshot ao humano com `AskUserQuestion`. Aguardar aprovação explícita da
direção visual antes de exportar. Não avançar com "parece ok" implícito.

### Estágio 5 — Exportação

1. `get_jsx` para extrair HTML do componente
2. Adaptar para uso no repo: inline styles, sem dependências externas
3. Verificar integração com `view.sh` e estrutura do fractal viewer
4. `finish_working_on_nodes` — obrigatório antes de fechar a sessão Paper

---

## Gates de saída

Antes de commitar o HTML no repo:

- [ ] Humano viu screenshot e aprovou direção visual
- [ ] Checkpoint de revisão passou nos 6 critérios
- [ ] HTML exportado é self-contained (inline styles, zero deps externos)
- [ ] HTML integra com `view.sh` / estrutura do fractal viewer existente

---

## Integração com o ciclo fractal

**Quando usar:** qualquer predicate leaf que envolva mudanças de UI/UX no viewer.

**Trigger:** durante `/fractal:patch` (mudança pontual) ou `/fractal:delivery` (sprint completo)
quando o deliverable é um arquivo HTML do viewer.

**Output:** arquivo HTML commitado no repo, referenciado no `results.md` do nó ativo.
