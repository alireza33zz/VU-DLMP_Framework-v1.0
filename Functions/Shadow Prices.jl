using Plots, Plots.PlotMeasures
using StatsPlots
using Printf

gr()

include("Bus_map.jl");

"""
Retrieve, print, and plot shadow prices, then save plots as high-quality PNG files
File extensions are taken from global variables defined in the main scope
"""
function print_shadow_prices(pm)
    # Create output directory if it doesn't exist
    if VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\With VUF Constraint"
    mkpath(output_dir)
    elseif !VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\Without VUF Constraint"
    mkpath(output_dir)
    end

    # Access global variables for file extensions
    # If they're not defined, use default names
    combined_ext = @isdefined(combined_extension) ? combined_extension : ""
    separate_ext = @isdefined(separate_extension) ? separate_extension : ""
    
    println("\n=== Shadow Prices ===")
    println("")

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

    phase_map = Dict(1 => "a", 2 => "b", 3 => "c")
    marker_map = Dict(1 => :circle, 2 => :square, 3 => :diamond)
    
    # Create data structures to store shadow prices for plotting
    bus_numbers = print_55_chosen_str[1:55]
    
    # Initialize data structures for plotting
    active_shadow_prices = Dict(phase => Float64[] for phase in 1:3)
    reactive_shadow_prices = Dict(phase => Float64[] for phase in 1:3)
    buses = Any[]
    
    # Print shadow prices for the P balance constraints
    println("Active Power Balance Constraints:")
    for j in bus_numbers
        k = reverse_bus_map_zero[j]
        i = bus_map_str[j]
        push!(buses, i)
        for phase in 1:3
            constraint = pm.con[:it][:pmd][:nw][0][:lam_kcl_r][k][phase]
            dual_value = -round(JuMP.dual(constraint), digits=3)
            plot_value = dual_value  # Negate the value for plotting
            phase_name = phase_map[phase]
            # Print the dual value for each phase
            if PRINT_PERMISSION_personal == true
                if phase == 1 
                    print("Load $i, Phase $phase_name: $dual_value")
                elseif phase == 2
                    print("   Phase $phase_name: $dual_value")
                elseif phase == 3
                    println("   Phase $phase_name: $dual_value")
                end
            end
            # Store the plot value in the corresponding phase array
            push!(active_shadow_prices[phase], plot_value)
        end
    end
    
    println("")
    # Print shadow prices for the Q balance constraints
    println("Reactive Power Balance Constraints:")
    for j in bus_numbers
        k = reverse_bus_map_zero[j]
        i = bus_map_str[j]
        for phase in 1:3
            constraint = pm.con[:it][:pmd][:nw][0][:lam_kcl_i][k][phase]
            dual_value = -round(JuMP.dual(constraint), digits=3)
            plot_value = dual_value  # Negate the value for plotting
            phase_name = phase_map[phase]
            # Print the dual value for each phase
            if PRINT_PERMISSION_personal == true
                if phase == 1 
                    print("Load $i, Phase $phase_name: $dual_value")
                elseif phase == 2
                    print("   Phase $phase_name: $dual_value")
                elseif phase == 3
                    println("   Phase $phase_name: $dual_value")
                end
            end
            # Store the plot value in the corresponding phase array
            push!(reactive_shadow_prices[phase], plot_value)
        end
    end

    # Define a color map for the phases
    color_map = Dict(1 => :blue, 2 => :green, 3 => :red)

    function custom_bus_sort(buses)
        # Function to determine sorting priority
        function bus_sorter(x::String)
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
        
        # Sort the buses
        sorted_indices = sortperm(buses, by=bus_sorter)
        
        return buses[sorted_indices], sorted_indices
    end
    
    # Sorting buses
    buses_adjusted, sorted_indices = custom_bus_sort(buses)

# Adjust active shadow prices to match the new order of buses
active_shadow_prices_adjusted = [active_shadow_prices[phase][sorted_indices] for phase in 1:3]

# Adjust reactive shadow prices to match the new order of buses
reactive_shadow_prices_adjusted = [reactive_shadow_prices[phase][sorted_indices] for phase in 1:3]

    custom_xticks = ([1, 12, 17, 32, 55].-0.5, ["1", "12", "17", "32", "55"])
    X_degree = 0 # Degree of rotation for x-axis labels
    # VERSION 1: Create a single plot for all data with improved margins
    shadow_price_plot = plot(
        title = "Shadow Prices (€/kVA)",
        xlabel = "Load Number",
        ylabel = "Shadow Price",
        legend = :outerbottom,
        legend_columns = 3,
        legendfontsize=14,
        grid = true,                # Turn on grid lines
        gridcolor = :black,         # Set grid line color
        gridalpha = 0.7,             # Set grid line transparency,
        size = (1400, 800),
        dpi = 300,
        margin = 20Plots.px,     # Add margin to keep labels inside figure
        bottom_margin = 30Plots.px, # Extra margin for x-axis label
        left_margin = 20Plots.px,    # Extra margin for y-axis label
        xticks=custom_xticks,
        xrotation= X_degree,  # Rotate x-axis labels for better readability
        xtickfontsize = 14,   # Increase x-axis tick label font size
        ytickfontsize = 14,    # Increase y-axis tick label font size
        xlabelfontsize = 16,  # Increase x-axis label font size
        ylabelfontsize = 16    # Increase y-axis label font size
    )

# Plot lines for active power
for phase in 1:3
    phase_name = phase_map[phase]
    plot!(shadow_price_plot, buses_adjusted, active_shadow_prices_adjusted[phase], 
        label = "Active Power Phase $phase_name", 
        marker = marker_map[phase], 
        linestyle = :solid, 
        linewidth = 2,
        color = color_map[phase])
end

# Plot lines for reactive power
for phase in 1:3
    phase_name = phase_map[phase]
    plot!(shadow_price_plot, buses_adjusted, reactive_shadow_prices_adjusted[phase], 
        label = "Reactive Power Phase $phase_name", 
        marker = marker_map[phase], 
        linestyle = :dot, 
        linewidth = 2,
        color = color_map[phase])
end

    if SAVING_FIGURES_STATUS
    # Save combined plot with dynamic filename
    combined_filename = joinpath(output_dir, "combined_shadow_prices$(combined_ext).svg")
    savefig(shadow_price_plot, combined_filename)
    println("Combined plot saved to: $combined_filename")
    end

    
    # VERSION 2: Create separate plots for active and reactive power with improved margins

    active_plot = plot(
        title = "Active Power",
        xlabel = "Load Number",
        ylabel = "Shadow Price (€/kW)",
        framestyle = :box,
        legend = :outertop,
        legend_columns = 3,
        grid = :true,
        minorgrid = :true,
        gridcolor = :black,
        gridalpha = 0.5,
        size = (1000, 500),
        dpi = 300,
        margin = 10mm,
        top_margin = 2mm,
        #bottom_margin = 10mm,  # Increased to accommodate legend + xlabel
        #left_margin = 10mm,
        xticks=custom_xticks,
        xrotation=X_degree,  # Rotate x-axis labels for better readability
        xtickfontsize = 16, ytickfontsize = 16,
        #fontfamily = "Courier", 
        titlefontsize = 18,
        xguidefontsize = 16,
        yguidefontsize = 16,
        legendfontsize = 12
    )

    reactive_plot = plot(
        title = "Reactive Power",
        xlabel = "Load Number",
        ylabel = "Shadow Price (€/kvar)",
        framestyle = :box,
        legend = :outertop,
        legend_columns = 3,
        grid = :true,
        minorgrid = :true,
        gridcolor = :black,
        gridalpha = 0.5,
        size = (1000, 500),
        dpi = 300,
        margin = 10mm,
        top_margin = 2mm,
        bottom_margin = 2mm,  # Increased to accommodate legend + xlabel
        #left_margin = 10mm,
        xticks=custom_xticks,
        xrotation=X_degree,  # Rotate x-axis labels for better readability
        xtickfontsize = 16, ytickfontsize = 16,
        #fontfamily = "Courier", 
        titlefontsize = 18,
        xguidefontsize = 16,
        yguidefontsize = 16,
        legendfontsize = 12
    )
    
    # Define a color map for the phases
    color_map = Dict(1 => :blue, 2 => :green, 3 => :red)

    # Plot each phase for active power
    for phase in 1:3
        phase_name = phase_map[phase]
        plot!(active_plot, buses_adjusted, active_shadow_prices_adjusted[phase], 
            label = "Phase $phase_name", 
            marker = marker_map[phase], 
            linestyle = :solid, 
            linewidth = 2,
            yticks=:auto,              # You can also provide specific values like yticks=0:0.1:1
            yformatter=y->@sprintf("%.2f", y), # Format to 2 decimal places
            color = color_map[phase])
    end

    # Plot each phase for reactive power
    for phase in 1:3
        phase_name = phase_map[phase]
        plot!(reactive_plot, buses_adjusted, reactive_shadow_prices_adjusted[phase], 
            label = "Phase $phase_name", 
            marker = marker_map[phase], 
            linestyle = :dot, 
            linewidth = 2,
            yticks=:auto,              # You can also provide specific values like yticks=0:0.1:1
            yformatter=y->@sprintf("%.2f", y), # Format to 2 decimal places
            color = color_map[phase])
    end
    
    # Combine plots into one figure with layout adjustments
    separate_plot = plot(active_plot, reactive_plot, 
                        layout = (2, 1),
                        size = (1000, 1000),  # Increased vertical size for better spacing
                        link = :x)            # Link x-axes between subplots

    
    active_plot2 = plot(
        #title = "Active Power",
        xlabel = "Load Number",
        ylabel = "Shadow Price (Euro/kW)",
        framestyle = :box,
        legend = :outertop,
        legend_columns = 3,
        grid = :true,
        minorgrid = :true,
        gridcolor = :black,
        gridalpha = 0.5,
        size = (1000, 500),
        dpi = 300,
        margin = 10mm,
        top_margin = 2mm,
        #bottom_margin = 10mm,  # Increased to accommodate legend + xlabel
        #left_margin = 10mm,
        xticks=custom_xticks,
        xrotation=X_degree,  # Rotate x-axis labels for better readability
        xtickfontsize = 16, ytickfontsize = 16,
        fontfamily = "Courier", 
        titlefontsize = 20,
        xguidefontsize = 18,
        yguidefontsize = 18,
        legendfontsize = 14
    )
    # Plot each phase for active power
    for phase in 1:3
        phase_name = phase_map[phase]
        plot!(active_plot2, buses_adjusted, active_shadow_prices_adjusted[phase], 
            label = "Phase $phase_name", 
            marker = marker_map[phase], 
            linestyle = :solid, 
            linewidth = 2,
            yticks=:auto,              # You can also provide specific values like yticks=0:0.1:1
            yformatter=y->@sprintf("%.2f", y), # Format to 2 decimal places
            color = color_map[phase])
    end

    if SAVING_FIGURES_STATUS
    # Save separate plots with dynamic filename
    separate_filename = joinpath(output_dir, "separate_shadow_prices$(separate_ext).svg")
    savefig(separate_plot, separate_filename)
    println("Separate plots saved to: $separate_filename")

    separate_filename_2 = joinpath(output_dir, "active_shadow_prices$(separate_ext).pdf")
    savefig(active_plot2, separate_filename_2)
    println("active plots saved to: $separate_filename")
    end

    
    # Display both plots
    if PLOT_DISPLAY
    display(shadow_price_plot)
    display(separate_plot)
    display(active_plot2)
    end
    
    return (combined = shadow_price_plot, separate = separate_plot)
end