"""
Configuration struct to hold OPF parameters
"""
struct OPFConfig
    sbase_default::Float64
    power_scale_factor::Float64
    v_upper_bound::Float64
    v_lower_bound::Float64
    thermal::Float64
    VUF_level::Float64
    print_level::Int
end

"""
Default configuration
"""
function default_config()
    return OPFConfig(
        1.0,    # sbase_default
        1000.0, # power_scale_factor (kW)
        1.10,   # v_upper_bound (p.u.)
        0.94,   # v_lower_bound (p.u.)
        100,    # thermal (kVA)
        1.0,    # VUF_level (%)
        1       # print_level
    )
end

"""
Custom constraint type for extensibility
"""
abstract type AbstractConstraint end

struct VoltageConstraint <: AbstractConstraint
    v_upper_bound::Float64
    v_lower_bound::Float64
end

struct ThermalConstraint <: AbstractConstraint
    phase_a::Float64
    phase_b::Float64
    phase_c::Float64
end

struct VUFConstraint <: AbstractConstraint
    vuf_threshold::Float64
end