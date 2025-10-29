"""
Add thermal limits constraints to the model (p^2 + q^2 <= s^2)
"""
function add_thermal_constraints!(math, constraint::ThermalConstraint)
    #
    N_lines = length(math["branch"])
    for i in 1:(N_lines) # N_lines - 1
        # Define thermal limits for each phase
        thermal_limits = [constraint.phase_a, constraint.phase_b, constraint.phase_c]
        math["branch"]["$i"]["rate_a"] = thermal_limits
        
    end
    #
    println()
    printstyled("Thermal constraints integrated successfully!"; color=:yellow)
end