"""
Print formatted results
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

    global corelation_vuf_Zlin = round(cor(results_df.vuf_percent, results_df.Zlin_percent), digits=5)
    printstyled("\nCorrelation between vuf_percent and Zlin_percent: ", corelation_vuf_Zlin,  color = :blue)

    printstyled("\n=== OPF Results ==="; color = :green)
    println()
    printstyled("Objective value: ", round(solution["objective"], digits=3) ; color = :blue)
    println()
    println("Solve time: ", round(solution["solve_time"], digits=6), " seconds")
    println("\nBus Results:")
    println(results_df)

fz = 18

# First plot: Box plot of error values
p1 = boxplot(
    results_df.error,
    title = "Distribution of Error (Modified PVUR2 - VUF)",
    ylabel = "Error Value",
    fillcolor = :lightblue,
    linecolor = :blue,
    whisker_width = 0.5,
    outliers = true,
    grid = false,
    framestyle = :box,
    size = (600, 500),
    dpi = 300,
    margin = 20Plots.px
)
hline!([0], color=:red, linestyle=:dash, label="Zero Error")

# Add mean value as a point
mean_error = mean(results_df.error)
scatter!([1], [mean_error], markersize=6, color=:black, 
         label="Mean ($(round(mean_error, digits=3)))")

# Second plot: VUF vs Zlin by bus_id
p2 = plot(
    #title = "Voltage Unbalance Indices Comparison",
    xlabel = "Load ID",
    ylabel = "Voltage Unbalance (%)",
    legend = :bottomright,
    framestyle = :box,
    size = (2000, 600),
    dpi = 300,
    xtickfontsize = fz, ytickfontsize = fz,
    fontfamily = "Courier", 
    titlefontsize = fz,
    xguidefontsize = fz,
    yguidefontsize = fz,
    legendfontsize = fz,

    margin = 12mm,
    
    # grid = :false,
    grid = :true,

    # minorgrid = :false,
    minorgrid = :true
)

# Add data points
bar_positions = 1:length(results_df.bus_id)


# Plot VUF bars
scatter!(p2, bar_positions[1:3:end], results_df.vuf_percent[1:3:end],
        color=:blue, markersize=9, alpha=0.7, marker = :circle, label="VUF (%)")

# Plot Zlin bars
scatter!(p2, bar_positions[1:3:end], results_df.Zlin_percent[1:3:end], 
        color=:red, markersize=9, alpha=0.7, marker = :square, label="Modified PVUR2 (%)")

# Add custom x-ticks with bus IDs
xticks!(p2, bar_positions[1:6:end], results_df.bus_id[1:6:end], rotation=-0)

# Display plots side by side
# X = plot(p1, p2, layout = (2, 1), size = (1000, 400))

if PLOT_DISPLAY
    display(p1)
    display(p2)
end

if VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\With VUF Constraint"
    mkpath(output_dir)
    elseif !VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\Without VUF Constraint"
    mkpath(output_dir)
end

    combined_ext = @isdefined(combined_extension) ? combined_extension : ""
    separate_ext = @isdefined(separate_extension) ? separate_extension : ""

# Save
if SAVING_FIGURES_STATUS
    # Save combined plot with dynamic filename
    combined_filename1 = joinpath(output_dir, "box_plot$(combined_ext).png")
    combined_filename2 = joinpath(output_dir, "VUF_Zlin$(combined_ext).pdf")

    savefig(p1, combined_filename1)
    savefig(p2, combined_filename2)
end

# Initialize the flag (do this once in your code, e.g., at the start)
global real_OPF_value_set = false

if DEFAULT_OPF_personal == true
    if VUF_STATUS
        global OPF_result_with_hard = round(solution["objective"], digits=3)
        global real_OPF_value_set = true  # Mark that we now have the correct value
    else  # VUF_STATUS is false
        global OPF_result_without_hard = round(solution["objective"], digits=3)
        # Only update OPF_result_with_hard if we haven't already set it with the "real" value
        if !real_OPF_value_set
            global OPF_result_with_hard = round(solution["objective"], digits=3)
        end
    end
end

return round(solution["solve_time"], digits=6)
end