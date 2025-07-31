<p align="left">
  <img src="assets\OPF_julia.png" alt="Logo" width="500">
</p>   

# ⚡ Julia Implementation of AC/DC OPF

This folder contains the Julia-based implementation of the AC/DC OPF model using the JuMP optimization framework and the Gurobi solver.

> **Current Status:** This is an **early-stage Version 0.1, Still building** ... more features are ongoing !

---

## 📁 File Overview

| File | Description |
|------|-------------|
| `main.jl` | Main script to run AC/DC OPF. |
| `create_ac.jl` | Parses the interconnected AC network data: bus, branch, generator information, etc. |
| `create_dc.jl` | Parses the MTDC network data: DC buses, DC branches, converters. |
| `params_ac.jl` | Extracts AC-side parameters used for AC/DC OPF. |
| `params_dc.jl` | Extracts DC-side parameters used for AC/DC OPF. |
| `solve_opf.jl` | Constructs and solves the AC/DC OPF model using JuMP and Gurobi. |
| `viz_opf.jl` | Visualizes optimization results: topology, power flows. |
| `makeYbus.jl` | Computes nodal addmitance matrix. |
| `benchmarkTools.jl` | Tests computation performance in cases. |

---

## 🔧 Dependencies

To run this project, the following tools must be installed:

- [JuMP.jl](https://jump.dev/JuMP.jl/stable/): Optimization modeling framework.
- [CSV.jl](https://github.com/JuliaData/CSV.jl): Reading and writing `.csv` data files. 
- [DataFrames.jl](https://dataframes.juliadata.org/stable/): Tabular data manipulation and processing.
- [Gurobi.jl](https://github.com/jump-dev/Gurobi.jl): Interface to the Gurobi solver (license required).
- [Graphs.jl](https://juliagraphs.org/Graphs.jl/stable/): Graph data structures for representing power network topology.
- [GraphPlot.jl](https://github.com/JuliaGraphs/GraphPlot.jl): Visualization tool for network layouts.
- [GLMakie.jl](https://docs.makie.org/v0.22/explanations/backends/glmakie) Tool for interactive plotting. 
- [ColorSchemes.jl](https://github.com/JuliaGraphics/ColorSchemes.jl) Color maps for consistent and aesthetic plots. 
- [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) Color operations and definitions.

---

## 🚀 Getting Started

1. Clone the repository and navigate to the `OPF_julia` folder:

    ```bash
    git clone https://github.com/CRESYM/ACDC_OPF.git
    cd ACDC_OPF/OPF_julia
    ```

2. Open Julia, then enter `Pkg` mode by pressing the`]` key. The prompt will change to:

    ```julia
    (@v1.10) pkg>
    ```

3. Run the following commands one by one:

    ```julia
    add JuMP
    add CSV
    add DataFrames
    add Gurobi
    add Graphs
    add GraphPlot
    add GLMakie
    add ColorSchemes
    add Colors
    ```
4. Open `OPF_julia` file and run `main.jl`:
   
    ```julia
    include("create_ac.jl") 
    include("create_dc.jl") 
    include("makeYbus.jl") 
    include("params_dc.jl") 
    include("params_ac.jl") 
    include("solve_opf.jl") 
    include("viz_opf.jl") 

    result_opf = solve_opf("mtdc3slack_a", "ac9ac14",
                    vscControl = true,
                    writeTxt = false,
                    plotResult = true)
    ```

## 🖨️  Expected Output

1. You will see the printed [AC/DC OPF results](assets/opf_results_julia.txt) on the terminal window :

     ```txt
    ===========================================================================================
    |   AC Grid Bus Data                                                                      |
    ===========================================================================================
    Area    Bus   Voltage        Generation             Load                  RES
    #       #     Mag [pu]  Pg [MW]   Qg [MVAr]   Pd [MW]  Qd [MVAr]  Pres [MW]  Qres [MVAr]
    -----   -----  --------  --------   --------  ---------  --------  ---------  -----------
    1       1      1.040*   87.563     97.799      0.000     0.000          -            -
    1       2      1.093   134.529    299.978      0.000     0.000          -            -
    1       3      1.037    93.126     91.936      0.000     0.000          -            -
    1       4      1.009        -           -      0.000     0.000          -            -
    1       5      1.000        -           -     90.000    30.000     40.000       -8.017
    
    ...... (omitted here)

2. You will see the plotted AC/DC OPF results like:

  <p align="left">
  <img src="assets\viz_Julia.png" alt="Logo" width="480">
  </p>  
