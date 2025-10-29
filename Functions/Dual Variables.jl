include("Bus_map.jl");

function print_dual_variables(pm)
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


    println("\n=== Dual Variables ===")
    println("")
    # Print dual variables for voltage magnitude constraints
    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")
    function parse_or_keep(s::AbstractString)
        num = tryparse(Int, s)
        return isnothing(num) ? s : num
    end
    println("Voltage Magnitude Constraints:")
    for i in VUF_set_str2
        j = reverse_bus_map_zero[i]
        for phase in 1:3
            constraint = pm.model[:voltage_constraints][(j, phase)]
            dual_value = round(JuMP.dual(constraint), digits=3)
            phase_name = phase_map[phase]
            if PRINT_PERMISSION_personal
                if phase == 1 
                    print("Bus $i, Phase $phase_name: Dual Value = $dual_value")
                elseif phase == 2
                    print("   Phase $phase_name: Dual Value = $dual_value")
                elseif phase == 3
                    println("   Phase $phase_name: Dual Value = $dual_value")
                end
            end
        end
    end
    if VUF_STATUS
    # Print dual variables for VUF constraints
    println("\nVoltage Unbalance Factor (VUF) Constraints:")
    for i in VUF_set_str2
        j = reverse_bus_map_zero[i]
        constraint = pm.model[:vuf_constraints][j]
        dual_value = round(JuMP.dual(constraint), digits=3)
        if PRINT_PERMISSION_personal
            println("Bus $i: Dual Value = $dual_value")
        end
    end
    #
    end
    
    # Print dual variables for Pg variables
    println("\nActive Power Generation (Pg) of DERs:")
    for (gen_id, dense_array) in pm.var[:it][:pmd][:nw][0][:pg]
        for idx in eachindex(dense_array)
            variable = dense_array[idx]
            if variable isa JuMP.VariableRef && JuMP.has_upper_bound(variable)
                dual_value = round(JuMP.dual(JuMP.UpperBoundRef(variable)), digits=3)
                if PRINT_PERMISSION_personal
                    println("Generator $gen_id, Pg = $dual_value")
                end
            end
        end
    end
end