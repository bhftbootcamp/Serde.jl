# Parquet Serialization and Deserialization Example
# This example demonstrates how to use Serde.jl to work with Parquet files
using Parquet2
using Serde

println("=== Parquet Example with Serde.jl ===\n")

# Example 1: Simple Struct Serialization
println("Example 1: Simple Struct Serialization")
println("=" ^ 50)

struct Person
    id::Int64
    name::String
    age::Int64
end

people = [
    Person(1, "Alice", 30),
    Person(2, "Bob", 25),
    Person(3, "Charlie", 35),
]

println("Original data:")
for person in people
    println("  ", person)
end

# Serialize to Parquet
output_file = pwd() * "/examples/_people.parquet"
Serde.to_parquet(output_file, people)
println("\n✓ Data serialized to: $output_file")

# Parse Parquet file
parsed_data = parse_parquet(output_file)
println("\nParsed data from Parquet:")
for item in parsed_data
    println("  ", item)
end

# Deserialize back to structs
deserialized_people = deser_parquet(Person, output_file)
println("\nDeserialized to typed structs:")
for person in deserialized_people
    println("  ID: $(person.id), Name: $(person.name), Age: $(person.age)")
end

# Cleanup
rm(output_file)
println("\n" * "=" ^ 50 * "\n")

# Example 2: Working with Custom Structs
println("Example 2: Serializing Custom Structs to Parquet")
println("=" ^ 50)

struct Employee
    id::Int64
    name::String
    salary::Float64
    department::String
end

employees = [
    Employee(1, "Alice Smith", 75000.0, "Engineering"),
    Employee(2, "Bob Johnson", 65000.0, "Marketing"),
    Employee(3, "Charlie Brown", 80000.0, "Engineering"),
    Employee(4, "Diana Prince", 70000.0, "HR"),
]

println("Original data (Vector of Structs):")
for emp in employees
    println("  ", emp)
end

# Serialize to Parquet
output_file2 = pwd() * "/examples/_struct.parquet"
to_parquet(output_file2, employees)
println("\n✓ Data serialized to: $output_file2")

# Deserialize back to structs
deserialized_employees = deser_parquet(Employee, output_file2)
println("\nDeserialized employees:")
for emp in deserialized_employees
    println("  ID: $(emp.id), Name: $(emp.name), Salary: \$$(emp.salary), Dept: $(emp.department)")
end

# Cleanup
rm(output_file2)
println("\n" * "=" ^ 50 * "\n")

# Example 3: Working with Larger Datasets
println("Example 3: Working with Larger Datasets")
println("=" ^ 50)

struct DataPoint
    index::Int64
    value::Float64
    category::String
end

large_dataset = [
    DataPoint(i, rand(), rand(["A", "B", "C"]))
    for i in 1:1000
]

println("Dataset size: $(length(large_dataset)) records")

# Write large dataset
large_file = pwd() * "/examples/_large.parquet"
to_parquet(large_file, large_dataset)
file_size = stat(large_file).size

println("File size: $(file_size) bytes")

# Verify we can read it back
parsed_large = parse_parquet(large_file)
println("✓ Successfully read $(length(parsed_large)) records from Parquet file")
println("Sample record: $(first(parsed_large))")

# Cleanup
rm(large_file)
println("\n" * "=" ^ 50 * "\n")

# Example 4: Type Conversion During Deserialization
println("Example 4: Type Conversion During Deserialization")
println("=" ^ 50)

struct InputData
    id::Int64
    value::Int64
end

struct OutputData
    id::Int64
    value::Float64  # Different type - will be converted
end

input_data = [
    InputData(1, 100),
    InputData(2, 200),
    InputData(3, 300),
]

println("Original data (Int64 values):")
for item in input_data
    println("  ", item)
end

# Serialize with Int64 values
conversion_file = pwd() * "/examples/_conversion.parquet"
to_parquet(conversion_file, input_data)

# Deserialize with Float64 values (automatic conversion)
output_data = deser_parquet(OutputData, conversion_file)
println("\nDeserialized data (Float64 values):")
for item in output_data
    println("  ID: $(item.id) ($(typeof(item.id))), Value: $(item.value) ($(typeof(item.value)))")
end

# Cleanup
rm(conversion_file)
println("\n" * "=" ^ 50 * "\n")

println("✓ All examples completed successfully!")
println("\nFor more information, see:")
println("  - Serde.jl documentation")
println("  - Parquet2.jl documentation: https://gitlab.com/ExpandingMan/Parquet2.jl")
