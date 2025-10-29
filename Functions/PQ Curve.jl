function ensuring_PQ_curve_of_flexible_DERs!(pm)
    if length(pm.var[:it][:pmd][:nw][0][:pg]) != 1
        # Add PQ curve constraints
        for j in 1:(length(pm.var[:it][:pmd][:nw][0][:pg])-15) # 15 is the number of non-flexible DERs (including the substation)
            j_2 = string(j) 
            for i in 1:length(pm.var[:it][:pmd][:nw][0][:pg][j])
                @constraint(pm.model, pm.var[:it][:pmd][:nw][0][:pg][j][i]^2 + pm.var[:it][:pmd][:nw][0][:qg][j][i]^2 <= pm.data["gen"][j_2]["pmax"][i]^2)
            end
        end
    end
    
    end