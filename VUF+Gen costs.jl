"""
This script performs a three-phase optimal power flow (OPF) calculation using the PowerModelsDistribution package in Julia. 
It includes the ability to add custom constraints. 
The script is modular and generic, allowing for easy integration of new constraints and configurations.
"""

using PowerModelsDistribution
using JuMP
using Ipopt
using DataFrames



include("Functions/Default Configuration.jl");
include("Functions/Configure Solver.jl");
include("Functions/Initialize Model.jl");
include("Functions/Calculate VUF.jl");
include("Functions/Format Results.jl");
include("Functions/Print Results.jl");
include("Functions/Solve OPF with VUF.jl");
include("Functions/Test OPF with VUF.jl");
include("Functions/Print Network Structure.jl");
include("Functions/Balanced 3ph DER.jl");
include("Functions/PQ Curve.jl");
include("Functions/Dual Variables.jl"); 
include("Functions/Shadow Prices.jl");
include("Functions/Thermal Limit.jl");
include("Functions/Voltage Magnitude.jl");
include("Functions/VUF Constriant.jl");

function VUF_Gen_costs(file_path::String, M::Float64, N::Float64)

solution, pm, results_df = test_opf_with_vuf(file_path, M, N); #Second number is for Gen cost

print_network_structure(solution, pm);

end