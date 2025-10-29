"""
Calculate Voltage Unbalance Factor (VUF) using sequence components method
"""
function calculate_vuf(vm::Vector{Float64}, va::Vector{Float64})
    # Transformation angle for sequence components
    a = exp(im * 2π/3)
    
    # Convert magnitude and angle to complex voltages
    Va = vm[1] * exp(im * va[1])
    Vb = vm[2] * exp(im * va[2])
    Vc = vm[3] * exp(im * va[3])
    
    # Calculate sequence components (corrected)
    V0 = (Va + Vb + Vc) / 3 
    V1 = (Va + a * Vb + a^2 * Vc) / 3 
    V2 = (Va + a^2 * Vb + a * Vc) / 3
    
    # Calculate VUF
    vuf = abs(V2) / abs(V1) * 100
    
    return vuf
end