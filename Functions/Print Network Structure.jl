# using Plots
using PlotUtils  # Necessary for calculating optimized ticks
include("Bus_map.jl")

function print_network_structure(solution::Dict, pm)

            # Create output directory if it doesn't exist
            if VUF_STATUS
                output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\With VUF Constraint"
            else
                output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\Without VUF Constraint"
            end
            mkpath(output_dir)
    
            combined_ext = @isdefined(combined_extension) ? combined_extension : ""
            separate_ext = @isdefined(separate_extension) ? separate_extension : ""

    println("\n=================================================================================")
    println("Complete report:")

    #= Print bus information with translated names
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
    =#
    # Create a reverse lookup to get original bus IDs from assigned numbers
    reverse_bus_lookup = Dict{Int, String}()
    for (original_id, assigned_num) in pm.data["bus_lookup"]
        reverse_bus_lookup[assigned_num] = original_id
    end
    #println("Bus IDs: ", reverse_bus_lookup)

# Generator code with updated bus name handling
println("\nGenerators:")

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

# Data for plotting
gen_data = Dict{String, Dict{String, Vector{Float64}}}()

# Initialize total cost and total_pg
total_cost = 0.0
total_pg = 0.0

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
            pg_bus = round.(get(sol_gen, "pg_bus", "Not found"), digits=3)
            qg_bus = round.(get(sol_gen, "qg_bus", "Not found"), digits=3)
            
            print("    pg: ", pg_bus)
            print("    qg: ", qg_bus)
            
            # Calculate apparent power
            if pg_bus != "Not found" && qg_bus != "Not found"
                s_bus = sqrt.(pg_bus.^2 + qg_bus.^2)
                println("    s: ", round.(s_bus, digits=3))
                
                # Accumulate total_pg (assuming pg_bus is an array of generation values)
                total_pg += sum(pg_bus)
                
                # Calculate generation cost only if generator is producing power
                if haskey(gen, "cost") && pg_bus != "Not found"
                    cost_coeffs = gen["cost"]
                    if length(cost_coeffs) == 2
                        a = cost_coeffs[1]
                        b = cost_coeffs[2]
                        
                        # Check if generator is on (producing power)
                        gen_cost = 0.0
                        for i in 1:length(pg_bus)
                            if (pg_bus[i] > 0.0001) || (qg_bus[i] > 0.0001) # Small tolerance for floating point
                                gen_cost += a * pg_bus[i] + ( b/3 )
                            end
                        end
                        
                        println("    cost: ", round(gen_cost, digits=2))
                        total_cost += gen_cost
                    end
                end
            end

            # Collect data for plotting
            if !haskey(gen_data, original_bus_id)
                gen_data[original_bus_id] = Dict("pg" => Float64[], "qg" => Float64[], "s" => Float64[])
            end

            for i in 1:length(pg_bus)
                push!(gen_data[original_bus_id]["pg"], pg_bus[i])
                push!(gen_data[original_bus_id]["qg"], qg_bus[i])
                push!(gen_data[original_bus_id]["s"], s_bus[i])
            end
        else
            println("    No solution data found for this generator")
        end
    end
end

combined_filename_report = joinpath(output_dir, "report$(combined_ext).txt")
# --- Print total generation cost in blue and additional cost info ---
# --- Prepare messages for costs ---
line1 = "\nTotal Generation Cost: \$$(round(total_cost, digits=3))\n"
line2 = "The additional cost rather than hard constraint is: $(round(total_cost - OPF_result_with_hard, digits=3))\n"
line3 = "The additional cost rather than hard constraint is: $(round(( (total_cost - OPF_result_with_hard) / OPF_result_with_hard * 100 ), digits=2))%\n"
line4 = "The additional cost rather than no constraint is: $(round(total_cost - OPF_result_without_hard, digits=3))\n"
line5 = "The additional cost rather than no constraint is: $(round(( (total_cost - OPF_result_without_hard) / OPF_result_without_hard * 100 ), digits=2))%\n"

# --- Calculate total load and losses ---
total_pl = sum(sum(load["pd"]) for (load_id, load) in pm.data["load"])
losses = total_pg - total_pl

# --- Prepare messages for power values ---
line6 = "\nTotal Pg: $(round(total_pg, digits=3)) kW\n"
line7 = "Total Pl: $(round(total_pl, digits=3)) kW\n"
line8 = "Total Losses (Pg - Pl): $(round(losses, digits=3)) kW\n"

# --- Write to file and print with styling ---
open(combined_filename_report, "w") do file
    # Print and save cost information
    printstyled(line1, color=:blue)
    print(file, line1)

    printstyled(line2, color=:red)
    print(file, line2)

    printstyled(line3, color=:red)
    print(file, line3)

    printstyled(line4, color=:yellow)
    print(file, line4)

    printstyled(line5, color=:yellow)
    print(file, line5)

    # Print and save power information
    printstyled(line6, color=:green)
    print(file, line6)

    printstyled(line7, color=:blue)
    print(file, line7)

    printstyled(line8, color=:magenta)
    print(file, line8)
end

# Calculate total load for each phase
phase_loads = Dict("a" => 0.0, "b" => 0.0, "c" => 0.0)

for (load_id, load) in pm.data["load"]
    # Get load values and connections
    pd = load["pd"]
    connections = load["connections"]

    # Iterate through connections to accumulate phase-specific loads
    for (i, phase_num) in enumerate(connections)
        phase_name = ["a", "b", "c"][phase_num]
        phase_loads[phase_name] += pd[i]
    end
end

# Print or use phase-specific loads
printstyled("\nTotal Load Phase a: ", round(phase_loads["a"], digits=3), " kW", "\n", color=:blue)
printstyled("Total Load Phase b: ", round(phase_loads["b"], digits=3), " kW", "\n", color=:yellow)
printstyled("Total Load Phase c: ", round(phase_loads["c"], digits=3), " kW", "\n", color=:red)



# --- Loads Section ---
println("\nLoads:")

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

# Data for plotting
load_data = Dict{String, Dict{String, Vector{Float64}}}()

for bus in sorted_buses
    # Get the original bus ID from the assigned number
    original_bus_id = get(reverse_bus_lookup, bus, "Substation")  # Changed from "Unknown" to "Substation"

    if PRINT_PERMISSION_personal
        println("Bus $original_bus_id:")
    end
 
    # Sort loads by phase (connections)
    bus_loads = loads_by_bus[bus]
    sort!(bus_loads, by = x -> minimum(x[2]["connections"]))
    
    for (load_id, load) in bus_loads
        phases = load["connections"]
        phase_names = ["a", "b", "c"]
        phase_str = join([phase_names[p] for p in phases], ",")
        
        if PRINT_PERMISSION_personal
            println("Phase(s): $phase_str")
        end

        pd = load["pd"]
        qd = load["qd"]

        if PRINT_PERMISSION_personal
            print("    pd: ", round.(pd, digits=3))
            print("    qd: ", round.(qd, digits=3))
        end
        # Calculate apparent power
        if length(pd) == length(qd)
            s = sqrt.(pd.^2 + qd.^2)
            
            if PRINT_PERMISSION_personal
                println("    s: ", round.(s, digits=3))
            end
        end

        # Collect data for plotting
        if !haskey(load_data, original_bus_id)
            load_data[original_bus_id] = Dict("pd" => Float64[], "qd" => Float64[], "s" => Float64[])
        end

        for i in 1:length(pd)
            push!(load_data[original_bus_id]["pd"], pd[i])
            push!(load_data[original_bus_id]["qd"], qd[i])
            push!(load_data[original_bus_id]["s"], s[i])
        end
    end
end

    # Assuming load_data and the rest of your code above is already executed
    # We need to extract and organize the data for plotting

    # Initialize data structures
    bus_numbers = String[]
    phase_a_pd = Float64[]
    phase_b_pd = Float64[]
    phase_c_pd = Float64[]
    phase_a_qd = Float64[]
    phase_b_qd = Float64[]
    phase_c_qd = Float64[]

    # Extract and organize load data by bus and phase
    for bus in sorted_buses
        original_bus_id = get(reverse_bus_lookup, bus, "Substation")
        
        # Get all loads for this bus
        bus_loads = loads_by_bus[bus]
        
        # Initialize phase values for this bus (default to 0 for bar plots)
        a_pd, b_pd, c_pd = 0.0, 0.0, 0.0
        a_qd, b_qd, c_qd = 0.0, 0.0, 0.0
        
        for (load_id, load) in bus_loads
            phases = load["connections"]
            pd = load["pd"]
            qd = load["qd"]
            
            # Map the values to the corresponding phases
            for (i, phase) in enumerate(phases)
                if phase == 1  # Phase a
                    a_pd = pd[i]
                    a_qd = qd[i]
                elseif phase == 2  # Phase b
                    b_pd = pd[i]
                    b_qd = qd[i]
                elseif phase == 3  # Phase c
                    c_pd = pd[i]
                    c_qd = qd[i]
                end
            end
        end
        
        # Add the data to our vectors
        push!(bus_numbers, original_bus_id)
        push!(phase_a_pd, a_pd)
        push!(phase_b_pd, b_pd)
        push!(phase_c_pd, c_pd)
        push!(phase_a_qd, a_qd)
        push!(phase_b_qd, b_qd)
        push!(phase_c_qd, c_qd)
    end

    # Convert bus_numbers to positions for x-axis
    load_numbers = [bus_map_str[bus] for bus in bus_numbers]
    
    # Convert load_numbers to integers so that sorting is numerical
    load_numbers_int = parse.(Int, load_numbers)

    # Get the permutation indices that would sort load_numbers_int in ascending order
    perm = sortperm(load_numbers_int)

    # Use the permutation to reorder all your arrays
    bus_numbers = bus_numbers[perm]
    load_numbers = load_numbers[perm]  # if you plan to use these as x labels

    phase_a_pd = phase_a_pd[perm]
    phase_b_pd = phase_b_pd[perm]
    phase_c_pd = phase_c_pd[perm]

    phase_a_qd = phase_a_qd[perm]
    phase_b_qd = phase_b_qd[perm]
    phase_c_qd = phase_c_qd[perm]

    # Recalculate x positions and custom xticks based on the new sorted order
    x_positions = 1:length(bus_numbers)
    custom_xticks = (x_positions, load_numbers)

    # Calculate bar positions (grouped bars for each phase)
    bar_width = 0.25
    x_a = x_positions .- (bar_width*1.1)
    x_b = x_positions
    x_c = x_positions .+ (bar_width*1.1)

    # Create the active power (pd) plot
    p1L = plot(
        #title = "Active Power",
        xlabel = "Load Number",
        ylabel = "Active Power (kW)",
        legend = :outertop,
        legend_columns = 3,
        legendfontsize = 14,  # Increase legend font size
        size = (25*length(bus_numbers), 15*length(bus_numbers)),
        dpi = 300,
        opacity = 0.5,
        xticks = custom_xticks,
        margin = 20Plots.px,
        xrotation = -90,
        xtickfontsize = 14,   # Increase x-axis tick label font size
        ytickfontsize = 14,    # Increase y-axis tick label font size
        xlabelfontsize = 16,  # Increase x-axis label font size
        ylabelfontsize = 16   # Increase y-axis label font size
    )

    # Plot each phase with different colors as bars
    bar!(p1L, x_a, phase_a_pd, color = :blue, bar_width = bar_width, label = "Phase a")
    bar!(p1L, x_b, phase_b_pd, color = :green, bar_width = bar_width, label = "Phase b")
    bar!(p1L, x_c, phase_c_pd, color = :red, bar_width = bar_width, label = "Phase c")

    # Create the reactive power (qd) plot
    p2L = plot(
        #title = "Reactive Power",
        xlabel = "Load Number",
        ylabel = "Reactive Power (kVAR)",
        legend = :outertop,
        legend_columns = 3,
        legendfontsize = 14,  # Increase legend font size
        size = (25*length(bus_numbers), 15*length(bus_numbers)),
        dpi = 300,
        opacity = 0.5,
        xticks = custom_xticks,
        margin = 20Plots.px,
        xrotation = -90,
        xtickfontsize = 14,   # Increase x-axis tick label font size
        ytickfontsize = 14,    # Increase y-axis tick label font size
        xlabelfontsize = 16,  # Increase x-axis label font size
        ylabelfontsize = 16   # Increase y-axis label font size

    )

    # Plot each phase with different colors as bars
    bar!(p2L, x_a, phase_a_qd, color = :blue, bar_width = bar_width, label = "Phase a")
    bar!(p2L, x_b, phase_b_qd, color = :green, bar_width = bar_width, label = "Phase b")
    bar!(p2L, x_c, phase_c_qd, color = :red, bar_width = bar_width, label = "Phase c")


    # We need to extract and organize the generator data for plotting
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

    # Initialize data structures
    gen_bus_numbers = String[]
    gen_phase_a_pg = Float64[]
    gen_phase_b_pg = Float64[]
    gen_phase_c_pg = Float64[]
    gen_phase_a_qg = Float64[]
    gen_phase_b_qg = Float64[]
    gen_phase_c_qg = Float64[]

    # Extract and organize generator data by bus and phase
    for bus in sorted_buses
        original_bus_id = get(reverse_bus_lookup, bus, "Feeder")
        
        # Get all generators for this bus
        bus_gens = gens_by_bus[bus]
        
        # Initialize phase values for this bus (default to 0 for bar plots)
        a_pg, b_pg, c_pg = 0.0, 0.0, 0.0
        a_qg, b_qg, c_qg = 0.0, 0.0, 0.0
        
        for (gen_id, gen) in bus_gens
            phases = gen["connections"]
            
            # Get pg and qg values from solution dictionary
            if haskey(solution["solution"]["gen"], gen_id)
                sol_gen = solution["solution"]["gen"][gen_id]
                pg_bus = get(sol_gen, "pg_bus", [0.0])
                qg_bus = get(sol_gen, "qg_bus", [0.0])
                
                # Map the values to the corresponding phases
                for (i, phase) in enumerate(phases)
                    if phase == 1  # Phase a
                        a_pg = pg_bus[i]
                        a_qg = qg_bus[i]
                    elseif phase == 2  # Phase b
                        b_pg = pg_bus[i]
                        b_qg = qg_bus[i]
                    elseif phase == 3  # Phase c
                        c_pg = pg_bus[i]
                        c_qg = qg_bus[i]
                    end
                end
            end
        end
        
        # Add the data to our vectors
        push!(gen_bus_numbers, original_bus_id)
        push!(gen_phase_a_pg, a_pg)
        push!(gen_phase_b_pg, b_pg)
        push!(gen_phase_c_pg, c_pg)
        push!(gen_phase_a_qg, a_qg)
        push!(gen_phase_b_qg, b_qg)
        push!(gen_phase_c_qg, c_qg)
    end

    # Convert bus_numbers to positions for x-axis
    x_positions = 1:length(gen_bus_numbers)
    if length(gen_bus_numbers) == 1
        custom_xticks = ["Feeder"]
    else
        custom_xticks = ["PV1","PV8","PV6","PV10","PV4","PV2","PV3","PV11","PV14","G1",
                         "G2","PV7","PV13","G3","PV9","PV12","PV5","Feeder"]
    end
    # Calculate bar positions (grouped bars for each phase)
    bar_width = 0.25
    x_a = x_positions .- (bar_width*1.1)
    x_b = x_positions
    x_c = x_positions .+ (bar_width*1.1)

    # Combine all generator power data to compute the range
    gen_pg_data = vcat(gen_phase_a_pg, gen_phase_b_pg, gen_phase_c_pg)
    data_min = minimum(gen_pg_data)
    data_max = maximum(gen_pg_data)
    y_upper = ceil(data_max)
    
    # Extend the y-axis limits to include 2.5 and 7
    y_min = min(data_min, 7.5, 18.0)
    y_max = max(data_max, 7.5, 18.0)
    
    # Calculate optimized ticks for the extended range and add desired values
    ticks = PlotUtils.optimize_ticks(y_min, y_max)[1]
    new_ticks = sort(unique(vcat(ticks, [7.5, 18.0, y_upper])))
    
    # Create the plot with adjusted y-axis settings
    p1G = plot(
        title = "Generators Active Power by Bus and Phase",
        xlabel = "Bus Name",
        ylabel = "Active Power (kW)",
        legend_columns = 3,
        gridalpha=0.7,
        legend = :outertop,
        size = (25*length(bus_numbers), 15*length(bus_numbers)),
        dpi = 300,
        xticks = (x_positions, custom_xticks),
        margin = 20Plots.px,
        xrotation = 0,
        ylims = (0, y_upper),
        yticks = new_ticks       # Set ticks explicitly
    )
    
    # Plot each phase with different colors as bars
    bar!(p1G, x_a, gen_phase_a_pg, color = :red, bar_width = bar_width, label = "Phase a")
    bar!(p1G, x_b, gen_phase_b_pg, color = :blue, bar_width = bar_width, label = "Phase b")
    bar!(p1G, x_c, gen_phase_c_pg, color = :green, bar_width = bar_width, label = "Phase c")

    # Combine all generator power data to compute the range
    gen_qg_data = vcat(gen_phase_a_qg, gen_phase_b_qg, gen_phase_c_qg)
    data_min = minimum(gen_qg_data)
    data_max = maximum(gen_qg_data)
    y_upper = ceil(data_max)
        
        # Extend the y-axis limits to include 2.5 and 7
    y_min = min(data_min, 10.0, 14.0)
    y_max = max(data_max, 10.0, 14.0)
        
    # Calculate optimized ticks for the extended range and add desired values
    ticks = PlotUtils.optimize_ticks(y_min, y_max)[1]
    new_ticks = sort(unique(vcat(ticks, [10.0, 14.0, y_upper])))

    # Create the plot with adjusted y-axis settings
    p2G = plot(
        title = "Generators Reactive Power by Bus and Phase",
        xlabel = "Bus Name",
        ylabel = "Reactive Power (kVAR)",
        legend_columns = 3,
        gridalpha=0.7,
        legend = :outertop,
        size = (25*length(bus_numbers), 15*length(bus_numbers)),
        dpi = 300,
        xticks = (x_positions, custom_xticks),
        margin = 20Plots.px,
        xrotation = 0,
        ylims = (0, y_upper),  # Extend limits to include 2.5 and 7
        yticks = new_ticks       # Set ticks explicitly
    )

    # Plot each phase with different colors as bars
    bar!(p2G, x_a, gen_phase_a_qg, color = :red, bar_width = bar_width, label = "Phase a")
    bar!(p2G, x_b, gen_phase_b_qg, color = :blue, bar_width = bar_width, label = "Phase b")
    bar!(p2G, x_c, gen_phase_c_qg, color = :green, bar_width = bar_width, label = "Phase c")

    # Display the plots
    if PLOT_DISPLAY
        display(p1L)
        display(p2L)
        display(p1G)
        display(p2G)
    end



    if SAVING_FIGURES_STATUS
        combined_filename_pG = joinpath(output_dir, "Generators_output$(combined_ext)PG.svg")
        savefig(p1G, combined_filename_pG)
        println("Generators output plot saved to: $combined_filename_pG")
        combined_filename_qG = joinpath(output_dir, "Generators_output$(combined_ext)QG.svg")
        savefig(p2G, combined_filename_qG)
        println("Generators output plot saved to: $combined_filename_qG")
        combined_filename_pL = joinpath(output_dir, "Loads_consumption$(combined_ext)PL.svg")
        savefig(p1L, combined_filename_pL)
        println("Loads consumption plot saved to: $combined_filename_pL")
        combined_filename_qL = joinpath(output_dir, "Loads_consumption$(combined_ext)QL.svg")
        savefig(p2L, combined_filename_qL)
        println("Loads consumption plot saved to: $combined_filename_qL")
    end


    #= Plotting
    # Create output directory if it doesn't exist
        if VUF_STATUS
            output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\With VUF Constraint"
        else
            output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\Without VUF Constraint"
        end
        mkpath(output_dir)

        combined_ext = @isdefined(combined_extension) ? combined_extension : ""
        separate_ext = @isdefined(separate_extension) ? separate_extension : ""

    # Plot generator data
    bus_ids = ["Substation"]
    append!(bus_ids, string.(sort(collect(keys(reverse_bus_lookup)))))

    # Prepare data for plotting
    phase_labels = ["a", "b", "c"]
    phase_offsets = [-0.2, 0.0, 0.2]  # Offsets for phases a, b, c

    # Define consistent colors for S, P, Q
    colors = Dict("S" => :blue, "P" => :yellow, "Q" => :red)

    # Generator data
    pg_values = Dict{String, Vector{Float64}}()
    qg_values = Dict{String, Vector{Float64}}()
    s_values = Dict{String, Vector{Float64}}()

    for phase in phase_labels
        pg_values[phase] = []
        qg_values[phase] = []
        s_values[phase] = []
    end

    for bus_id in bus_ids
        if haskey(gen_data, bus_id)
            for (i, phase) in enumerate(phase_labels)
                push!(pg_values[phase], sum(gen_data[bus_id]["pg"][i:3:end]))
                push!(qg_values[phase], sum(gen_data[bus_id]["qg"][i:3:end]))
                push!(s_values[phase], sum(gen_data[bus_id]["s"][i:3:end]))
            end
        else
            for phase in phase_labels
                push!(pg_values[phase], 0.0)
                push!(qg_values[phase], 0.0)
                push!(s_values[phase], 0.0)
            end
        end
    end

    # Plot generator data
    p = plot(size = (600, 400), dpi = 300)
    x_positions = 1:length(bus_ids)  # Numerical x-axis positions
    for (i, phase) in enumerate(phase_labels)
        # Plot S, P, Q with consistent colors
        bar!(p, x_positions .+ phase_offsets[i], s_values[phase], 
             label=(i == 1 ? "S" : ""), color=colors["S"], bar_width=0.2, alpha=1.0)
        bar!(p, x_positions .+ phase_offsets[i], pg_values[phase], 
             label=(i == 1 ? "P" : ""), color=colors["P"], bar_width=0.2, alpha=1.0)
        bar!(p, x_positions .+ phase_offsets[i], qg_values[phase], 
             label=(i == 1 ? "Q" : ""), color=colors["Q"], bar_width=0.2, alpha=1.0)
    end
    xticks!(x_positions, bus_ids)  # Set x-tick labels to bus IDs
    xlabel!("Bus")
    ylabel!("Power (kVA)")
    title!("Generator Output by Bus and Phase")

    # Load data
    pd_values = Dict{String, Vector{Float64}}()
    qd_values = Dict{String, Vector{Float64}}()
    s_values = Dict{String, Vector{Float64}}()

    for phase in phase_labels
        pd_values[phase] = []
        qd_values[phase] = []
        s_values[phase] = []
    end

    for bus_id in bus_ids
        if haskey(load_data, bus_id)
            for (i, phase) in enumerate(phase_labels)
                push!(pd_values[phase], sum(load_data[bus_id]["pd"][i:3:end]))
                push!(qd_values[phase], sum(load_data[bus_id]["qd"][i:3:end]))
                push!(s_values[phase], sum(load_data[bus_id]["s"][i:3:end]))
            end
        else
            for phase in phase_labels
                push!(pd_values[phase], 0.0)
                push!(qd_values[phase], 0.0)
                push!(s_values[phase], 0.0)
            end
        end
    end

    # Plot load data
    pl = plot(size = (2000, 800), dpi = 300)  # Increased width and height
    x_positions = 1:length(bus_ids)
    phase_offsets = [-0.25, 0.0, 0.25]  # Adjusted offsets for better spacing
    bar_width = 0.15  # Narrower bars to fit more buses

    for (i, phase) in enumerate(phase_labels)
        # Plot S, P, Q with consistent colors
        bar!(pl, x_positions .+ phase_offsets[i], s_values[phase], 
            label=(i == 1 ? "S" : ""), color=colors["S"], bar_width=bar_width, alpha=1.0)
        bar!(pl, x_positions .+ phase_offsets[i], pd_values[phase], 
            label=(i == 1 ? "P" : ""), color=colors["P"], bar_width=bar_width, alpha=1.0)
        bar!(pl, x_positions .+ phase_offsets[i], qd_values[phase], 
            label=(i == 1 ? "Q" : ""), color=colors["Q"], bar_width=bar_width, alpha=1.0)
    end

    # Rotate x-ticks and set labels
    plot!(pl, xticks=(x_positions, bus_ids), xrotation=45, xlabel="Bus", ylabel="Power (kVA)")
    title!("Load Consumption by Bus and Phase")

    if SAVING_FIGURES_STATUS
        combined_filename_G = joinpath(output_dir, "Generators_output$(combined_ext).png")
        savefig(p, combined_filename_G)
        println("Generators output plot saved to: $combined_filename_G")
        combined_filename_L = joinpath(output_dir, "Loads_consumption$(combined_ext).png")
        savefig(pl, combined_filename_L)
        println("Loads consumption plot saved to: $combined_filename_L")
    end

    # Display plots
    if PLOT_DISPLAY
        display(p)
        display(pl)
    end
    =#
end