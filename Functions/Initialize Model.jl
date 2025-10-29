"""
Initialize PowerModelsDistribution model with basic settings
"""
function initialize_model(eng::Dict, config::OPFConfig)
    eng["settings"]["sbase_default"] = config.sbase_default
    eng["settings"]["power_scale_factor"] = config.power_scale_factor
    math = transform_data_model(eng)

        gen_ids = collect(keys(math["gen"]))
        # Set the cost function for generators C = ax + b
        ## For single phase gens dont put b (doesnt work)
        if length(gen_ids) == 1
            gen_id = gen_ids[1]
            math["gen"][gen_id]["cost"] = [1.0, 0.0]  # Only modify cost
        else
            math["gen"]["1"]["cost"] = [1.1, 150.0]
            math["gen"]["2"]["cost"] = [0.0, 0.0]
            math["gen"]["3"]["cost"] = [1.1, 150.0]
            math["gen"]["4"]["cost"] = [0.0, 0.0]
            math["gen"]["5"]["cost"] = [0.0, 0.0]
            math["gen"]["6"]["cost"] = [0.0, 0.0]
            math["gen"]["7"]["cost"] = [0.0, 0.0]
            math["gen"]["8"]["cost"] = [0.0, 0.0]
            math["gen"]["9"]["cost"] = [0.0, 0.0]
            math["gen"]["10"]["cost"] = [0.0, 0.0]
            math["gen"]["11"]["cost"] = [0.0, 0.0]
            math["gen"]["12"]["cost"] = [0.0, 0.0]
            math["gen"]["13"]["cost"] = [0.0, 0.0]
            math["gen"]["14"]["cost"] = [0.0, 0.0]
            math["gen"]["15"]["cost"] = [0.0, 0.0]
            math["gen"]["16"]["cost"] = [0.0, 0.0]
            math["gen"]["17"]["cost"] = [0.0, 0.0]
            math["gen"]["18"]["cost"] = [1.0, 0.0]
        end
        
        return math
end