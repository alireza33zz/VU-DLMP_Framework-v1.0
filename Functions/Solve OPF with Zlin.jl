"""
Main function to solve OPF with custom constraints
"""

include("Balanced 3ph DER.jl");
include("PQ Curve.jl");
include("Bus_map.jl");


function solve_opf_with_Zlin(file_path::String, config::OPFConfig=default_config(), M::Float64=2.0, N::Float64=2.0)
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

    function generate_bus_map(pm)

        bus_map = Dict{Int, Any}()
        
        # Fill from pm.data["bus_lookup"]
        for (original_id, assigned_num) in pm.data["bus_lookup"]
            # In your format, the key is the assigned_num and value is the original_id
            bus_map[assigned_num] = original_id
        end        
        
        return bus_map
    end
    bus_map_zero = generate_bus_map(pm)
    
    reverse_bus_map_zero = Dict(value => key for (key, value) in bus_map_zero)
    
    # Add voltage magnitude constraints
    voltage_constraint = VoltageConstraint(config.v_upper_bound, config.v_lower_bound)
    add_voltage_constraints!(pm, voltage_constraint)

    # Add VUF constraint
    if VUF_STATUS
        vuf_constraint = VUFConstraint(config.VUF_level/100)
        Bus_ids_to_include = VUF_set_str2 #With DSS format
        included_buses_constraint = ([reverse_bus_map_zero[bus] for bus in Bus_ids_to_include])
        add_vuf_constraints!(pm, vuf_constraint, included_buses_constraint)
    end

    ensuring_balance_operation_of_3ph_DERs(math, pm);

    ensuring_PQ_curve_of_flexible_DERs!(pm);

    # Define the number of buses
    N_bus = length(pm.data["bus"])
    println("")
    println("Number of buses: ", N_bus)

# List of original bus IDs you want to include
Bus_ids_to_include = VUF_set_str2 #With DSS format
included_buses_Obj = ([reverse_bus_map_zero[bus] for bus in Bus_ids_to_include])


# 1. Introduce auxiliary variables for the absolute value terms
@variable(pm.model, diff1[bus=included_buses_Obj] >= 0)
@variable(pm.model, diff2[bus=included_buses_Obj] >= 0)
@variable(pm.model, diff3[bus=included_buses_Obj] >= 0)

# Add constraints to define the absolute differences
@constraint(pm.model, [bus=included_buses_Obj], diff1[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][1] - pm.var[:it][:pmd][:nw][0][:vm][bus][2])
@constraint(pm.model, [bus=included_buses_Obj], diff1[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][2] - pm.var[:it][:pmd][:nw][0][:vm][bus][1])

@constraint(pm.model, [bus=included_buses_Obj], diff2[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][2] - pm.var[:it][:pmd][:nw][0][:vm][bus][3])
@constraint(pm.model, [bus=included_buses_Obj], diff2[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][3] - pm.var[:it][:pmd][:nw][0][:vm][bus][2])

@constraint(pm.model, [bus=included_buses_Obj], diff3[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][3] - pm.var[:it][:pmd][:nw][0][:vm][bus][1])
@constraint(pm.model, [bus=included_buses_Obj], diff3[bus] >= pm.var[:it][:pmd][:nw][0][:vm][bus][1] - pm.var[:it][:pmd][:nw][0][:vm][bus][3])

# 2. Define the Xpression_Value using auxiliary variables
@expression(pm.model, Xpression_Value[bus=included_buses_Obj], 
    (diff1[bus] + diff2[bus] + diff3[bus]) / 6.928)

# 3. Use auxiliary variables for the division to avoid potential numerical issues
@variable(pm.model, z_over_p[bus=included_buses_Obj])

# 4. Average voltage magnitude expression across phases
@expression(pm.model, P_mag[bus=included_buses_Obj], 
    (pm.var[:it][:pmd][:nw][0][:vm][bus][1] + pm.var[:it][:pmd][:nw][0][:vm][bus][2] + pm.var[:it][:pmd][:nw][0][:vm][bus][3]) / 3)

# 5. Add constraints to linearize the division (z_over_p = Xpression_Value / P_mag)
# This requires P_mag to be bounded away from zero, which should be reasonable for voltage magnitudes
@constraint(pm.model, [bus=included_buses_Obj], z_over_p[bus] * P_mag[bus] == Xpression_Value[bus])

# 6. Define total_Zlin using the new auxiliary variables
@expression(pm.model, total_Zlin, sum(z_over_p[bus] * 100 for bus in included_buses_Obj))

# 7. Define the total cost
default_cost = JuMP.objective_function(pm.model)

# 8. Apply the combined objective function
JuMP.@objective(pm.model, Min, N * default_cost + M * total_Zlin)

    # Configure and run solver
    solver = configure_solver(config)
    solution = optimize_model!(pm, optimizer=solver)

    # Print formatted results
    print_formatted_results(solution, pm)
    print_dual_variables(pm)
    print_shadow_prices(pm)

    return solution, pm, format_results(solution, pm)
end
