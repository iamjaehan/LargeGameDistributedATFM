import numpy as np
import matplotlib.pyplot as plt
import random
import os
from itertools import product

from BRD import best_response_dynamics

class Airspace:
    def __init__(self, nb_x, nb_y, dx, dy, time_horizon, dt, capacity):
        """
        Initialize an Airspace object.

        Parameters:
        nb_x (int): Number of blocks along the x-axis.
        nb_y (int): Number of blocks along the y-axis.
        dx (float): Size of each block along the x-axis.
        dy (float): Size of each block along the y-axis.
        time_horizon (float): Total time horizon for the simulation.
        dt (float): Time step for the simulation.
        capacity (float): Capacity of each block.

        """
        self.nb_x = nb_x
        self.nb_y = nb_y
        self.nb = nb_x * nb_y
        self.dx = dx
        self.dy = dy
        self.ids = np.arange(self.nb)
        self.ids.resize((nb_x, nb_y))
        self.blocks = np.array([[[i*dx, j * dy], [(i+1)*dx, j * dy], [(i+1)*dx, (j+1) * dy], [i*dx, (j+1) * dy], [i*dx, j * dy]] for i in range(nb_x) for j in range(nb_y)])
        self.centers = np.array([[(i+0.5)*dx, (j+0.5) * dy] for i in range(nb_x) for j in range(nb_y)])
        self.times = np.arange(0, time_horizon, dt)
        self.dt = dt
        self.capacities = np.ones(self.nb) * capacity

    def __str__(self):
        return str(self.blocks)

    def is_inblock(self, x, y):
        i = int(x//self.dx)
        j = int(y//self.dy)
        if i >= 0 and i < self.nb_x:
            if j >= 0 and j < self.nb_y:
                return self.ids[i, j]
        return -1
    
    def plot(self, flights, filename="animation"):
        """
        Generate a plot of the airspace at each time step, highlighting overloaded blocks.

        Parameters:
        flights (list): A list of Flight objects representing the flights in the airspace.
        filename (str, optional): The base name for the saved plot images. Default is "animation".

        The function iterates over each time step in the simulation, creating a plot of the airspace.
        Overloaded blocks are highlighted in red, while non-overloaded blocks are shown in gray.
        The function saves each plot image with a filename constructed from the base name and the time step.
        """
        # self.print_flights(flights)
        for t in self.times:
            plt.figure()
            plt.scatter(self.centers[:,0], self.centers[:,1], color="black")
            for i in range(self.nb):
                c = "red" if self.overloaded[t//self.dt, i] else "gray"
                plt.fill(self.blocks[i,:,0], self.blocks[i,:,1],color=c, alpha=0.2)
                plt.text(self.centers[i,0]+0.01*self.dx, self.centers[i,1]+0.01*self.dy, str(self.is_inblock(*self.centers[i])))
            for flight in flights:
                flight.plot(t, t+self.dt)
            plt.savefig(f"{IMG_DIR}/{filename}{t}.png")
            plt.close()
    
    def occupancy_count(self, flights):
        """
        Calculate the occupancy count and identify overloaded blocks for each time step.

        Parameters:
        flights (list): A list of Flight objects representing the flights in the airspace.

        Returns:
        counts (numpy.ndarray): A 3D array of shape (len(self.times), self.nb, self.nb) representing the occupancy count if overloaded else zero for each time step and block.
        phi (numpy.ndarray): A 1D array of shape (len(self.times)) representing the trace of the occupancy count if overloaded else zero summed over all blocks for each time step.
        """
        self.counts = np.zeros((len(self.times), self.nb, self.nb))
        for flight in flights:
            dep_block = self.is_inblock(*flight.dep)
            last_t = -1
            for point in flight.traj:
                traj_block = self.is_inblock(*point[:2])
                t = int(point[2]//self.dt)
                if last_t < t:
                    self.counts[t, dep_block, traj_block] +=  1
                last_t = t
        self.overloaded = self.counts.sum(axis=1)>np.ones((len(self.times), self.nb))*(self.capacities)
        for i in range(self.nb):
            self.counts[:,i,:] = np.multiply(self.counts[:,i,:], self.overloaded)
        self.phi = np.trace(self.counts.sum(axis=0))
        return self.counts, self.phi
    
class Flight:
    def __init__(self, airports, speed, upper_start_time, dt=1):
        """
        Initialize a Flight object.

        Parameters:
        airports (numpy.ndarray): A 2D array containing the coordinates of airports.
        speed (float): The speed of the flight in units per time step.
        upper_start_time (int): The upper limit for the start time of the flight.
        dt (float, optional): The time step for the simulation. Default is 1.

        The flight is initialized with a random departure and destination airport,
        a random start time within the given range, and a trajectory calculated based
        on the speed and duration of the flight.
        """
        i = random.randint(0, len(airports)-1)
        j= random.randint(0, len(airports)-1)
        if j == i:
            j -= 1
        self.dep = airports[i]
        self.dest = airports[j]
        self.speed = speed
        self.dt = dt
        dv = self.dest-self.dep
        self.duration = np.linalg.norm(dv)/self.speed
        self.dv = dv / self.duration
        self.update_traj(random.randint(0, upper_start_time))
        
    
    def update_traj(self, start_time):
        self.start_time = start_time
        self.end_time = self.duration + self.start_time
        self.times = np.arange(self.start_time, self.end_time, self.dt)
        self.traj = [[*(self.dep + (t-self.start_time) * self.dv), t] for t in self.times]
        if (self.end_time - self.start_time) % self.dt == 0:
            self.traj.append([*self.dest, self.end_time])
        self.traj = np.array(self.traj)

    def plot(self, start_time, end_time):
        x, y= [], []
        for point in self.traj:
            if point[2] >=start_time and point[2] <= end_time:
                x.append(point[0])
                y.append(point[1])
        plt.plot(x, y, marker="+")

    def __str__(self):
        return f"{self.dep} {self.dest} {self.start_time} {self.end_time}"

class AirTraffic:

    def __init__(self, airspace, flights):
        self.airspace = airspace
        self.flights = flights
        self.nb_flights = len(flights)
        self.nominal_start_time = np.array([flight.start_time for flight in self.flights])
        self.counts, self.phi = self.airspace.occupancy_count(self.flights)
    
    def update_flights(self, new_start_times):
        """
        Update the trajectories of the flights based on new start times and recalculate the occupancy count and trace.

        Parameters:
        new_start_times (numpy.ndarray): A 1D array of new start times for each flight. The length of this array should be equal to the number of flights.

        The function iterates over each flight, updates its trajectory using the new start time, and then recalculates the occupancy count and trace using the updated trajectories.
        """
        for i in range(self.nb_flights):
            self.flights[i].update_traj(new_start_times[i])
        self.counts, self.phi = self.airspace.occupancy_count(self.flights)
    
    def nb_overloaded(self):
        return self.airspace.overloaded.sum()

    def plot(self, filename="animation"):
        self.airspace.plot(self.flights, filename)

    def print_flights(self, flights):
        for flight in flights:
            self.print_flight(flight)

    def print_flight(self, flight):
        """
        Print the flight details including the departure and destination block IDs, and the start time.

        Parameters:
        flight (Flight): A Flight object representing the flight to be printed.

        The function calculates the departure and destination block IDs using the `is_inblock` method
        and then prints the flight details in the format "{dep_block}->{dest_block} : {start_time}".
        """
        i = self.airspace.is_inblock(*flight.dep)
        j = self.airspace.is_inblock(*flight.dest)
        print(f"{i}->{j} : {flight.start_time}")

    def block_ctrl(self, flight):
        """
        Determine the block ID of the sector controlling a given flight.

        Parameters:
        flight (Flight): A Flight object representing the flight for which the controlling sector needs to be determined.

        Returns:
        int: The block ID of the sector controlling the given flight.

        The function calculates the departure block ID of the given flight using the `is_inblock` method
        of the Airspace object and returns this block ID as the controlling sector.
        """
        i = self.airspace.is_inblock(*flight.dep)
        return i

if __name__ == '__main__':
    IMG_DIR = os.path.expanduser("~/Documents/main/LargeNashATM/img")
    CAPACITY = 2
    TIME_WINDOW = 2
    TIME_HORIZON = 20
    NB_X = 2
    NB_Y = 2
    DX = 2
    DY = 2
    MAX_START_TIME = 10
    DT = 0.1
    NB_FLIGHTS = 20
    NB_SECTORS = NB_X * NB_Y
    airspace = Airspace(NB_X, NB_Y, DX, DY, TIME_HORIZON, TIME_WINDOW, CAPACITY)
    flights = [Flight(airspace.centers, 1.0, MAX_START_TIME, DT) for i in range(NB_FLIGHTS)]
    instance = AirTraffic(airspace, flights)

    # i = 0
    NEW_START_TIMES = np.arange(0, MAX_START_TIME, DT)
    ACTIONS = np.array([-1,-0.5,0,0.5,1])
    # ACTIONS = np.array([-3,-2,-1,0,1,2,3])
    numFlights = instance.nb_flights
    
    # Map: player_id -> list of flight indices
    player_to_flights = [[] for _ in range(NB_SECTORS)]
    for flight_idx, flight in enumerate(flights):
        player_id = instance.block_ctrl(flight)
        player_to_flights[player_id].append(flight_idx)
    
    # Brute Force
    # actionCombinations = np.asarray(list(product(ACTIONS,repeat=numFlights)))
    # numCombinations = len(actionCombinations)
    # nominalStartTime = np.copy(instance.nominal_start_time)
    
    # overloaded = np.zeros(numCombinations)
    # phi = np.zeros(numCombinations)
    # totalCost = np.zeros(numCombinations)
    # for i in range(numCombinations):
    #     new_start_times = nominalStartTime + actionCombinations[i]
    #     instance.update_flights(new_start_times)
    #     overloaded[i] = instance.nb_overloaded()
    #     totalCost[i] = np.sum(instance.counts)
    #     phi[i] = instance.phi
    
    # minIndices = np.where(phi == np.min(phi))
    # minIdx = minIndices[0][0]
    # nashCost = totalCost[minIdx]
    # optCost = np.min(totalCost)
    # print(f"Minimum indices: {minIdx}")
    # print(f"Nash equilibrium: {actionCombinations[minIdx]}, System cost: {nashCost}")
    # print(f"Optimal Cost: {optCost}")
    # print(f"Optimality Gap: {(nashCost-optCost)/optCost}")
    
    # print(instance.block_ctrl(flights[1]))
    
    # Run BRD
    final_times, final_action, system_cost, individual_costs = best_response_dynamics(
        instance=instance,
        nominal_start_time=instance.nominal_start_time,
        actions=ACTIONS,
        player_to_flights=player_to_flights,
        max_iter=100,
        verbose=True
    )
    
    print("\n[Best Response Dynamics Result]")
    print(f"Final Start Times: {final_times}")
    print(f"Final Action: {final_action}")
    print(f"System Cost: {system_cost}")
    print(f"Individual Costs: {individual_costs}")
    
    # Find the index in actionCombinations that matches final_action
    # brd_index = np.where(np.all(np.isclose(actionCombinations, final_action, atol=1e-6), axis=1))[0]

    # if len(brd_index) > 0:
    #     brd_index = brd_index[0]
    #     print(f"BRD index found: {brd_index}")
    # else:
    #     brd_index = None
    #     print("⚠️ BRD result not found in brute-force combinations.")
    
    # plt.figure()
    # plt.plot(range(numCombinations),totalCost, linestyle='--', marker='.', label="Total Cost", color="orange")
    # plt.plot(range(numCombinations), phi, linestyle=':', marker='.', label="Potential Cost", color="blue")
    # if brd_index is not None:
    #     # plt.axvline(x=brd_index, color="red", linestyle="--", label="BRD Result")
    #     plt.scatter(brd_index, totalCost[brd_index], color="red", zorder=5)
    # plt.legend()
    # plt.title("Potential to Total Cost Comparison")
    # plt.xlabel("Action Combination Index")
    # plt.ylabel("Cost (Total Occupancy Count)")
    # plt.savefig(f"{IMG_DIR}/CostComparison.png")
    # plt.show()