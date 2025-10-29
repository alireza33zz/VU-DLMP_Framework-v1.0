"""
Add voltage magnitude constraints to the model (v_lower_bound <= v <= v_upper_bound)
"""
function add_voltage_constraints!(pm, constraint::VoltageConstraint)
    pm.model[:voltage_constraints] = Dict()
    for i in 1:length(pm.data["bus"])
        for phase in 1:3
            con = @constraint(pm.model, constraint.v_lower_bound <= pm.var[:it][:pmd][:nw][0][:vm][i][phase] <= constraint.v_upper_bound)
            pm.model[:voltage_constraints][(i, phase)] = con
        end
    end
    println("")
    printstyled("Voltage magnitude constraints integrated successfully!"; color=:yellow)
end