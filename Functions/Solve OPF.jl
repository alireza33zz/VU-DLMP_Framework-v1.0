"""
Main function to solve OPF with custom constraints
"""

include("Balanced 3ph DER.jl");
include("PQ Curve.jl");
include("Bus_map.jl");

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
    # Add bus map (DSS-PMD)
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

    # Configure and run solver
    solver = configure_solver(config)
    solution = optimize_model!(pm, optimizer=solver)

    # Print formatted results
    print_formatted_results(solution, pm)
    print_dual_variables(pm)
    print_shadow_prices(pm)

    return solution, pm, format_results(solution, pm)
end