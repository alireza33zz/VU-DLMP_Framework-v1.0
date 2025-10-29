"""
Test function with default settings
"""
function test_opf(file_path::String)
  
    # Solve OPF with VUF constraint
    solution, pm, results_df = solve_opf(file_path, config)
    
    return solution, pm, results_df
end