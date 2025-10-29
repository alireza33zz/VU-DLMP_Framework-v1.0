using JuMP
using Ipopt

# Create a new model
model = Model(Ipopt.Optimizer)

# Define a 3x3 matrix of variables with bounds between 0 and 1
@variable(model, 0 <= x[1:3, 1:3] <= 1)

# Add constraints
@constraint(model, sum(x[1, :]) == 1)
@constraint(model, sum(x[2, :]) == 1)
@constraint(model, sum(x[3, :]) == 1)

@constraint(model, sum(x[:, 1]) == 1)
@constraint(model, sum(x[:, 2]) == 1)
@constraint(model, sum(x[:, 3]) == 1)

@constraint(model, x[1, 1]^2 + x[1, 2]^2 + x[1, 3]^2 == 1)
@constraint(model, x[2, 1]^2 + x[2, 2]^2 + x[2, 3]^2 == 1)

#=
@constraint(model, x[1, 1]^2 + x[2, 1]^2 + x[3, 1]^2 == 1)
@constraint(model, x[1, 2]^2 + x[2, 2]^2 + x[3, 2]^2 == 1)
=#

# Objective: Minimize the sum of the 9 variables
@objective(model, Min, sum(x[1, :]))

# Solve the model
optimize!(model)

# Print the results
println("Optimal value: ", objective_value(model))
println("Optimal variables: ")
for i in 1:3, j in 1:3
    println("x[$i, $j] = ", round(value(x[i, j]), digits=2))
end