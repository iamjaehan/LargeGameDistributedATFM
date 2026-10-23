# Refined bound on κ for self-prioritizing behaviour (Theorem 1)

Notation follows the manuscript: sectors $\mathbf M$, $|\mathbf M| = m$; flights $n$; $\mathcal F_i$ the flights sector $i$ controls, $n_i = |\mathcal F_i|$; cost $J_i = L_i + \kappa \sum_{j \ne i} L_j$; bin length $\Delta\tau$.

## Original statement

$$
\kappa < \frac{\Delta\tau}{n\,(m-1)\,T_{\max}}
$$

where $T_{\max}$ is the longest time any single flight occupies any single sector. The proof bounds the largest possible drop in the other sectors' overload by $n(m-1)T_{\max}$ (proof of Theorem 1, Eq. A.5): every flight, moving, in every other sector, for the longest possible dwell.

## Refined statement

Let $T_{f,j}$ be the time flight $f$ occupies sector $j$. A departure-time shift translates the trajectory, so $T_{f,j}$ does not depend on the action. If

$$
\kappa \;<\; \frac{\Delta\tau}{\displaystyle\max_{i \in \mathbf M}\; \sum_{f \in \mathcal F_i} \sum_{j \ne i} T_{f,j}},
$$

then no sector adopts an action that increases its own cumulative overload.

The original bound is a corollary: $\sum_{f \in \mathcal F_i}\sum_{j\ne i} T_{f,j} \le n_i (m-1) T_{\max} \le n (m-1) T_{\max}$. The middle form, $\Delta\tau / (\max_i n_i\,(m-1)\,T_{\max})$, is also valid.

## Proof (replaces A.5; the rest is unchanged)

Take a unilateral deviation $x_i \to x_i'$ with $\Delta L_i > 0$. Overload is a sum over bins of integer excesses, so $\Delta L_i \ge \Delta\tau$ (A.4, unchanged).

Only sector $i$'s flights move (Eq. 5). In another sector $j$ at bin $\tau$, the occupancy can fall by at most the number of $i$'s flights that were in $j$ at $\tau$ under $x$, i.e. $C^\tau_{ij}(x)$. The map $\ell \mapsto \max(0, \ell - D_j)$ is 1-Lipschitz, so the overload falls by at most as much:

$$
\ell^\tau_j(x) - \ell^\tau_j(x_i') \;\le\; C^\tau_{ij}(x).
$$

Summing over bins and over $j \ne i$:

$$
\Delta L_{-i} \;\ge\; -\sum_{j \ne i} \sum_{\tau} C^\tau_{ij}(x)\,\Delta\tau
\;=\; -\sum_{f \in \mathcal F_i} \sum_{j \ne i} T_{f,j}.
$$

Hence, whenever $\Delta L_i > 0$,

$$
J_i(x_i') - J_i(x) \;\ge\; \Delta\tau - \kappa \sum_{f \in \mathcal F_i}\sum_{j\ne i} T_{f,j} \;>\; 0
$$

under the refined condition, so such a deviation is never cost-improving. ∎

## Values on the BREST study (D = 7, 28 days, Δτ = 1 s bins)

Dwell counted in 1-second bins, inclusive, as the simulator counts occupancy.

| Bound | Formula | Min over days | Median |
|---|---|---|---|
| Original Theorem 1 | Δτ / (n (m−1) T_max) | 7.4e-9 | 1.7e-8 |
| n → n_i | Δτ / (max_i n_i (m−1) T_max) | 6.2e-8 | 1.3e-7 |
| **Refined (actual dwell)** | **Δτ / max_i Σ_{f∈F_i} Σ_{j≠i} T_{f,j}** | **2.3e-6** | **2.9e-6** |

The tightest day is 230722.

- **κ = 10⁻⁶ satisfies the refined bound on all 28 days.** It is the value used in `Devel/exp_brest_days_D7.mat`.
- κ = 10⁻⁸ does **not** satisfy the original bound on every day (minimum 7.4e-9).
- κ = 10⁻⁸ is also numerically fragile in the best-response MILP. The objective is scaled by 1/κ, so the coefficients span about 10¹¹. One best response (230715, round 1, the sector controlling 136 flights) did not return within its 600 s limit.

## For the manuscript

- Theorem 1: state the refined bound. The original can remain as a corollary.
- Appendix A, Eq. (A.5): replace with the inequality above.
- Section 6.1: κ = 10⁻⁶ "satisfies the bound of Theorem 1 on every traffic day" rather than "approximates the self-prioritizing regime".
- Δτ is 1 s in the experiments. The manuscript currently says 1 min.
