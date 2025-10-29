"""
Configure solver with custom settings
"""
function configure_solver(config::OPFConfig)
    return JuMP.optimizer_with_attributes(
        Ipopt.Optimizer,
        "print_level" => config.print_level,
        "tol" => 1e-4,          # Default tolerance
        "acceptable_tol" => 1e-3,  # Allows earlier termination if stuck, # Matching acceptable tolerance
        "max_iter" => 10000 # Added maximum iteration limit
    )
end