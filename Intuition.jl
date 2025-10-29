"""
This script performs a three-phase optimal power flow (OPF) calculation using the PowerModelsDistribution package in Julia. 
It includes the ability to add custom constraints, such as voltage magnitude limits and voltage unbalance factor (VUF) constraints. 
The script is modular and generic, allowing for easy integration of new constraints and configurations.

Key Components:
1. Configuration struct to hold OPF parameters.
2. Default configuration function.
3. Custom constraint types for extensibility.
4. Functions to add voltage magnitude and VUF constraints to the model.
5. Solver configuration function.
6. Model initialization function.
7. Function to calculate VUF using the sequence components method.
8. Functions to extract, format, and print key results from the OPF solution.
9. Main function to solve OPF with custom constraints.
10. Test function with default settings.
11. Optional diagnostic function to understand network structure.
"""

using PowerModelsDistribution
using JuMP
using Ipopt
using DataFrames

"""
Configuration struct to hold OPF parameters
"""
struct OPFConfig
    sbase_default::Float64
    power_scale_factor::Float64
    v_upper_bound::Float64
    v_lower_bound::Float64
    thermal::Float64
    VUF_level::Float64
    print_level::Int
end

"""
Default configuration
"""
function default_config()
    return OPFConfig(
        1.0,    # sbase_default
        1000.0, # power_scale_factor (kW)
        1.10,   # v_upper_bound (p.u.)
        0.94,   # v_lower_bound (p.u.)
        100,    # thermal (kVA)
        1.0,    # VUF_level (%)
        1       # print_level
    )
end

"""
Custom constraint type for extensibility
"""
abstract type AbstractConstraint end

struct VoltageConstraint <: AbstractConstraint
    v_upper_bound::Float64
    v_lower_bound::Float64
end

struct ThermalConstraint <: AbstractConstraint
    phase_a::Float64
    phase_b::Float64
    phase_c::Float64
end

struct VUFConstraint <: AbstractConstraint
    vuf_threshold::Float64
end

"""
Add voltage magnitude constraints to the model (v_lower_bound <= v <= v_upper_bound)
"""
function add_voltage_constraints!(pm, constraint::VoltageConstraint)
    pm.model[:voltage_constraints] = Dict()
    for i in 1:length(pm.data["bus"])
        for phase in 1:3
            con = @constraint(pm.model, constraint.v_lower_bound <= pm.var[:it][:pmd][:nw][0][:vm][i][phase] <= constraint.v_upper_bound)
            pm.model[:voltage_constraints][(i, phase)] = con
        end
    end
    println("")
    printstyled("Voltage magnitude constraints integrated successfully!"; color=:yellow)
end

"""
Add thermal limits constraints to the model (p^2 + q^2 <= s^2)
"""
function add_thermal_constraints!(math, constraint::ThermalConstraint)
    N_lines = length(math["branch"])
    for i in 1:(N_lines - 1)
        # Define thermal limits for each phase
        thermal_limits = [constraint.phase_a, constraint.phase_b, constraint.phase_c]
        math["branch"]["$i"]["rate_a"] = thermal_limits
        
    end
    println()
    printstyled("Thermal constraints integrated successfully!"; color=:yellow)
end

"""
Add voltage unbalance factor (VUF) constraints to the model (VUF = V2 / V1 <= threshold)
"""
function add_vuf_constraints!(pm, constraint::VUFConstraint)
    N_bus = length(pm.data["bus"])
    vm_var_allbus = pm.var[:it][:pmd][:nw][0][:vm]
    va_var_allbus = pm.var[:it][:pmd][:nw][0][:va]
    
    # Define real and imaginary parts of phase voltages as decision variables
    @variable(pm.model, vp_r[bus=1:N_bus, i=1:3])
    @variable(pm.model, vp_i[bus=1:N_bus, i=1:3])

    # Use expressions for cos and sin calculations
    @expression(pm.model, vp_r_expr[bus=1:N_bus, i=1:3], vm_var_allbus[bus][i] * cos(va_var_allbus[bus][i]))
    @expression(pm.model, vp_i_expr[bus=1:N_bus, i=1:3], vm_var_allbus[bus][i] * sin(va_var_allbus[bus][i]))

    # Use these expressions in constraints
    @constraint(pm.model, [bus=1:N_bus, i=1:3], vp_r[bus,i] == vp_r_expr[bus,i])
    @constraint(pm.model, [bus=1:N_bus, i=1:3], vp_i[bus,i] == vp_i_expr[bus,i])

    # Expressions for real and imaginary parts of positive sequence voltage components
    @expression(pm.model, v_pos_r[bus=1:N_bus], 
        (1/3) * (vp_r[bus,1] + (-0.5) * vp_r[bus,2] - 0.866 * vp_i[bus,2] + (-0.5) * vp_r[bus,3] - (-0.866) * vp_i[bus,3]))
    @expression(pm.model, v_pos_i[bus=1:N_bus], 
        (1/3) * (vp_i[bus,1] + (-0.5) * vp_i[bus,2] + 0.866 * vp_r[bus,2] + (-0.5) * vp_i[bus,3] + (-0.866) * vp_r[bus,3]))

    # Expressions for real and imaginary parts of negative sequence voltage components
    @expression(pm.model, v_neg_r[bus=1:N_bus], 
        (1/3) * (vp_r[bus,1] + (-0.5) * vp_r[bus,2] - (-0.866) * vp_i[bus,2] + (-0.5) * vp_r[bus,3] - 0.866 * vp_i[bus,3]))
    @expression(pm.model, v_neg_i[bus=1:N_bus], 
        (1/3) * (vp_i[bus,1] + (-0.5) * vp_i[bus,2] + (-0.866) * vp_r[bus,2] + (-0.5) * vp_i[bus,3] + 0.866 * vp_r[bus,3]))

    # Expressions for magnitudes of positive and negative sequence voltages
    @expression(pm.model, v_pos[bus=1:N_bus], v_pos_r[bus]^2 + v_pos_i[bus]^2)
    @expression(pm.model, v_neg[bus=1:N_bus], v_neg_r[bus]^2 + v_neg_i[bus]^2)

    # VUF constraint to ensure the negative sequence voltage is within the allowed threshold
    pm.model[:vuf_constraints] = Dict()
    for bus in 1:N_bus
        con = @constraint(pm.model, v_neg[bus] <= (constraint.vuf_threshold^2) * v_pos[bus])
        pm.model[:vuf_constraints][bus] = con
    end
    
    println()
    printstyled("VUF constraints integrated successfully!"; color = :yellow)
end

"""
Configure solver with custom settings
"""
function configure_solver(config::OPFConfig)
    return JuMP.optimizer_with_attributes(
        Ipopt.Optimizer,
        "print_level" => config.print_level,
        "tol" => 1e-8,  # Adjust tolerance
        "acceptable_tol" => 1e-8  # Adjust acceptable tolerance
    )
end

"""
Initialize PowerModelsDistribution model with basic settings
"""
function initialize_model(eng::Dict, config::OPFConfig)
    eng["settings"]["sbase_default"] = config.sbase_default
    eng["settings"]["power_scale_factor"] = config.power_scale_factor
    math = transform_data_model(eng)

Cost_Func = 1
    if Cost_Func == 1
        math["gen"]["1"]["cost"] = [0.0, 0.0]
        math["gen"]["2"]["cost"] = [0.0, 0.0]
        math["gen"]["3"]["cost"] = [0.0, 0.0]
        math["gen"]["4"]["cost"] = [1.0, 0.0]
    end

    math["gen"]["4"]["pmin"] = [0.0, 0.0, 0.0]

    return math
end

"""
Calculate Voltage Unbalance Factor (VUF) using sequence components method
"""
function calculate_vuf(vm::Vector{Float64}, va::Vector{Float64})
    # Transformation angle for sequence components
    a = exp(im * 2π/3)
    
    # Convert magnitude and angle to complex voltages
    Va = vm[1] * exp(im * va[1])
    Vb = vm[2] * exp(im * va[2])
    Vc = vm[3] * exp(im * va[3])
    
    # Calculate sequence components (corrected)
    V0 = (Va + Vb + Vc) / 3 
    V1 = (Va + a * Vb + a^2 * Vc) / 3 
    V2 = (Va + a^2 * Vb + a * Vc) / 3
    
    # Calculate VUF
    vuf = abs(V2) / abs(V1) * 100
    
    return vuf
end

"""
Extract and format key results from the OPF solution with VUF
"""
function format_results(solution::Dict, pm)
    # Initialize DataFrame for bus results
    results_df = DataFrame(
        bus_id = String[],
        phase = String[],  # Change to String[]
        vm_pu = Float64[],
        va_deg = Float64[],
        vuf_percent = Float64[]
    )

    # Define phase mapping
    bus_map = Dict("1" => "4", "2" => "1", "3" => "2", "4" => "3", "5" => "0")
    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")

    # Extract bus results
    for (bus_id, bus) in solution["solution"]["bus"]
        # Collect voltage magnitudes and angles for this bus
        vm = bus["vm"]
        va = bus["va"] * (180/π)  # Convert to degrees for readability

        # Calculate VUF for this bus
        vuf = calculate_vuf(bus["vm"], bus["va"])
               
        # Add rows to DataFrame
        for phase in 1:3
            push!(results_df, (
                bus_map[bus_id],
                phase_map[phase],  # Use the phase mapping
                round(vm[phase], digits=3),
                round(va[phase], digits=1),
                round(vuf, digits=3)
            ))
        end
    end
    
    # Sort by bus_id and phase
    sort!(results_df, [:bus_id, :phase])
    
    return results_df
end

"""
Print formatted results with VUF
"""
function print_formatted_results(solution::Dict, pm)
    if solution["termination_status"] != MOI.LOCALLY_SOLVED
        println()
        printstyled("WARNING: OPF didn't converge!"; color=:red)
        println()
        return
    end

    # Format and display results
    results_df = format_results(solution, pm)
    printstyled("\n=== OPF Results ==="; color = :green)
    println()
    printstyled("Objective value: ", round(solution["objective"], digits=3); color = :blue)
    println()
    println("Solve time: ", round(solution["solve_time"], digits=6), " seconds")
    println("\nBus Results:")
    println(results_df)
end

"""
Retrieve and print dual variables for specific constraints and variables
"""
function print_dual_variables(pm)
    bus_map = Dict(1 => 4, 2 => 1, 3 => 2, 4 => 3, 5 => 0)
    println("\n=== Dual Variables ===")
    println("")
    # Print dual variables for voltage magnitude constraints
    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")
    println("Voltage Magnitude Constraints:")
    for i in 1:length(pm.data["bus"])
        j = bus_map[i]
        for phase in 1:3
            constraint = pm.model[:voltage_constraints][(i, phase)]
            dual_value = round(JuMP.dual(constraint), digits=3)
            phase_name = phase_map[phase]
            println("Bus $j, Phase $phase_name: Dual Value = $dual_value")
        end
    end
    
    # Print dual variables for VUF constraints
    println("\nVoltage Unbalance Factor (VUF) Constraints:")
    for i in 1:length(pm.data["bus"])
        constraint = pm.model[:vuf_constraints][i]
        dual_value = round(JuMP.dual(constraint), digits=3)
        j = bus_map[i]
        println("Bus $j: Dual Value = $dual_value")
    end
    #

    # Print dual variables for Pg variables
    println("\nActive Power Generation (Pg) of PVs:")
    for (gen_id, dense_array) in pm.var[:it][:pmd][:nw][0][:pg_bus]
        for idx in eachindex(dense_array)
            variable = dense_array[idx]
            if variable isa JuMP.VariableRef && JuMP.has_upper_bound(variable)
                dual_value = round(JuMP.dual(JuMP.UpperBoundRef(variable)), digits=3)
                println("Generator $gen_id, Dual Value = $dual_value")
            end
        end
    end
end

"""
Retrieve and print shadow prices
"""
function print_shadow_prices(pm)
    bus_map = Dict(1 => 4, 2 => 1, 3 => 2, 4 => 3, 5 => 0)
    println("\n=== Shadow Prices ===")
    println("")
    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")
    # Print shadow prices for the P balance constraints
    println("Active Power Balance Constraints:")
    for i in 1:length(pm.data["bus"])
        j = bus_map[i]
        for phase in 1:3
            constraint = pm.con[:it][:pmd][:nw][0][:lam_kcl_r][i][phase]
            dual_value = round(JuMP.dual(constraint), digits=3)
            phase_name = phase_map[phase]
            println("Bus $j, Phase $phase_name: Shadow Price = $dual_value")
        end
    end
    
    println("")
    # Print shadow prices for the Q balance constraints
    println("Reactive Power Balance Constraints:")
    for i in 1:length(pm.data["bus"])
        j = bus_map[i]
        for phase in 1:3
            constraint = pm.con[:it][:pmd][:nw][0][:lam_kcl_i][i][phase]
            dual_value = round(JuMP.dual(constraint), digits=3)
            phase_name = phase_map[phase]
            println("Bus $j, Phase $phase_name: Shadow Price = $dual_value")
        end
    end

    println("")
    # Print shadow prices for the branch constraints
    println("Thermal Limit on Branches Constraints:")
    for ((branch, from_bus, to_bus), constraints) in pm.con[:it][:pmd][:nw][0][:mu_sm_branch]
        j = bus_map[from_bus]
        k = bus_map[to_bus]
        for phase in 1:3
        constraint = constraints[phase]
        dual_value = round(JuMP.dual(constraint), digits=3)
        phase_name = phase_map[phase]
        println("Branch $branch, between ($j, $k) buses, in Phase $phase_name: Shadow Price = $dual_value")
        end
    end

end

"""
Main function to solve OPF with custom constraints
"""
function solve_opf(file_path::String, config::OPFConfig=default_config())

    # Parse network file
    eng = parse_file(file_path)

    # Initialize model
    math = initialize_model(eng, config)

    # Add thermal constraints
    thermal_limits = ThermalConstraint(config.thermal, config.thermal, config.thermal) 
    add_thermal_constraints!(math, thermal_limits)

    # Initialize PowerModelsDistribution model
    pm = instantiate_mc_model(math, ACPUPowerModel, build_mc_opf)
    pm.data["per_unit"] = false

    # Add voltage magnitude constraints
    voltage_constraint = VoltageConstraint(config.v_upper_bound, config.v_lower_bound)
    add_voltage_constraints!(pm, voltage_constraint)

    # Add VUF constraint
    vuf_constraint = VUFConstraint(config.VUF_level/100)
    add_vuf_constraints!(pm, vuf_constraint)

    # Configure and run solver
    solver = configure_solver(config)
    solution = optimize_model!(pm, optimizer=solver)

    # Print formatted results
    print_formatted_results(solution, pm)

    # Print dual variables
    print_dual_variables(pm)

    # Print shadow prices
    print_shadow_prices(pm)

    return solution, pm, format_results(solution, pm)
end

"""
Test function with default settings
"""
function test_opf_with_vuf(file_path::String)
    # Define custom configuration
    config = OPFConfig(
        1.0,    # sbase_default
        1000.0, # power_scale_factor
        1.10,   # v_upper_bound
        0.94,   # v_lower_bound
        20.0,    # thermal
        1.0,    # VUF_level
        1       # print_level
    )
   
    # Solve OPF with VUF constraint
    solution, pm, results_df = solve_opf(file_path, config)
    
    return solution, pm, results_df
end

# Example usage:
file_path = "Test2.dss"
solution, pm, results_df = test_opf_with_vuf(file_path);

# Optional: Diagnostic function to understand network structure
function print_network_structure(solution::Dict, pm)
    println("\n=================================================================================")
    println("Complete report:\n")

# Print bus information with translated names
println("Buses:")
for (bus_id, bus) in solution["solution"]["bus"]
    # Find original bus ID
    original_id = "Substation"  # Default to "Substation" instead of "Unknown"
    for (orig_id, assigned_num) in pm.data["bus_lookup"]
        if string(assigned_num) == bus_id
            original_id = orig_id
            break
        end
    end
    println("Bus $original_id")
end

# Generator code with updated bus name handling
println("\nGenerators:")

# Create a reverse lookup to get original bus IDs from assigned numbers
reverse_bus_lookup = Dict{Int, String}()
for (original_id, assigned_num) in pm.data["bus_lookup"]
    reverse_bus_lookup[assigned_num] = original_id
end

# Group generators by bus number
gens_by_bus = Dict{Int, Vector{Tuple{String, Dict{String, Any}}}}()

for (gen_id, gen) in pm.data["gen"]
    bus_num = gen["gen_bus"]
    if !haskey(gens_by_bus, bus_num)
        gens_by_bus[bus_num] = []
    end
    push!(gens_by_bus[bus_num], (gen_id, gen))
end

# Sort buses numerically
sorted_buses = sort(collect(keys(gens_by_bus)))

# Initialize total cost
total_cost = 0.0

for bus in sorted_buses
    # Get the original bus ID from the assigned number
    original_bus_id = get(reverse_bus_lookup, bus, "Substation")  # Use "Substation" instead of "Unknown"
    
    println("Bus $original_bus_id:")
    
    # Sort generators by phase (connections)
    bus_gens = gens_by_bus[bus]
    sort!(bus_gens, by = x -> minimum(x[2]["connections"]))
    
    for (gen_id, gen) in bus_gens
        phases = gen["connections"]
        phase_names = ["a", "b", "c"]
        phase_str = join([phase_names[p] for p in phases], ",")
        
        println("Phase(s): $phase_str")
        
        # Get pg and qg values from solution dictionary
        if haskey(solution["solution"]["gen"], gen_id)
            sol_gen = solution["solution"]["gen"][gen_id]
            pg_bus = round.(get(sol_gen, "pg_bus", "Not found"), digits=6)
            qg_bus = round.(get(sol_gen, "qg_bus", "Not found"), digits=6)
            
            println("    pg: ", pg_bus)
            println("    qg: ", qg_bus)
            
            # Calculate apparent power
            if pg_bus != "Not found" && qg_bus != "Not found"
                s_bus = sqrt.(pg_bus.^2 + qg_bus.^2)
                println("    s: ", round.(s_bus, digits=6))
                
                # Calculate generation cost only if generator is producing power
                if haskey(gen, "cost") && pg_bus != "Not found"
                    cost_coeffs = gen["cost"]
                    if length(cost_coeffs) == 2
                        a = cost_coeffs[1]
                        b = cost_coeffs[2]
                        
                        # Check if generator is on (producing power)
                        if isa(pg_bus, Array)
                            # For multi-phase generators, calculate cost only for active phases
                            gen_cost = 0.0
                            for p in pg_bus
                                if p > 0.000001  # Small tolerance to account for floating point
                                    gen_cost += a * p + b
                                end
                            end
                        else
                            # For single-phase generators
                            gen_cost = (pg_bus > 0.000001) ? (a * pg_bus + b) : 0.0
                        end
                        
                        println("    cost: ", round(gen_cost, digits=4))
                        total_cost += gen_cost
                    end
                end
            end
        else
            println("    No solution data found for this generator")
        end
    end
end

# Print total generation cost
println("\nTotal Generation Cost: \$", round(total_cost, digits=2))
    
    println("\nLoads:")

    # Create a reverse lookup to get original bus IDs from assigned numbers
    reverse_bus_lookup = Dict{Int, String}()
    for (original_id, assigned_num) in pm.data["bus_lookup"]
        reverse_bus_lookup[assigned_num] = original_id
    end
    
    # Group loads by bus number
    loads_by_bus = Dict{Int, Vector{Tuple{String, Dict{String, Any}}}}()
    
    for (load_id, load) in pm.data["load"]
        bus_num = load["load_bus"]
        if !haskey(loads_by_bus, bus_num)
            loads_by_bus[bus_num] = []
        end
        push!(loads_by_bus[bus_num], (load_id, load))
    end
    
    # Sort buses numerically
    sorted_buses = sort(collect(keys(loads_by_bus)))
    
    for bus in sorted_buses
        # Get the original bus ID from the assigned number
        original_bus_id = get(reverse_bus_lookup, bus, "Unknown")
        
        println("Bus $original_bus_id:")
        
        # Sort loads by phase (connections)
        bus_loads = loads_by_bus[bus]
        sort!(bus_loads, by = x -> minimum(x[2]["connections"]))
        
        for (load_id, load) in bus_loads
            phases = load["connections"]
            phase_names = ["a", "b", "c"]
            phase_str = join([phase_names[p] for p in phases], ",")
            
            println("Phase(s): $phase_str")
            
            pd = load["pd"]
            qd = load["qd"]
            
            println("    pd: ", round.(pd, digits=6))
            println("    qd: ", round.(qd, digits=6))
            
            # Calculate apparent power
            if length(pd) == length(qd)
                s = sqrt.(pd.^2 + qd.^2)
                println("    s: ", round.(s, digits=6))
            end
        end
    end
end

print_network_structure(solution, pm);



#
using PowerModelsDistribution 
using JuMP
using Ipopt


file_path = "LVTestCase/Master.dss"
eng = parse_file(file_path);
math = transform_data_model(eng);
# math["gen"]["1"]["cost"] = [100000.0, 0.0]
pm = instantiate_mc_model(math, ACPUPowerModel, build_mc_opf);
pm.data["per_unit"] = false;
solution = optimize_model!(pm, optimizer=Ipopt.Optimizer)
x = length(pm.data["bus"])
y = length(pm.data["bus_lookup"])
#
#=
function generate_bus_map(pm)

    bus_map = Dict{Int, Any}()

    # Fill from pm.data["bus_lookup"]
    for (original_id, assigned_num) in pm.data["bus_lookup"]
        # In your format, the key is the assigned_num and value is the original_id
        bus_map[assigned_num] = original_id
    end

    # Add Substation or any other special entries
    # Assuming n + 1 is not in pm.data["bus_lookup"], we add it manually
    N_plus = length(pm.data["bus_lookup"]) + 1
    if !haskey(bus_map, N_plus)
        bus_map[N_plus] = "Substation"
    end

    return bus_map
end
bus_map = generate_bus_map(pm)

reverse_bus_map = Dict(value => key for (key, value) in bus_map)
=#