using CSV
using DataFrames

"""
    create_ac(case_name::String) -> Dict{String,Any}

Load AC grid data from CSV files with the given `case_name` prefix.

Expected CSV files (located in the same directory):
  - `<case_name>_baseMVA_ac.csv`
  - `<case_name>_bus_ac.csv`
  - `<case_name>_branch_ac.csv`
  - `<case_name>_gen_ac.csv`
  - `<case_name>_gencost_ac.csv`
  - `<case_name>_res_ac.csv`

Returns a dictionary `ac` with the following keys:
  - "baseMVA"   : Scalar base MVA value.
  - "bus"       : Matrix containing AC bus data.
  - "branch"    : Matrix containing AC branch data.
  - "generator" : Matrix containing AC generator data.
  - "gencost"   : Matrix containing AC generator cost data.
  - "res"       : Matrix containing AC RES data.
"""
function create_ac(case_name::String)
    # Set the base path to the directory containing this file
    base_path = @__DIR__

    # Initialize the dictionary to hold AC network data
    ac = Dict{String,Any}()

    # List of required CSV file names
    required_files = [
        "$(case_name)_baseMVA_ac.csv",
        "$(case_name)_bus_ac.csv",
        "$(case_name)_branch_ac.csv",
        "$(case_name)_gen_ac.csv",
        "$(case_name)_gencost_ac.csv",
        "$(case_name)_res_ac.csv"
    ]

    # Check missing files
    missing_files = filter(f -> !isfile(joinpath(base_path, f)), required_files)
    if !isempty(missing_files)
        error("Missing required AC files: " * join(missing_files, ", "))
    end

    # Load each CSV file
    read_csv_matrix(file) = Matrix(DataFrame(CSV.File(joinpath(base_path, file); header=false)))
    baseMVA = read_csv_matrix("$(case_name)_baseMVA_ac.csv")
    ac["baseMVA"] = baseMVA[1, 1]
    ac["bus"]      = read_csv_matrix("$(case_name)_bus_ac.csv")
    ac["branch"]   = read_csv_matrix("$(case_name)_branch_ac.csv")
    ac["generator"] = read_csv_matrix("$(case_name)_gen_ac.csv")
    ac["gencost"]  = read_csv_matrix("$(case_name)_gencost_ac.csv")
    ac["res"] = read_csv_matrix("$(case_name)_res_ac.csv")

    return ac
end

