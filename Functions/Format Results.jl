"""
Extract and format key results from the OPF solution with VUF
"""
    
using DataFrames
using Statistics
using Plots, StatsPlots
using Plots.PlotMeasures

include("Bus_map.jl");

function format_results(solution::Dict, pm)
    # Initialize DataFrame for bus results
    results_df = DataFrame(
        bus_id = String[],
        phase = String[],  # Change to String[]
        vm_pu = Float64[],
        va_deg = Float64[],
        vuf_percent = Float64[],
        Zlin_percent = Float64[],
        error = Float64[]
    )
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
    # println("bus_map_zero: ", bus_map_zero)
    reverse_bus_map_zero = Dict(value => key for (key, value) in bus_map_zero)
    # println("reverse_bus_map_zero: ", reverse_bus_map_zero)
    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")

# Extract bus results for the chosen buses
# vcat(VUF_set_str2, print_55_chosen_str)
#for bus_id in VUF_set_str2
for bus_id in Just_plot
    bus_id2= string(reverse_bus_map_zero[bus_id])
    if haskey(solution["solution"]["bus"], bus_id2)
        bus = solution["solution"]["bus"][bus_id2]

        # Collect voltage magnitudes and angles for this bus
        vm = bus["vm"]
        va = bus["va"] * (180/π)  # Convert to degrees for readability

# Calculate vuf and Zlin
vuf, Zlin = calculate_vuf(bus["vm"], bus["va"])

        # Add rows to DataFrame
        for phase in 1:3
            push!(results_df, (
                get(bus_map_str, bus_id, "O.N."),
                phase_map[phase],  # Use the phase mapping
                round(vm[phase], digits=3),
                round(va[phase], digits=1),
                round(vuf, digits=3),
                round(Zlin, digits=3),
                round(Zlin - vuf, digits=3)  # Calculate error    
            ))
        end
    end
end



function custom_bus_id_sort(df::DataFrame)
    # Define a custom sorting order
    function bus_id_sorter(x::String)
        # Put "sourcebus" and "substation" first
        if x == "sourcebus"
            return (0, x)
        elseif x == "substation"
            return (1, x)
        else
            # Try to extract numeric part for the rest
            numeric_part = tryparse(Int, x)
            if numeric_part !== nothing
                return (2, numeric_part)
            else
                # For any non-numeric strings, sort them alphabetically after numbers
                return (3, x)
            end
        end
    end
    
    # Sort the DataFrame using the custom sorting function
    sort!(df, [:bus_id], by=bus_id_sorter)
    
    return df
end

# Example usage:
# results_df = DataFrame(bus_id = ["10", "1", "sourcebus", "2", "substation", "21"])
sorted_df = custom_bus_id_sort(results_df)
    
    return sorted_df
end