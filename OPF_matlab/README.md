<p align="left">
  <img src="assets\OPF_matlab.png" alt="Logo" width="500">
</p>   

# ⚡ MATLAB Implementation of AC/DC OPF

This folder contains the MATLAB-based implementation of the AC/DC OPF model using the YALMIP framework and the Gurobi solver.

> **Current Status:** This is an **early-stage Version 0.1, Still building** ... more features coming soon!

---

## 📁 File Overview

| File | Description |
|------|-------------|
| `main.m` | Main script to run AC/DC OPF. |
| `create_ac.m` | Parses the interconnected AC network data: bus, branch, generator information, etc. |
| `create_dc.m` | Parses the MTDC network data: DC buses, DC branches, converters. |
| `params_ac.m` | Extracts AC-side parameters used for AC/DC OPF. |
| `params_dc.m` | Extracts DC-side parameters used fro AC/DC OPF. |
| `solve_opf.m` | Constructs and solves the AC/DC OPF model using YALMIP and Gurobi. |
| `viz_opf.m` | Visualizes optimization results: topology, power flows. |
| `benchmarkTools.m` | Test computation performance in cases. |

---

## 🔧 Dependencies

To run this module, the following tools must be installed:

- MATLAB (R2015b or later recommended, which includes built-in function `graph`)
- [YALMIP](https://yalmip.github.io/): Help fromulate AC/DC OPF model.   
- [Gurobi Optimizer](https://www.gurobi.com/): Support various mathematical programming problem-solving.

---

## 🚀 Getting Started

1. Clone the repository and navigate to the `OPF_matlab` folder:

    ```bash
    git clone https://github.com/CRESYM/ACDC_OPF.git
    cd ACDC_OPF/OPF_matlab
    ```

2. Open MATLAB and add all files to your path:

    ```matlab
    addpath(genpath(pwd));   
    savepath;
    ```

3. Run `main.m` file:

    ```matlab
    solve_opf('mtdc3slack_a', ...   
              'ac9ac14', ...
              'vscControl', true, ...
              'writeTxt',   false, ...
              'plotResult', true);
    ```

## 🖨️  Expected Output

1. You will see the printed [AC/DC OPF results](assets/opf_result.txt) on the terminal window :

     ```txt
    =================================================================================
    |      AC Grids Bus Data                                                        |
    =================================================================================
     Area   Branch        Voltage            Generation                Load        
     #      #       Mag [pu]  Ang [deg]   Pg [MW]   Qg [MVAr]   Pd [MW]   Qd [MVAr]
    -----   -----   --------  ---------   --------  ---------   -------   ---------
       1       1      1.048      0.000    100.966    119.890     0.000       0.000
       1       2      1.100      0.000    150.474    299.987     0.000       0.000
       1       3      1.045      0.000    104.361     96.882     0.000       0.000
       1       4      1.011      0.000        -         -        0.000       0.000
       1       5      1.000      0.000        -         -       90.000      30.000
    
    ...... (omitted here)

2. You will see the plotted AC/DC OPF results like:

  <p align="left">
  <img src="assets\viz_MATLAB.png" alt="Logo" width="450">
  </p>  
    
