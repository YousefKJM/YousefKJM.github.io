---
title: "AI Search, Explained Through Pac-Man: BFS to A* to Q-Learning"
excerpt: "One generic search function, four data structures, four algorithms. Plus heuristics that don't lie, adversarial search for the ghosts, and the Q-learning update in one line — the AI fundamentals from a Pac-Man agent project, as a reference you'll reuse."
---

One of my favorite university projects (team of four) was building agents for Pac-Man: navigate the maze, eat food efficiently, survive the ghosts. It's the cleanest possible tour of classical AI — search, heuristics, adversarial reasoning, and reinforcement learning, all in one game.

## The big idea: every search is the same loop

The only thing that changes between BFS, DFS, UCS and A* is **which frontier node you expand next.** Swap the data structure, get a different algorithm.

```python
def graph_search(problem, frontier):
    frontier.push((problem.start, [], 0))           # (state, path, cost so far)
    explored = set()
    while not frontier.is_empty():
        state, path, cost = frontier.pop()
        if problem.is_goal(state):
            return path
        if state in explored:
            continue
        explored.add(state)
        for nxt, action, step in problem.successors(state):
            if nxt not in explored:
                frontier.push((nxt, path + [action], cost + step))
    return None
```

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Four algorithms, four frontiers: DFS uses a stack, BFS a queue, UCS a priority queue on path cost g, A star a priority queue on g plus heuristic h">
  <g style="font-size:13px;">
    <rect x="10" y="10" width="145" height="210" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="36" font-weight="700" fill="var(--text)">DFS</text>
    <text x="24" y="58" fill="var(--accent)" font-weight="700">Stack (LIFO)</text>
    <text x="24" y="90" fill="var(--text-muted)">dives deep first</text>
    <text x="24" y="112" fill="var(--text-muted)">low memory</text>
    <text x="24" y="134" fill="var(--text-muted)">❌ not optimal</text>
    <text x="24" y="156" fill="var(--text-muted)">❌ can loop forever</text>
    <text x="24" y="190" fill="var(--text)">Pac-Man: weird,</text>
    <text x="24" y="208" fill="var(--text)">winding paths</text>

    <rect x="168" y="10" width="145" height="210" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="182" y="36" font-weight="700" fill="var(--text)">BFS</text>
    <text x="182" y="58" fill="var(--accent)" font-weight="700">Queue (FIFO)</text>
    <text x="182" y="90" fill="var(--text-muted)">level by level</text>
    <text x="182" y="112" fill="var(--text-muted)">✅ fewest steps</text>
    <text x="182" y="134" fill="var(--text-muted)">❌ ignores step cost</text>
    <text x="182" y="156" fill="var(--text-muted)">memory-hungry</text>
    <text x="182" y="190" fill="var(--text)">Pac-Man: shortest</text>
    <text x="182" y="208" fill="var(--text)">path, uniform cost</text>

    <rect x="326" y="10" width="145" height="210" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="340" y="36" font-weight="700" fill="var(--text)">UCS</text>
    <text x="340" y="58" fill="var(--accent)" font-weight="700">PQ by g(n)</text>
    <text x="340" y="90" fill="var(--text-muted)">cheapest so far</text>
    <text x="340" y="112" fill="var(--text-muted)">✅ optimal cost</text>
    <text x="340" y="134" fill="var(--text-muted)">explores in rings</text>
    <text x="340" y="156" fill="var(--text-muted)">= Dijkstra</text>
    <text x="340" y="190" fill="var(--text)">Pac-Man: avoids</text>
    <text x="340" y="208" fill="var(--text)">costly ghost zones</text>

    <rect x="484" y="10" width="146" height="210" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="498" y="36" font-weight="700" fill="var(--accent)">A*</text>
    <text x="498" y="58" fill="var(--accent)" font-weight="700">PQ by g(n)+h(n)</text>
    <text x="498" y="90" fill="var(--text-muted)">cost + estimate</text>
    <text x="498" y="112" fill="var(--text-muted)">✅ optimal if h</text>
    <text x="498" y="134" fill="var(--text-muted)">is admissible</text>
    <text x="498" y="156" fill="var(--text-muted)">far fewer expansions</text>
    <text x="498" y="190" fill="var(--text)">Pac-Man: same path</text>
    <text x="498" y="208" fill="var(--text)">as UCS, much faster</text>
  </g>
</svg>
</div>

```python
dfs   = lambda p: graph_search(p, Stack())
bfs   = lambda p: graph_search(p, Queue())
ucs   = lambda p: graph_search(p, PriorityQueueWithFunction(lambda n: n[2]))
astar = lambda p, h: graph_search(p, PriorityQueueWithFunction(lambda n: n[2] + h(n[0], p)))
```

Four algorithms, one function. That's the whole insight.

## Heuristics: the part that's actually hard

A* is only as good as `h(n)`, your estimate of remaining cost.

| Property | Means | Guarantees |
|---|---|---|
| **Admissible** | Never overestimates: `h(n) ≤ true cost` | A* tree search is optimal |
| **Consistent** | `h(n) ≤ step(n→n') + h(n')` (triangle inequality) | A* graph search is optimal; nodes never need re-opening |
| `h = 0` | Trivially admissible | A* degenerates into UCS |

```python
def manhattan(state, problem):                     # admissible on a grid with no diagonal moves
    (x1, y1), (x2, y2) = state, problem.goal
    return abs(x1 - x2) + abs(y1 - y2)
```

**The food-eating trap:** "distance to the *nearest* dot" is admissible but weak. "Distance to the *farthest* dot" is still admissible (you must reach it eventually) and far stronger — it expands noticeably fewer nodes, and using true maze distance instead of Manhattan tightens it further. A good heuristic is the **tightest estimate that still never lies.**

## Adversarial search: when the ghosts fight back

Ghosts aren't a static maze — they move. Now you're searching a game tree.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 200" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Minimax tree: a max node for Pac-Man picks the highest of its min children; each min node for a ghost picks the lowest leaf score">
  <g style="font-size:13px;">
    <line x1="320" y1="40" x2="170" y2="100" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="40" x2="470" y2="100" stroke="var(--border)" stroke-width="2"/>
    <line x1="170" y1="100" x2="100" y2="160" stroke="var(--border)" stroke-width="2"/>
    <line x1="170" y1="100" x2="240" y2="160" stroke="var(--border)" stroke-width="2"/>
    <line x1="470" y1="100" x2="400" y2="160" stroke="var(--border)" stroke-width="2"/>
    <line x1="470" y1="100" x2="540" y2="160" stroke="var(--border)" stroke-width="2"/>
    <polygon points="320,18 342,50 298,50" fill="var(--accent)"/>
    <text x="352" y="42" font-weight="700" fill="var(--accent)">MAX (Pac-Man) = 3</text>
    <polygon points="148,88 192,88 170,120" fill="var(--bg-elevated-2)" stroke="var(--text)"/>
    <text x="60" y="108" fill="var(--text)">MIN = 3</text>
    <polygon points="448,88 492,88 470,120" fill="var(--bg-elevated-2)" stroke="var(--text)"/>
    <text x="500" y="108" fill="var(--text)">MIN = 2</text>
    <rect x="85" y="160" width="30" height="26" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="95" y="178" fill="var(--text)">3</text>
    <rect x="225" y="160" width="30" height="26" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="235" y="178" fill="var(--text)">8</text>
    <rect x="385" y="160" width="30" height="26" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="395" y="178" fill="var(--text)">2</text>
    <rect x="525" y="160" width="30" height="26" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="535" y="178" fill="var(--text)">9</text>
    <text x="560" y="178" fill="var(--text-muted)">← pruned</text>
  </g>
</svg>
</div>

```python
def minimax(state, depth, agent):
    if depth == 0 or state.is_terminal():
        return evaluate(state)
    nxt = (agent + 1) % state.num_agents
    d   = depth - 1 if nxt == 0 else depth            # one ply = everyone moves once
    scores = [minimax(state.after(agent, a), d, nxt) for a in state.legal_actions(agent)]
    return max(scores) if agent == 0 else min(scores) # Pac-Man maximizes, ghosts minimize
```

| Variant | Assumes ghosts… | Use it when |
|---|---|---|
| **Minimax** | Play perfectly against you | Worst-case safety |
| **Alpha-beta** | Same, but skips branches that can't change the answer | Always — same result, far fewer nodes (the `9` above is never evaluated: MIN already has a 2, and MAX already has a 3) |
| **Expectimax** | Move randomly; take the *average* | Real ghosts are dumb — minimax makes Pac-Man too scared to eat |

## Reinforcement learning: learning without a map

No model of the maze, no known rewards. Pac-Man plays, gets rewarded (+10 dot, +500 win, −500 caught), and learns a value for each state-action pair:

```python
# Q-learning update — the whole algorithm in one line
Q[s][a] += alpha * (reward + gamma * max(Q[s2].values()) - Q[s][a])
```

| Knob | Controls | Typical |
|---|---|---|
| `alpha` (learning rate) | How fast new experience overwrites old | 0.2–0.5 |
| `gamma` (discount) | How much future reward matters | 0.8–0.99 |
| `epsilon` (exploration) | Chance of a random move instead of the best known one | Start high, decay toward 0.05 |

Tabular Q-learning breaks on big mazes — too many states. **Approximate Q-learning** fixes it by learning weights over features (distance to nearest food, ghosts one step away, …) instead of a value for every state. That generalization step is the bridge from classic RL to deep RL.

## The one-page summary

- Search = one loop; **the frontier decides the algorithm.**
- A* = UCS + a heuristic. **Admissible = optimal. Tighter = faster.**
- Opponents → minimax; **always add alpha-beta**; use expectimax when opponents aren't optimal.
- No model → **Q-learning**; big state space → features.
