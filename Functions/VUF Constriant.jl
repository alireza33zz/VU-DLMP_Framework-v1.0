function add_vuf_constraints!(pm, constraint::VUFConstraint, included_buses::Vector{Int})
    N_bus = isempty(included_buses) ? keys(pm.data["bus"]) : included_buses

    printstyled("\nAdding VUF constraints for buses: $(N_bus)"; color=:green)
    printstyled("\nAdding VUF constraints for $(length(N_bus)) buses"; color=:red)
    vm_var = pm.var[:it][:pmd][:nw][0][:vm]
    va_var = pm.var[:it][:pmd][:nw][0][:va]
    
    # Define auxiliary variables for real and imaginary parts of phase voltages
    @variable(pm.model, v_real[bus=N_bus, phase=1:3])
    @variable(pm.model, v_imag[bus=N_bus, phase=1:3])
    
    # Linear approximation of trigonometric functions
    # cos(θ) ≈ 1 - θ²/2 and sin(θ) ≈ θ for small θ
    # Or use piecewise linear approximations for wider range
    
    for bus in N_bus, phase in 1:3
        # Assuming angles are small or using PWL approximation
        @constraint(pm.model, v_real[bus, phase] == vm_var[bus][phase] * cos(va_var[bus][phase]))
        @constraint(pm.model, v_imag[bus, phase] == vm_var[bus][phase] * sin(va_var[bus][phase]))
    end
    
    # Define sequence components using linear combinations
    @variable(pm.model, v_pos_r[bus=N_bus])
    @variable(pm.model, v_pos_i[bus=N_bus])
    @variable(pm.model, v_neg_r[bus=N_bus])
    @variable(pm.model, v_neg_i[bus=N_bus])

    # Add explicit bounds on auxiliary variables
    for bus in N_bus
        # Assuming voltage magnitudes are bounded by vmin and vmax
        vmax = 1.1
        
        # Bounds for sequence components
    # Bounds for sequence components
    @constraint(pm.model, v_pos_r[bus] >= -vmax)
    @constraint(pm.model, v_pos_r[bus] <= vmax)
    @constraint(pm.model, v_pos_i[bus] >= -vmax)
    @constraint(pm.model, v_pos_i[bus] <= vmax)
    @constraint(pm.model, v_neg_r[bus] >= -vmax)
    @constraint(pm.model, v_neg_r[bus] <= vmax)
    @constraint(pm.model, v_neg_i[bus] >= -vmax)
    @constraint(pm.model, v_neg_i[bus] <= vmax)
    end
    
    a_r = -0.5
    a_i = 0.866
    
    # Sequence components as linear combinations of phase components
    for bus in N_bus
        @constraint(pm.model, v_pos_r[bus] == (1/3)*(v_real[bus,1] + a_r*v_real[bus,2] - a_i*v_imag[bus,2] + a_r*v_real[bus,3] + a_i*v_imag[bus,3]))
        @constraint(pm.model, v_pos_i[bus] == (1/3)*(v_imag[bus,1] + a_r*v_imag[bus,2] + a_i*v_real[bus,2] + a_r*v_imag[bus,3] - a_i*v_real[bus,3]))
        @constraint(pm.model, v_neg_r[bus] == (1/3)*(v_real[bus,1] + a_r*v_real[bus,2] + a_i*v_imag[bus,2] + a_r*v_real[bus,3] - a_i*v_imag[bus,3]))
        @constraint(pm.model, v_neg_i[bus] == (1/3)*(v_imag[bus,1] + a_r*v_imag[bus,2] - a_i*v_real[bus,2] + a_r*v_imag[bus,3] + a_i*v_real[bus,3]))
    end
    
    # Add numerical safeguard for positive sequence magnitude
    @variable(pm.model, v_pos_mag_sq[bus=N_bus] >= 0.01)  # Small positive lower bound
    
    for bus in N_bus
        @constraint(pm.model, v_pos_mag_sq[bus] == v_pos_r[bus]^2 + v_pos_i[bus]^2)
    end
    
    # VUF constraint
    pm.model[:vuf_constraints] = Dict()
    for bus in N_bus
        con = @constraint(pm.model, 
            v_neg_r[bus]^2 + v_neg_i[bus]^2 <= constraint.vuf_threshold^2 * v_pos_mag_sq[bus])
        pm.model[:vuf_constraints][bus] = con
    end
    
    printstyled("\nVUF constraints integrated successfully!"; color=:yellow)
end