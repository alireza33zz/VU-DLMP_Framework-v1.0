using DataFrames
using Statistics
using Plots, StatsPlots
using Plots.PlotMeasures

# Prepare the data
test_cases = ["Default", "R. Hard", "Soft", "M. Hyb."]
parameters = ["PV1", "PV2", "PV3", "PV4", "PV5", "PV6", "PV7", 
              "PV8", "PV9", "PV10", "PV11", "PV12", "PV13", "PV14", "DER2"]

data = -1 * [
    -1.012 -1.119 -1.081 -1.107 -1.118 -0.990 -1.025 -1.051 -1.010 -1.010 -1.055 -1.123 -1.065 -1.012 0.000;
    -0.482 -2.732 -0.216 -2.181 -2.213 -0.492 -0.709 -0.639 -0.629 -0.682 -0.618 -2.226 -0.456 0.000 0.000;
    0.000 -3.595 0.000 -3.211 -3.442 0.000 -0.397 -0.225 -0.212 -0.301 -0.189 -3.542 0.000 0.000 0.000;
    0.000 -3.360 0.000 -3.271 -3.298 0.000 -0.633 -0.314 0.000 -0.009 -0.225 -3.301 0.000 0.000	0.000

]

# 1. Create a heatmap - keeping this one as is
p1 = heatmap(parameters[1:end-1], test_cases, data[:,1:end-1],
           color=:RdYlGn_9,
           aspect_ratio=1.25,
           #title="Parameter Values Across Test Cases",
           xlabel="Name of generator",
           ylabel="Test Cases",
           left_margin=8Plots.mm,
           fontfamily = "Courier",
           xtickfontsize=16,
           xrotation = -90,
           ytickfontsize=16,
           labelfontsize=18,
           size=(1100, 500),
           colorbar=true,
           right_margin=20Plots.mm,
           bottom_margin=11Plots.mm)               # Increases right margin

annotate!(p1, [(17.5, 0.5, text("Dual Value", 18, :right, :Courier, rotation=-90))])
# 2. Create a scatter plot (points only, no lines)
p2 = scatter()
for i in 1:size(data, 1)
    scatter!(1:15, data[i,:], 
            label=test_cases[i],
            markersize=6,
            markershape=[:circle, :square, :diamond, :utriangle, :circle][i],
            #title="Parameter Values by Test Case (Scatter)",
            xlabel="Name of generator",
            ylabel="Dual Value",
            xticks=(1:15, parameters),
            legend=:bottomright,
            xrotation=45,
            bottom_margin=2Plots.mm,
            left_margin=6Plots.mm,
            size=(800, 600))
end

# 3. Create an improved bar chart with better spacing
# Calculate the positions for each group
# We'll create offset positions for each test case within parameter groups
p3 = plot(#title="Parameter Values by Test Case (Bar)",
        xlabel="Name of generator",
        ylabel="Dual Value",
        legend=:outertop,
        legend_columns = 4,
        size=(800, 600),
        bottom_margin=2Plots.mm,
        left_margin=6Plots.mm,
        xtickfontsize=8)

bar_width = 0.15  # Width of each bar
for i in 1:size(data, 1)
    # Calculate offset for each test case (centered around integer positions)
    offset = (i - 2.5) * bar_width
    positions = collect(1:15) .+ offset
    
    # Plot bars for this test case
    bar!(positions, data[i,:], 
        bar_width=bar_width,
        label=test_cases[i],
        alpha=0.8)
end

# Set x-axis ticks at the parameter positions
xticks!(1:15, parameters, xrotation=45)

# Show all plots in a layout
final_plot = plot(p1, p2, p3, layout=(3,1), size=(1600, 1600))

# Save the plot
savefig(final_plot, "test_case_visualization.png")
savefig(p1, "test_case_visualization1_2.png")
savefig(p1, "heatmap2.svg")
savefig(p1, "heatmap2.pdf")
savefig(p2, "test_case_visualization2.png")
savefig(p3, "test_case_visualization3.png")
# Display the plot
#final_plot
p1

