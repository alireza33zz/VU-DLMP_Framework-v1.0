"""
Print formatted results
"""

function print_formatted_results(solution::Dict, pm)
    if solution["termination_status"] != MOI.LOCALLY_SOLVED
        println()
        printstyled("WARNING: OPF didn't converge!"; color=:red)
        println()
        return
    end

    # Format and display results
    results_df = format_results(solution, pm)

    printstyled("\n=== OPF Results ==="; color = :green)
    println()
    printstyled("Objective value: ", round(solution["objective"], digits=3) ; color = :blue)
    println()
    println("Solve time: ", round(solution["solve_time"], digits=6), " seconds")
    println("\nBus Results:")
    println(results_df)


if VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\With VUF Constraint"
    mkpath(output_dir)
    elseif !VUF_STATUS
    output_dir = "C:\\Users\\Alireza\\.julia\\Distribution-Locational-Mariginal-Price-55LV-simplified\\Outputs\\Without VUF Constraint"
    mkpath(output_dir)
end

    combined_ext = @isdefined(combined_extension) ? combined_extension : ""
    separate_ext = @isdefined(separate_extension) ? separate_extension : ""

# Initialize the flag (do this once in your code, e.g., at the start)
global real_OPF_value_set = false

return round(solution["solve_time"], digits=6)
end