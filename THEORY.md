# Arbol — Recursive Planning Primitive

## The Problem

Frameworks de planejamento para agentes de código impõem taxonomias rígidas com lifecycles fixos. Na prática: planos quebram no contato com a realidade, hierarquias são arbitrárias, e artefatos ficam stale entre sessões.

O Launchpad (framework anterior) impunha mission → stage → module com lifecycle discovery → planning → delivery → review → ship. Funcionava, mas a hierarquia era arbitrária e o plano era contrato que não se adaptava.

**Condição de sucesso:** uma única operação recursiva que funciona identicamente em qualquer escala, de "criar um app" a "implementar essa função", onde o plano nunca fica stale porque não existe plano — existe só o próximo predicado.

---

## A Primitiva

### Operação fundamental

```
// ponto de entrada
predicado_raiz ← extrair_objetivo(humano)  // pré-condição, não parte da primitiva
arbol(predicado_raiz)

arbol(predicado):
  se inatingível(predicado):
    podar(predicado)
    retorna podado

  senão se try_consegue_satisfazer(predicado):
    try(predicado)
    humano valida → satisfeito | arbol(predicado)

  senão se ciclo_consegue_satisfazer(predicado):
    ciclo(predicado)  // discovery → delivery → review → ship
    humano valida → satisfeito | arbol(predicado)

  senão:
    // escolhe o sub-predicado que, satisfeito, mais reduz a incerteza
    // sobre como satisfazer o pai — não o mais fácil, nem o mais
    // importante, mas o que mais clarifica o caminho
    filho ← propor sub-predicado
    humano valida proposta:
      se aceita → arbol(filho), depois arbol(predicado)
      se rejeita → arbol(predicado)  // propõe outro filho
```

A operação é fractal — auto-similar em qualquer escala. Mesma estrutura, diferentes constantes de tempo.

A árvore cresce lazy — um filho por vez. Depois de satisfazer um filho, o pai é re-avaliado: talvez já seja satisfazível, talvez precise de outro filho. A re-avaliação decide.

### Árvore de predicados, não de tarefas

**O agente não define passos atômicos — define predicados atômicos.** A árvore inteira é uma árvore de predicados falsificáveis. Ações emergem dos predicados: "o que preciso fazer pra tornar este predicado verdadeiro?"

```
Predicado raiz: "ciclistas em SP conseguem ver ciclofaixas em tempo real no celular"
  └─ Predicado filho 1: "dados de ciclofaixas da CET estão acessíveis via API"
      └─ Predicado atômico: "endpoint /api/lanes retorna GeoJSON válido"
  └─ Predicado filho 2: "mapa renderiza com camada de ciclofaixas"
  └─ Predicado filho 3: "app funciona offline no celular"
```

### Closure property

Cada nível da árvore herda o mesmo tipo (predicado falsificável). Satisfação do filho contribui pra satisfação do pai. A álgebra é fechada por construção — não precisa de mecanismo extra de composição.

---

## Extração do objetivo

Pré-condição da primitiva, não parte dela. Antes da primeira chamada `arbol()`, o agente investe energia máxima em:
1. Descobrir o objetivo real por trás do pedido (Socratic extraction)
2. Antecipar o "cair na real" — quando o humano vai descobrir que queria outra coisa
3. Tornar o objetivo falsificável — condição concreta que prova que foi atingido

Sem objetivo claro → predicado não funciona → recursão não tem caso base → divergência (= AutoGPT).

### Janela de abstração

O objetivo tem um nível ótimo de abstração:

- **Muito abstrato** ("facilitar mobilidade urbana") → zero poder discriminatório. Todo passo "serve". No limite, "ser feliz" é o objetivo de todo humano — mas não funciona como predicado.
- **Zona útil** ("app que mostra ciclofaixas em tempo real pra ciclistas urbanos de SP") → rejeita passos irrelevantes, sobrevive a mudanças de implementação.
- **Muito concreto** ("PWA com Mapbox GL + layer da CET") → plano rígido disfarçado de objetivo. Não sobrevive a mudança de premissa.

A zona útil é onde o objetivo tem **máximo poder de discriminação**. Na teoria da informação: o nível com maior entropia condicional útil. Teste: se toda a stack mudar, o predicado ainda faz sentido?

### Resiliência a mutação

O sistema é reativo, não contratual. Se o objetivo raiz muda:
- Cria-se um novo nó raiz na árvore
- A árvore anterior persiste como histórico
- A recursão recomeça do novo raiz
- Nada se perde, e a profundidade se corrige

Estruturalmente idêntico ao MPC (Model Predictive Control): planeja N passos, commita 1, observa, replanteia.

---

## Validação humana

O humano é parte da primitiva, não obstáculo. Valida em dois momentos:
- **Proposta:** o agente propõe um predicado, humano confirma que faz sentido e progride na direção correta
- **Resultado:** o agente conclui que satisfez o predicado, humano confirma que foi de fato satisfeito

Rejeição na proposta → agente propõe outro predicado. Rejeição no resultado → agente refaz a execução. Não são casos especiais — são re-avaliações naturais da primitiva.

Quando o agente reconhece que um predicado é inatingível, ele poda o nó. Isso força re-avaliação no pai e geração de outro caminho.

---

## Dois modos de execução

O caso base tem dois modos, e o agente decide qual:
- **Try:** predicados triviais. Implementa, valida, aprova ou descarta.
- **Ciclo completo:** predicados complexos. Discovery → delivery → review → ship.

O ciclo do Launchpad sobrevive como motor de execução no caso base. Arbol substitui a camada de planejamento/hierarquia (mission/stage/module), mas o ciclo de execução (discovery → delivery → review → ship) é a unidade atômica de trabalho para predicados complexos.

Paralelismo (múltiplos subagentes) é estratégia interna do ciclo — aumenta a capacidade de satisfazer predicados maiores. Do ponto de vista da árvore, continua sendo um nó, um predicado, um resultado.

---

## Persistência

A árvore de predicados é a representação persistente em disco. Cada nó: predicado (condição falsificável), status (pendente | satisfeito | podado), filhos.

Não existe "plano" separado. A árvore é o plano, o log e o estado. Existe sempre um e apenas um nó ativo — o predicado sendo trabalhado. Uma sessão nova lê a árvore, encontra o nó ativo, e continua. É o estado completo da sessão.

Delegação muda o executor do nó, não cria nós paralelos.

---

## Delegação por capacidade

- **Opus** nos níveis altos: predicados abstratos, decisões de arquitetura, extração de objetivo
- **Sonnet** nos níveis médios: predicados técnicos, implementação com contexto
- **Haiku** nos níveis baixos: predicados atômicos, execução direta

Critério de delegação: "quem consegue satisfazer este predicado?" É o único critério.

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
