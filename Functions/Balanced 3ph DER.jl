function ensuring_balance_operation_of_3ph_DERs(math, pm)
    for gen_i = 1:length(math["gen"]) # set equal phase outputs for 3-phase generators
        if math["gen"][string(gen_i)]["name"] != "_virtual_gen.voltage_source.source" 
            if length(math["gen"][string(gen_i)]["connections"]) == 3
                println("")
                printstyled("Note: 3-phase balanced generators are connected to the network"; color = :blue)
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:pg][gen_i][1] == pm.var[:it][:pmd][:nw][0][:pg][gen_i][2])
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:pg][gen_i][2] == pm.var[:it][:pmd][:nw][0][:pg][gen_i][3])
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:pg][gen_i][3] == pm.var[:it][:pmd][:nw][0][:pg][gen_i][1])
    
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:qg][gen_i][1] == pm.var[:it][:pmd][:nw][0][:qg][gen_i][2])
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:qg][gen_i][2] == pm.var[:it][:pmd][:nw][0][:qg][gen_i][3])
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:qg][gen_i][3] == pm.var[:it][:pmd][:nw][0][:qg][gen_i][1])
            end
        end
    end

end