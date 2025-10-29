# main.jl
# ─────────────────────────────────────────────────────────────────────────────
# Entry point for running OPF simulations
# Includes: Default OPF, VUF+Gen costs, Zlin+Gen costs
# ─────────────────────────────────────────────────────────────────────────────

# Load core algorithm files
include("Default Gen cost.jl")
include("VUF+Gen costs.jl")

# ─────────────────────────────────────────────────────────────────────────────
# Global flags and settings
# ─────────────────────────────────────────────────────────────────────────────

global VUF_STATUS = false              # Enable/Disable VUF constraints
global PLOT_DISPLAY = true            # Show plots during execution
global SAVING_FIGURES_STATUS = false  # Save figures to disk
global DEFAULT_OPF_personal = true    # true = run default OPF; false = run VUF+Gen and Zlin+Gen
global PRINT_PERMISSION_personal = false # Verbose solver output

# Case selection
Case_Num = [20]  # 20 = 55-bus system + motors + DERs
file_path = "LVTestCase/Master.dss"

# OPF configuration struct
struct OPFConfig
    sbase_default::Float64
    power_scale_factor::Float64
    v_upper_bound::Float64
    v_lower_bound::Float64
    thermal::Float64
    VUF_level::Float64
    print_level::Int
end

config = OPFConfig(
    1.0,    # sbase_default
    1000.0, # power_scale_factor
    1.10,   # v_upper_bound
    0.94,   # v_lower_bound
    1000.0, # thermal
    1.0,    # VUF_level
    1       # print_level
)

# Weight sets for VUF+Gen and Zlin+Gen
M_values_set = [1.0, 0.5, 1.0, 1.5, 2.0, 3.0, 10.0, 30.0]
N_values_set = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# Select one pair or all
single = 3  # Set to 0 to run all pairs

if single != 0
    M_values = [M_values_set[single]]
    N_values = [N_values_set[single]]
else
    M_values = M_values_set
    N_values = N_values_set
end

# ─────────────────────────────────────────────────────────────────────────────
# Run loop
# ─────────────────────────────────────────────────────────────────────────────

for case in Case_Num
    if DEFAULT_OPF_personal
        global combined_extension = "_default_case$case"
        global separate_extension = combined_extension
        println()
        printstyled("Running default case $case"; color = :red)
        println()
        default_opf(file_path)
    else
        for i in 1:length(M_values)
            M = M_values[i]
            N = N_values[i]

            global combined_extension = "_VUF+Gen_$(M)_$(N)_case$case"
            global separate_extension = combined_extension
            println()
            printstyled("Running VUF+Gen case $case with M=$M and N=$N"; color = :red)
            println()
            VUF_Gen_costs(file_path, M, N)
        end
    end
end