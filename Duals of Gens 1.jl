using DataFrames
using Statistics
using Plots, StatsPlots
using Plots.PlotMeasures

# Prepare the data
test_cases = ["1", "2", "3.a", "3.b"]
parameters = ["PV1", "PV2", "PV3", "PV4", "PV5", "PV6", "PV7", 
              "PV8", "PV9", "PV10", "PV11", "PV12", "PV13", "PV14", "DER2"]

data = -1 * [
-1.012	-1.119	-1.081	-1.107	-1.118	-0.990	-1.025	-1.051	-1.010	-1.010	-1.055	-1.123	-1.065	-1.012	0.000;
-0.482	-2.732	-0.216	-2.181	-2.213	-0.492	-0.709	-0.639	-0.629	-0.682	-0.618	-2.226	-0.456	0.000	0.000;
-0.601	-2.007	-0.779	-1.786	-1.843	-0.535	-0.862	-0.860	-0.688	-0.723	-0.859	-1.866	-0.823	-0.429	0.000;
-0.295	-2.864	-0.285	-2.447	-2.543	-0.188	-0.649	-0.577	-0.450	-0.513	-0.564	-2.581	-0.440	0.000	0.000

]

# 1. Create a heatmap - keeping this one as is
p1 = heatmap(parameters[1:end-1], test_cases, data[:,1:end-1],
           color=:greys,
            
           aspect_ratio=1.25,
           #title="Parameter Values Across Test Cases",
           xlabel="Name of generator",
           ylabel="Test Cases",
           left_margin=8Plots.mm,
           #fontfamily = "Courier",
           xtickfontsize=16,
           xrotation = -90,
           ytickfontsize=16,
           labelfontsize=18,
           size=(1100, 500),
           colorbar=true,
           right_margin=10Plots.mm,
           bottom_margin=11Plots.mm)               # Increases right margin

annotate!(p1, [(16.25, 1.0, text("Dual Value", 18, :right, rotation=-90))])

#= Save the plot
savefig(final_plot, "test_case_visualization.png")
savefig(p1, "test_case_visualization1_2.png")
savefig(p1, "heatmap2.svg")
savefig(p1, "heatmap2.pdf")
savefig(p2, "test_case_visualization2.png")
savefig(p3, "test_case_visualization3.png")
# Display the plot
=#
#final_plot
display(p1)
savefig(p1, "heatmap1.svg")

