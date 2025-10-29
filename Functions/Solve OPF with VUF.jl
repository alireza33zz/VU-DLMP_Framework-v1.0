"""
Main function to solve OPF with custom constraints
"""

include("Balanced 3ph DER.jl");
include("PQ Curve.jl");
include("Bus_map.jl");


function solve_opf_with_VUF(file_path::String, config::OPFConfig=default_config(), M::Float64=5.0, N::Float64=5.0)
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


    # Define phase angle shifts for positive and negative sequence components
    an = [0, -2π/3, 2π/3]  # Phase angle shifts for negative sequence
    ap = [0, 2π/3, -2π/3]  # Phase angle shifts for positive sequence

# Step 1: Break down the complex expressions into simpler components
# Define variables for real and imaginary parts of sequence components
@variable(pm.model, Vn_real[bus=included_buses_Obj])
@variable(pm.model, Vn_imag[bus=included_buses_Obj])
@variable(pm.model, Vp_real[bus=included_buses_Obj])
@variable(pm.model, Vp_imag[bus=included_buses_Obj])

# Step 2: Define the real and imaginary parts using linear expressions
for bus in included_buses_Obj
    # Negative sequence components
    @constraint(pm.model, Vn_real[bus] == sum(pm.var[:it][:pmd][:nw][0][:vm][bus][i] * cos(pm.var[:it][:pmd][:nw][0][:va][bus][i] + an[i]) for i in 1:3))
    @constraint(pm.model, Vn_imag[bus] == sum(pm.var[:it][:pmd][:nw][0][:vm][bus][i] * sin(pm.var[:it][:pmd][:nw][0][:va][bus][i] + an[i]) for i in 1:3))
    
    # Positive sequence components
    @constraint(pm.model, Vp_real[bus] == sum(pm.var[:it][:pmd][:nw][0][:vm][bus][i] * cos(pm.var[:it][:pmd][:nw][0][:va][bus][i] + ap[i]) for i in 1:3))
    @constraint(pm.model, Vp_imag[bus] == sum(pm.var[:it][:pmd][:nw][0][:vm][bus][i] * sin(pm.var[:it][:pmd][:nw][0][:va][bus][i] + ap[i]) for i in 1:3))
end

# Step 3: Define variables for the squared magnitudes of sequence components
@variable(pm.model, Vn2[bus=included_buses_Obj] >= 0)
@variable(pm.model, Vp2[bus=included_buses_Obj] >= 0)

# Step 4: Add constraints to define the squared magnitudes using second-order cone constraints
for bus in included_buses_Obj
    @constraint(pm.model, Vn2[bus] == Vn_real[bus]^2 + Vn_imag[bus]^2)
    @constraint(pm.model, Vp2[bus] == Vp_real[bus]^2 + Vp_imag[bus]^2)
end

# Step 5: Add a constraint to ensure Vp2 is bounded away from zero
@constraint(pm.model, [bus=included_buses_Obj], Vp2[bus] >= 0.01)  # Adjust this value based on your system

# Step 6: Define a variable for the VUF ratio
@variable(pm.model, vuf_ratio[bus=included_buses_Obj] >= 0)

# Step 7: Define the relationship between vuf_ratio, Vn2, and Vp2
for bus in included_buses_Obj
    @constraint(pm.model, vuf_ratio[bus] * Vp2[bus] == Vn2[bus])
end

# Step 8: Define the total VUF cost using the new variables
@expression(pm.model, cost_VUF, sum(vuf_ratio[bus] * 10000 for bus in included_buses_Obj))

# Step 9: Define the total cost
default_cost = JuMP.objective_function(pm.model)

# Step 10: Apply the combined objective function
JuMP.@objective(pm.model, Min, N * default_cost + M^2 * cost_VUF)

    # Configure and run solver
    solver = configure_solver(config)
    solution = optimize_model!(pm, optimizer=solver)

    # Print formatted results
    print_formatted_results(solution, pm)
    print_dual_variables(pm)
    print_shadow_prices(pm)

    return solution, pm, format_results(solution, pm)
end