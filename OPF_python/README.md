<p align="left">
  <img src="assets\OPF_python.png" alt="Logo" width="500">
</p>   

# ⚡ Python Implementation of AC/DC OPF

This folder contains the Python-based implementation of the AC/DC OPF model using the Pyomo optimization framework and the Gurobi solver.

> **Current Status:** This is an **early-stage Version 0.1, Still building** ... more features is ongoing !

---

## 📁 File Overview

| File | Description |
|------|-------------|
| `main.py` | Entry script to run the AC/DC OPF solver. |
| `create_acdc.py` | Parses both AC and DC system data from `.csv` files. |
| `params_acdc.py` | Extracts AC and DC-side parameters used for AC/DC OPF. |
| `opf_acdc.py` | Builds and solves the AC/DC OPF model using Pyomo and Gurobi. |
| `viz_opf.py` | Visualizes optimization results: topology, power flows.  |
| `makeYbus.py` | Computes the nodal admittance matrix. |
| `benchmarkTools.py` | Tests computation performance in cases. |

---

## 🔧 Dependencies

To run this project, the following tools must be installed:

- [pyomo](https://www.pyomo.org/): Optimization modeling framework.
- [gurobipy](https://pypi.org/project/gurobipy/): Interface to the Gurobi solver (license required).
- [pandas](https://pandas.pydata.org/): Reading and managing tabular data.
- [numpy](https://numpy.org/): Numerical computations and matrix operations.
- [matplotlib](https://matplotlib.org/): Plotting tools.
- [networkx](https://networkx.org/): Power network topology and graph operations. 

---

## 🚀 Getting Started

1. Clone the repository and navigate to the `OPF_python` folder:

    ```bash
    git clone https://github.com/YourUsername/ACDC_OPF.git
    cd ACDC_OPF/OPF_python
    ```

2. Install the required packages using either `pip` or `conda`:

    ```bash
    pip install pyomo gurobipy pandas numpy matplotlib networkx
    ```
   ```bash
    conda create -n your_env_name python=3.1x
    conda activate your_env_name
    conda install -c conda-forge pyomo pandas numpy matplotlib networkx
    ```
   
3. Open the `OPF_python` file and run `main.py`:
   
    ```python
   from opf_acdc import solve_opf
   result_opf = solve_opf("mtdc3slack_a", "ac9ac14", 
                       vscControl=True,
                       writeTxt=False,
                       plotResult=True)
    ```

## 🖨️  Expected Output

1. You will see the printed [AC/DC OPF results](assets/opf_results_python.txt) on the terminal window :

     ```txt
        =======================================================================================
    |   AC Grid Bus Data                                                                  |
    =======================================================================================
    Area     Bus   Voltage       Generation             Load                 RES
    #        #     Mag [pu]  Pg [MW]  Qg [MVAr]    P [MW]  Q [MVAr]  Pres [MW]  Qres [MVAr]
    -----   -----  --------  --------  --------  ---------   ------  ---------  -----------
    1        1     1.042*    87.562  104.708      0.000    0.000          -            -
    1        2     1.093    134.529  299.999      0.000    0.000          -            -
    1        3     1.037     93.127   91.192      0.000    0.000          -            -
    1        4     1.009          -       -       0.000    0.000          -            -
    1        5     1.000          -       -      90.000   30.000     40.000       -8.004

    ...... (omitted here)

2. You will see the plotted AC/DC OPF results like:

  <p align="left">
  <img src="assets\viz_Python.png" alt="Logo" width="480">
  </p>  

