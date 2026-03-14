# Arbol — Recursive Planning Primitive

## The Problem

Frameworks de planejamento para agentes de código impõem taxonomias rígidas com lifecycles fixos. Na prática: planos quebram no contato com a realidade, hierarquias são arbitrárias, e artefatos ficam stale entre sessões.

**Condição de sucesso:** uma única operação recursiva que funciona identicamente em qualquer escala, de "criar um app" a "implementar essa função", onde o plano nunca fica stale porque não existe plano — existe só o próximo predicado.

---

## A Primitiva

### Operação fundamental

```
dado um OBJETIVO:
  1. extrair o verdadeiro objetivo (pode não ser o que foi pedido)
  2. definir o PRÓXIMO PREDICADO — o maior objetivo que temos confiança
     de progredir pro pai E que o executor consegue satisfazer
  3. decidir: EXECUTAR (satisfazer diretamente) ou SUBDIVIDIR (gerar predicados filhos)?
  4. se executar → validar predicado → voltar a 2 com estado atualizado
  5. se subdividir → aplicar esta mesma operação ao primeiro predicado filho
```

A operação é fractal — auto-similar em qualquer escala. Mesma estrutura, diferentes constantes de tempo.

### Árvore de predicados, não de tarefas

**O agente não define passos atômicos — define predicados atômicos.** A árvore inteira é uma árvore de predicados falsificáveis. Ações emergem dos predicados: "o que preciso fazer pra tornar este predicado verdadeiro?"

```
Predicado raiz: "ciclistas em SP conseguem ver ciclofaixas em tempo real no celular"
  └─ Predicado filho 1: "dados de ciclofaixas da CET estão acessíveis via API"
      └─ Predicado atômico: "endpoint /api/lanes retorna GeoJSON válido"
  └─ Predicado filho 2: "mapa renderiza com camada de ciclofaixas"
  └─ Predicado filho 3: "app funciona offline no celular"
```

### Definição do predicado

> O maior objetivo que temos confiança de progredir para o objetivo pai E que o agente é capaz de executar como unidade contínua de trabalho.

Dois eixos governam o tamanho:
- **Confiança** — certeza de que satisfazer este predicado progride pro pai
- **Capacidade** — o executor consegue satisfazê-lo diretamente

Dial conservador/agressivo: predicados menores = mais checkpoints, mais custo, mais segurança. Predicados maiores = menos checkpoints, menos custo, mais risco.

### Closure property

Cada nível da árvore herda o mesmo tipo (predicado falsificável). Satisfação do filho contribui pra satisfação do pai. A álgebra é fechada por construção — não precisa de mecanismo extra de composição.

---

## Extração do objetivo

A etapa mais crítica. O agente investe energia máxima em:
1. Descobrir o objetivo real por trás do pedido (Socratic extraction)
2. Antecipar o "cair na real" — quando o humano vai descobrir que queria outra coisa
3. Tornar o objetivo falsificável — condição concreta que prova que foi atingido

Sem objetivo claro → predicado não funciona → recursão não tem caso base → divergência.

### Janela de abstração

O objetivo tem um nível ótimo de abstração:

- **Muito abstrato** ("facilitar mobilidade urbana") → zero poder discriminatório. Todo passo "serve". No limite, "ser feliz" é o objetivo de todo humano — mas não funciona como predicado.
- **Zona útil** ("app que mostra ciclofaixas em tempo real pra ciclistas urbanos de SP") → rejeita passos irrelevantes, sobrevive a mudanças de implementação.
- **Muito concreto** ("PWA com Mapbox GL + layer da CET") → plano rígido disfarçado de objetivo. Não sobrevive a mudança de premissa.

A zona útil é onde o objetivo tem **máximo poder de discriminação**. Na teoria da informação: o nível com maior entropia condicional útil.

### Resiliência a mutação

O sistema é reativo, não contratual. Se o objetivo muda:
- Não há plano para invalidar
- O próximo predicado já reflete o objetivo novo
- Galhos da árvore podem ser podados, backtrack é natural
- Zero inércia

Estruturalmente idêntico ao MPC (Model Predictive Control): planeja N passos, commita 1, observa, replanteia.

---

## Humano na arquitetura

O humano é parte da primitiva, não obstáculo. Checkpoints quando:
- O objetivo pode ter mudado (humano aprendeu algo)
- Reversibilidade é baixa (decisão consequencial)
- Certeza é insuficiente (agente não consegue determinar o próximo predicado)

---

## Caso base: Ralph Loop

Quando o predicado é atômico, a execução é um Ralph Loop: agente executa, verificação externa (testes, build, humano), commit ou revert, repete. Flat, constraint-driven, sem hierarquia.

---

## Delegação por capacidade

- **Opus** nos níveis altos: predicados abstratos, decisões de arquitetura, extração de objetivo
- **Sonnet** nos níveis médios: predicados técnicos, implementação com contexto
- **Haiku** nos níveis baixos: predicados atômicos, execução direta

Critério de delegação: "quem consegue satisfazer este predicado?"

---

## Persistência

A árvore de predicados é a representação persistente em disco. Cada nó: predicado (condição falsificável), status (satisfeito/pendente/podado), filhos.

Não existe "plano" separado. A árvore é o plano, o log e o estado. Uma sessão nova lê a árvore, encontra o próximo predicado pendente, e continua.

---

## Fundamentação teórica

### Convergência de 7 campos

| Campo | Primitiva | Critério de subdivisão |
|---|---|---|
| AI Planning (HTN) | Task decomposition | Type check: primitivo ou composto |
| Reinforcement Learning (Options) | Option ⟨I, π, β⟩ | Função β aprendida (termination condition) |
| Teoria de Controle (MPC) | Receding horizon | Horizonte = constante de tempo dominante |
| Teoria da Informação (MDL) | Partition | ΔH < custo de representar subdivisão |
| CS teórico (Y combinator) | Fixed-point | Predicado no argumento, não profundidade |
| Category Theory (F-algebras) | Initial algebra | Mesmo morfismo em todo nível (catamorphism) |
| Estruturas espaciais (Quadtree) | Adaptive subdivision | Heterogeneidade interna da célula |

### Trabalhos relacionados

- **ADaPT** (Allen AI, NAACL 2024) — tenta executar → falha → decompõe → repete. +28% benchmarks. Mais próximo, mas sem HITL e com predicado binário.
- **HyperTree Planning** (ICML 2025) — divide-and-conquer hierárquico, 3.6x vs o1-preview
- **LADDER** (2025) — recursão que gera variantes mais fáceis, bootstraps upward
- **"Learning When to Plan"** (2025) — frequência ótima de planning é task-dependent
- **Option-Critic** (Bacon 2017) — terminação pode ser aprendida end-to-end
- **Ralph Loop** (Huntley 2025) — loop flat com verificação externa = caso base da recursão
- **Autoresearch** (Karpathy 2026) — loop flat com constraints rígidos = validação do caso base

### Insights matemáticos

**Terminação é predicado, não profundidade.** A primitiva precisa de um único parâmetro: o predicado de atomicidade. Profundidade, branching factor, total de passos são consequência.

**Dimensão fractal como consistency check.** Se a primitiva é auto-similar, o ratio sub-objetivos/passo deve ser ~constante. Desvio indica regra de decomposição não-uniforme.

**Analogia com a teoria de tudo na física.** A primitiva unifica o planning, mas a complexidade não desaparece — migra para a extração e calibração do objetivo. O framework fica simples; o trabalho difícil muda de lugar.

---

## Risks resolvidos

| Risk | Resolução |
|---|---|
| Fundamento teórico | Convergência de 7+ campos independentes |
| Implementação similar | ADaPT é o mais próximo, sem HITL/predicado gradual |
| Caso base funciona? | Ralph Loop + Autoresearch validam empiricamente |
| Calibração do agente | Aceito v1: confiar no agente, feedback loops naturais |
| Closure property | Resolvido pelo design: árvore de predicados, álgebra fechada |
| Custo | Otimização via dial conservador/agressivo + delegação de modelos |
| Persistência | Árvore de predicados em disco é a source of truth |

## Próximos passos (implementação)

- Formato concreto da árvore em disco
- UX de visualização pro humano
- Heurísticas de delegação por modelo
- Integração com git, testes, CI
- Primeiro protótipo: uma skill que opera com a primitiva
