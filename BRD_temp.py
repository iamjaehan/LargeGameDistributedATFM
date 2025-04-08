import numpy as np

def best_response_dynamics(instance, nominal_start_time, actions, num_players, max_iter=100, tol=1e-3, verbose=False):
    """
    Perform Best Response Dynamics with simultaneous update for a potential game.
    
    Args:
        instance: AirTraffic instance that supports update_flights().
        nominal_start_time: array of nominal start times for each player.
        actions: list or array of allowable start time adjustments.
        max_iter: maximum number of iterations.
        tol: minimum cost improvement threshold to consider a change meaningful.
        verbose: whether to print convergence info.

    Returns:
        final_start_times: array of converged start times.
        total_cost: system-wide cost at final state.
        player_costs: array of individual player costs.
    """
    current_actions = np.zeros(len(nominal_start_time))

    for it in range(max_iter):
        best_actions = current_actions.copy()
        prev_costs = None
        updated = False

        # For simultaneous update, evaluate all players' best actions in parallel
        for i in range(num_players):
            min_cost = float('inf')
            best_a = current_actions[i]

            for a in actions:
                test_actions = current_actions.copy()
                test_actions[i] = a
                test_start_times = nominal_start_time + test_actions
                instance.update_flights(test_start_times)
                individual_cost = float(instance.counts.sum(axis=0)[:, i].sum())

                if individual_cost < min_cost - tol:
                    min_cost = individual_cost
                    best_a = a

            best_actions[i] = best_a
            if best_a != current_actions[i]:
                updated = True
            if verbose:
                print(f"  Player {i}: Best action = {best_a}, Min cost = {min_cost:.2f}")

        current_actions = best_actions

        if verbose:
            print(f"[Iter {it}] Action Profile: {current_actions}")

        if not updated:
            if verbose:
                print(f"Converged at iteration {it}")
            break

    # Final update
    final_start_times = nominal_start_time + current_actions
    final_action = current_actions
    instance.update_flights(final_start_times)
    player_costs = instance.counts.sum(axis=0).sum(axis=0)
    total_cost = player_costs.sum()

    return final_start_times, final_action, total_cost, player_costs