import numpy as np
from itertools import product

def best_response_dynamics(instance, nominal_start_time, actions, player_to_flights, max_iter=100, tol=1e-3, verbose=False):
    """
    Perform Best Response Dynamics with simultaneous update for a potential game.
    
    Args:
        instance: AirTraffic instance that supports update_flights().
        nominal_start_time: array of nominal start times for each flight.
        actions: list or array of allowable per-flight start time adjustments.
        player_to_flights: list of lists, mapping each player to their controlled flight indices.
        max_iter: maximum number of iterations.
        tol: minimum cost improvement threshold to consider a change meaningful.
        verbose: whether to print convergence info.

    Returns:
        final_start_times: array of converged start times.
        final_action: array of chosen action shifts for each flight.
        total_cost: total system cost at convergence.
        player_costs: array of individual player costs (sum of costs over all flights they control).
    """
    num_players = len(player_to_flights)
    num_flights = len(nominal_start_time)
    current_actions = np.zeros(num_flights)

    for it in range(max_iter):
        best_actions = current_actions.copy()
        updated = False

        for i in range(num_players):
            flight_indices = player_to_flights[i]
            best_a_vector = current_actions[flight_indices]
            min_cost = float('inf')

            for a_vector in product(actions, repeat=len(flight_indices)):
                test_actions = current_actions.copy()
                test_actions[flight_indices] = a_vector
                test_start_times = nominal_start_time + test_actions
                instance.update_flights(test_start_times)
                individual_cost = float(instance.counts.sum(axis=0)[:, i].sum())

                if individual_cost < min_cost - tol:
                    min_cost = individual_cost
                    best_a_vector = a_vector

            if not np.allclose(best_actions[flight_indices], best_a_vector, atol=tol):
                updated = True
            best_actions[flight_indices] = best_a_vector

            if verbose:
                print(f"  Player {i}: Best action = {best_a_vector}, Min cost = {min_cost:.2f}")

        current_actions = best_actions

        if verbose:
            print(f"[Iter {it}] Action Profile: {current_actions}")

        if not updated:
            if verbose:
                print(f"Converged at iteration {it}")
            break

    # Final update
    final_start_times = nominal_start_time + current_actions
    instance.update_flights(final_start_times)

    player_costs = np.zeros(num_players)
    cost_matrix = instance.counts.sum(axis=0)  # shape: (num_flights, num_players)
    for i in range(num_players):
        player_costs[i] = cost_matrix[:, i].sum()

    total_cost = player_costs.sum()

    return final_start_times, current_actions, total_cost, player_costs