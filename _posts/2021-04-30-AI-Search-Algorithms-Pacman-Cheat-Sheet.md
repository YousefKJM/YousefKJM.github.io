---
title: "AI Search Algorithms Explained with Pac-Man"
excerpt: "DFS, BFS, UCS and A* are the same loop with a different frontier. A visual tour of classic AI search — plus heuristics, minimax and Q-learning — through the Pac-Man agents my team built."
header:
  image: /images/posts/ai-search/search_comparison.png
tags: [AI, search, algorithms, Python, game-AI]
---
![DFS, BFS, UCS and A* compared on the same maze](/images/posts/ai-search/search_comparison.png)

Few university projects were as much fun as building agents for Pac-Man with a team of four. The agent had to navigate a maze, eat all the food efficiently and stay away from the ghosts. It sounds like a game; it is actually a full tour of classical AI — search, heuristics, adversarial reasoning and reinforcement learning.

To make the search part visible, I ran four algorithms on the same maze. The picture above shows which cells each one explored before it reached the goal, and the numbers tell the story better than any definition.

## Every search is the same loop
The most important idea first: BFS, DFS, UCS and A* are all the <strong>same algorithm</strong>. The only difference is which node from the frontier is expanded next. Here is the generic graph search:

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

Change the data structure behind `frontier`, and you get a different algorithm:

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

## What the experiment shows
I ran exactly this code on the maze in the picture at the top. The yellow area is a "ghost zone" where every step costs 5 instead of 1. These are the results:

| Algorithm | Nodes expanded | Path cost | Optimal? |
|---|---|---|---|
| DFS | 106 | 60 | ❌ |
| BFS | 134 | 56 | ✅ (here, because it avoided the costly zone by luck of the maze) |
| UCS | 117 | 56 | ✅ |
| A* (Manhattan distance) | **87** | 56 | ✅ |

A few things stand out:

1. **DFS** dives deep in one direction and returns the first path it finds — here 4 steps longer than needed.
2. **BFS** finds the path with the fewest steps, but it ignores step costs, so it happily explores inside the costly ghost zone.
3. **UCS** always expands the cheapest path so far, so it is optimal even with different costs.
4. **A\*** finds the same optimal path as UCS while expanding the fewest nodes, because the heuristic guides it toward the goal. Look at the bottom-right picture: most of the maze stays white (unexplored).

## Heuristics: the hard part
A* is only as good as its heuristic `h(n)` — the estimate of the remaining cost to the goal. Two properties matter:

| Property | Meaning | Guarantee |
|---|---|---|
| **Admissible** | Never overestimates: `h(n) ≤ real cost` | A* finds the optimal path |
| **Consistent** | `h(n) ≤ step(n → n') + h(n')` | A* graph search stays optimal and never re-opens nodes |
| `h = 0` | Admissible, but gives no information | A* becomes UCS |

For a grid without diagonal moves, Manhattan distance is admissible:

```python
def manhattan(state, problem):
    (x1, y1), (x2, y2) = state, problem.goal
    return abs(x1 - x2) + abs(y1 - y2)
```

> **From the project:** In the food-eating part of the project, "distance to the <em>nearest</em> food" is admissible but weak. "Distance to the <em>farthest</em> food" is still admissible — Pac-Man has to reach it eventually — and much stronger. The best heuristic is the tightest estimate that still never overestimates.

## Adversarial search: when the ghosts fight back
The maze doesn't move, but ghosts do. Now Pac-Man has to think about what the ghosts will do, and we are searching a <strong>game tree</strong>:

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
    d   = depth - 1 if nxt == 0 else depth            # one ply = every agent moved once
    scores = [minimax(state.after(agent, a), d, nxt) for a in state.legal_actions(agent)]
    return max(scores) if agent == 0 else min(scores) # Pac-Man maximizes, ghosts minimize
```

There are three versions worth knowing:

1. **Minimax** — assumes the ghosts play perfectly against you. Safe, but very cautious.
2. **Alpha-beta pruning** — the same result as minimax, but it skips branches that cannot change the decision. In the tree above, once the right MIN node sees the value 2, it is already worse than the 3 that MAX has, so the leaf 9 is never evaluated.
3. **Expectimax** — assumes the ghosts move randomly and uses the <em>average</em>. Real ghosts are not perfect, so expectimax makes Pac-Man braver — and it usually scores more against them.

## Reinforcement learning: learning without a map
In the last part of the project, Pac-Man had no model of the maze at all. It plays, receives rewards (for example +10 for food, +500 for winning, −500 for being caught), and learns a value for each state and action. This is <strong>Q-learning</strong>, and the whole algorithm is one line:

```python
Q[s][a] += alpha * (reward + gamma * max(Q[s2].values()) - Q[s][a])
```

| Parameter | What it controls | Typical value |
|---|---|---|
| `alpha` (learning rate) | How fast new experience replaces old knowledge | 0.2–0.5 |
| `gamma` (discount) | How much future rewards matter | 0.8–0.99 |
| `epsilon` (exploration) | Chance of a random move instead of the best known one | Start high, decay to ~0.05 |

On a big maze, a table with a value for every state is too large. <strong>Approximate Q-learning</strong> solves this by learning weights for features (distance to the nearest food, ghosts one step away, …) instead of every state — the same idea that later grew into deep reinforcement learning.

## One loop, many algorithms

Classical AI search is one loop where the frontier decides everything: a stack gives DFS, a queue gives BFS, a priority queue on cost gives UCS, and adding a heuristic gives A*. With an admissible heuristic A* stays optimal — and the experiment above shows how many nodes it saves. Add opponents and you need minimax with alpha-beta (or expectimax for imperfect ones); remove the model entirely and Q-learning learns from rewards. To try it yourself, start with the Pac-Man projects from <a href="http://ai.berkeley.edu/project_overview.html" target="_blank" rel="noopener">UC Berkeley's CS188</a>.
