# main.jl
# ─────────────────────────────────────────────────────────────────────────────
# Entry point for running OPF simulations
# Includes: Default OPF, VUF+Gen costs
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Mode selection helper
# ─────────────────────────────────────────────────────────────────────────────

# Choose one of the following modes manually:
# 1 → Default OPF (no VUF constraint or penalty)
# 2 → OPF with voltage unbalance as constraint
# 3 → OPF with voltage unbalance penalization

selected_mode = 1  # ← change this to 2 or 3 as needed

if selected_mode == 1
    global VUF_STATUS = false
    global DEFAULT_OPF_personal = true
elseif selected_mode == 2
    global VUF_STATUS = true
    global DEFAULT_OPF_personal = true
    global VUF_set_selector = 2
elseif selected_mode == 3
    global VUF_STATUS = false
    global DEFAULT_OPF_personal = false
    global VUF_set_selector = 3
else
    error("Invalid mode selected. Choose 1, 2, or 3.")
end

# ─────────────────────────────────────────────────────────────────────────────
# Other global flags
# ─────────────────────────────────────────────────────────────────────────────
global PLOT_DISPLAY = true            # Show plots during execution
global SAVING_FIGURES_STATUS = true  # Save figures to disk
global PRINT_PERMISSION_personal = true # Verbose solver output

# Load core algorithm files
include("Default Gen cost.jl")
include("VUF+Gen costs.jl")

# Case selection
Case_Num = [1]  # List of case numbers to run
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