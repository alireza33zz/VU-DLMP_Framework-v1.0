"""
Test function with default settings
"""
function test_opf_with_vuf(file_path::String, M::Float64, N::Float64)
    # Solve OPF with VUF constraint
    solution, pm, results_df = solve_opf_with_VUF(file_path, config, M, N)
    
    return solution, pm, results_df
end