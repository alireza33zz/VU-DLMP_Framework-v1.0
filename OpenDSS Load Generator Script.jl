# Load Generator Script with Unique Bus-Phase Combinations

# Flag to identify the specific load generation scenario
A = 112  # Modify this number as needed

# Define the available bus names
bus_names = [
    5, 7, 10, 11, 12, 13, 21, 25, 26, 29,     
    30, 33, 34, 37, 39, 40, 42, 45, 46, 47,   
    49, 50, 52, 54, 57, 60, 62, 64, 66, 67,   
    72, 73, 75, 76, 77, 80, 81, 83, 87, 88,   
    93, 95, 96, 97, 102, 103, 104, 106, 107, 110,
    112, 113, 114, 115, 116                   
]

# Define possible phase coordinates
phases = [1, 2, 3]

# Define load sizes
load_sizes = (2:8) .* 0.25

# Define power factors
power_factors = [0.85, 0.90, 0.95]

# Function to generate loads with unique bus-phase combinations
function generate_loads(num_loads)
    # Track used bus-phase combinations
    used_combinations = Set{Tuple{Int, Int}}()
    
    # Open file for writing
    filename = "Load$A.txt"
    open(filename, "w") do file
        # Counter for actually added loads
        loads_added = 0
        
        # Maximum attempts to find unique combinations
        max_attempts = length(bus_names) * length(phases)
        attempts = 0
        
        while loads_added < num_loads && attempts < max_attempts
            # Randomly select bus name
            bus_name = rand(bus_names)
            
            # Randomly select phase
            phase = rand(phases)
            
            # Check if this bus-phase combination is unique
            if !((bus_name, phase) in used_combinations)
                # Randomly select load size
                load_size = rand(load_sizes)
                
                # Randomly select power factor
                pf = rand(power_factors)
                
                # Construct load definition
                load_def = "New Load.LOAD$(loads_added+1) Phases=1 Bus1=$bus_name.$phase kV=0.23 kW=$load_size PF=$pf\n"
                
                # Write to file
                write(file, load_def)
                
                # Mark this combination as used
                push!(used_combinations, (bus_name, phase))
                
                # Increment loads added
                loads_added += 1
            end
            
            # Increment attempts to prevent infinite loop
            attempts += 1
        end
        
        # Check if we couldn't generate enough unique loads
        if loads_added < num_loads
            println("Warning: Only generated $loads_added unique loads out of $num_loads requested")
        else
            println("Loads generated and saved to $filename")
        end
    end
    
    return used_combinations
end

# Example usage: generate 10 loads
unique_loads = generate_loads(130);