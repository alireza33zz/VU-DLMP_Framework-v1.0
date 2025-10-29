# Simple Julia test code
function hello_world()
    println("Hello from Julia!")
end

# Calculate the sum of numbers from 1 to n
function sum_numbers(n::Int)
    total = 0
    for i in 1:n
        total += i
    end
    return total
end

# Test our functions
hello_world()
result = sum_numbers(10)
println("Sum of numbers from 1 to 10: $result")

# Create and display a simple array
my_array = [3, 1, 4, 1, 5, 9, 2, 6]
println("Original array: $my_array")
println("Sorted array: $(sort(my_array))")
println("Array length: $(length(my_array))")