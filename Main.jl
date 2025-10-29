
include("Default Gen cost.jl")
include("VUF+Gen costs.jl")
include("Zlin+Gen costs.jl")


global VUF_STATUS = false
global PLOT_DISPLAY = true
global SAVING_FIGURES_STATUS = false
global DEFAULT_OPF_personal = true
global PRINT_PERMISSION_personal = false
 
#Case_Num = [1, 2, 3, 4]
Case_Num = [20]
# 10 is the 55-bus default system 
# 12 is the 55-bus default system + DERs
# 11 is the 105-bus default system Load111 
# 13 is the 105-bus default system Load111 + DERs
# 20 is the 55-bus default system + 3 Motors + DERs

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
    1000.0,    # thermal 
    1.0,    # VUF_level
    1       # print_level
)

#=
M_values_set = [1.0, 1.0, 1.4, 1.43, 1.44, 1.5, 1.6,
                2.0, 3.0, 4.5, 7.0, 10.0, 15.0, 21.0, 30.0]  # Voltage Unbalance weight
N_values_set = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
                1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # Generation cost weight
=#

M_values_set = [1.0, 0.5, 1.0, 1.5, 2.0, 3.0, 10.0, 30.0] # Voltage Unbalance weight
N_values_set = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] # Generation cost weight

single = 3  # Set to 1 for the first element

if single != 0
    M_values = M_values_set[single]  # Indexing starts at 1 in Julia
    N_values = N_values_set[single]
else
    M_values = M_values_set
    N_values = N_values_set
end

Solve_time_personal = zeros(length(M_values), 2)
for case in Case_Num
    file_path = "LVTestCase/Master.dss"
        #
if DEFAULT_OPF_personal == true
        global combined_extension = "_default_case$case"
        global separate_extension = combined_extension
        println()
        printstyled("Running default case $case"; color = :red)
        println()
        default_opf(file_path)
end
#
if DEFAULT_OPF_personal == false
    for i in 1:length(M_values)
        M = M_values[i]
        N = N_values[i]
        #
        global combined_extension = "_VUF+Gen_$(M)_$(N)_case$case"
        global separate_extension = combined_extension
        println()
        printstyled("Running VUF+Gen case $case with M= $(M) and N= $(N)"; color = :red)
        println()
        t1 = @elapsed VUF_Gen_costs(file_path, M, N)
        Solve_time_personal[i,1] = t1
        #
        global combined_extension = "_Zlin+Gen_$(M)_$(N)_case$case"
        global separate_extension = combined_extension
        println()
        printstyled("Running Zlin+Gen case $case with M= $(M) and N= $(N)"; color = :red)
        println()
        #t2 = @elapsed Zlin_Gen_costs(file_path, M, N)
        #Solve_time_personal[i,2] = t2
        Zlin_Gen_costs(file_path, M, N)
        #
    end
end
#
end
