<p align="left">
  <img src="assets\OPF_cpp.png" alt="Logo" width="500">
</p>   

# ⚡ C++ Implementation of AC/DC OPF

This folder contains the C++-based implementation of the AC/DC OPF model using the Gurobi C++ API optimization framework and the Gurobi solver.

> **Current Status:** This is an **early-stage Version 0.1, Still building** ... more features is ongoing !

---

## 📁 File Overview

| File | Description |
|------|-------------|
| `main.cpp` | Main script to run the AC/DC OPF. |
| `create_ac.cpp / create_ac.h` | Load AC grid data from `.csv`. |
| `create_dc.cpp / create_dc.h` | Load DC grid and VSC converter data from `.csv`. |
| `params_ac.cpp / params_ac.h` | Extract parameters for AC-side modeling. |
| `params_dc.cpp / params_dc.h` | Extract parameters for DC-side modeling. |
| `csv_reader.cpp / csv_reader.h` | Read custom `.csv` files. |
| `makeYbus.cpp / makeYbus.h` | Construct AC admittance matrix using bus/branch data. |
| `solve_opf.cpp / solve_opf.h` | Core OPF formulation using Gurobi C++ API. |
| `viz_opf.cpp / viz_opf.h` | Visualize AC/DC power flows. |
| `benchmarkTools.cpp / benchmarkTools.h` | Tools to run performance tests across cases. |
| `acmtdcpfvcx.sln` | Visual Studio solution file. |

---

## 🔧 Dependencies

To run this project, the following tools must be installed:

- [Gurobi C++ API](https://docs.gurobi.com/projects/optimizer/en/current/reference/cpp.html): C++ API for optimization (license required).
- [Eigen](https://eigen.tuxfamily.org/index.php?title=Main_Page): C++ library for linear algebra.
- [Matplot++](https://alandefreitas.github.io/matplotplusplus/): C++ plotting library.

---

## 🚀 Getting Started

1. Clone the repository and navigate to the `OPF_c++` folder:

    ```bash
    git clone https://github.com/YourUsername/ACDC_OPF.git
    cd ACDC_OPF/OPF_c++
    ```
2. We recomend using [vcpkg](https://github.com/microsoft/vcpkg) to manage C++ library. Download `vcpkg`:
   ```bash
   git clone https://github.com/microsoft/vcpkg.git
   cd vcpkg
   ./bootstrap-vcpkg.bat
   ```
   Intergrate`vcpkg` with Visual Studio:
   ```bash
   ./vcpkg integrate install
   ```
3. Install  `Eigen` and  `Matplot++` via `vcpkg`. Open  `Powershell` or `CMD`, and navigate to the  `vcpkg` directory, like: 

    ```bash
   cd C:\XXX\vcpkg
   ```

   In the root directory of `vcpkg`, type:

   ```bash
   .\vcpkg install eigen3
   .\vcpkg install matplotplusplus
   ```

   `Gurobi` is not in `vcpkg`, you must download [Gurobi](https://www.gurobi.com/downloads/) manually and install it follow a [Instruction](https://support.gurobi.com/hc/en-us/articles/4534161999889-How-do-I-install-Gurobi-Optimizer).

    ---
   

## 🧩 Gurobi Configuration in Visual Studio IDE
  
   Below are details regarding the Gurobi Configuration. Based on our local setup, the configuration is demonstrated using **Gurobi 9.5.2** and **Visual Studio 2022**.

   👉 Firstly, you will find two folders, `include` and `lib`, inside your Gurobi installation directory. 
  
  <p align="left">
  <img src="assets\gurobi_config_f1.png" alt="Logo" width="450">
  </p>  

  For example, if you installed `Gurobi` to `D:\gurobi952\win64`, then:
  
  - Header files are located at:  
  `D:\gurobi952\win64\include`
  <p align="left">
    <img src="assets\gurobi_config_f2.png" alt="Logo" width="450">
  </p> 

  - Library files are located at:  
  `D:\gurobi952\win64\lib`
  <p align="left">
    <img src="assets\gurobi_config_f3.png" alt="Logo" width="450">
  </p> 

👉 Then, set **External Include Directories**:

Step1️⃣: right-click **【project】** ➡️ select **【Properties】** ➡️ go to **【VC++ Drectories】**
 
Step2️⃣: select **【External Include Directories】** ➡️ add  `D:\gurobi952\win64\include` 

Step3️⃣: click **【OK】**


  <p align="left">
    <img src="assets\gurobi_config_f4.jpg" alt="Logo" width="660">
  </p> 

 👉 Next, set **Additional Liarbry Directories**:

 Step1️⃣: right-click **【project】** ➡️ select **【Properties】** ➡️ go to **【Linker】** ➡️ select **【General】**
 
 Step2️⃣: select **【Additional Liarbry Directories】** ➡️ add  `D:\gurobi952\win64\lib` 

 Step3️⃣: click **【OK】**

<p align="left">
  <img src="assets\gurobi_config_f5.jpg" alt="Logo" width="660">
</p> 

 👉 Last, add **Additional Dpendencies**:

 Step1️⃣: right-click **【project】** ➡️ select **【Properties】** ➡️ go to **【Linker】** ➡️ select **【Input】**
 
 Step2️⃣: select **【Additional Dpendencies】** ➡️ add  `D:\gurobi952\win64\lib\gurobi95.lib` and `D:\gurobi952\win64\lib\gurobi_c++mdd2019.lib` 

 Step3️⃣: click **【OK】**

<p align="left">
  <img src="assets\gurobi_config_f6.jpg" alt="Logo" width="660">
</p> 

✅ Configuration finished

## 🧩 Matplot++ Configuration in Visual Studio IDE

After installing `Matplot++`, you probably still have problems running it successfully. 

👉 First,  `Matplot++` only use `C++17` or higher. In your Visual Studio, you need to go to **【Configuration Properties】** and then set:

<p align="left">
  <img src="assets\matplot++_f4.jpg" alt="Logo" width="660">
</p> 

👉 Then, you will still get an error report:
   ```bash
   Unhandled exception at 0x0007ffe9ececf19 in MatplotPlusPlus_text.exe:
   Microsoft C++ exception: std::runtime_error at memory location 0x000000F632EFEC68.
   ```
This is because `Matplot++` relies on [gunplot](https://sourceforge.net/projects/gnuplot/) to achieve the plot function. You need to download and install `gunplot`.
<p align="left">
  <img src="assets\matplot++_f3.png" alt="Logo" width="660">
</p> 

👉 After installing `gunplot`, add the `gunplot.exe` file into `PATH` under `System Variables` :
<p align="left">
  <img src="assets\matplot++_f2.jpg" alt="Logo" width="350">
</p> 

<p align="left">
  <img src="assets\matplot++_f1.jpg" alt="Logo" width="350">
</p> 

👉 Last, add `gunplot` library path in Visual Studio:
<p align="left">
  <img src="assets\matplot++_f5.jpg" alt="Logo" width="660">
</p> 

✅ Configuration finished

## 🖨️  Expected Output

1. You will see the printed [AC/DC OPF results](assets/opf_results_cpp.txt) on the terminal window :

     ```txt
        =======================================================================================
    |   AC  Grid Bus Data                                                                 |
    =======================================================================================
    Area    Bus   Voltage       Generation            Load                 RES
    #       #     Mag [pu]  Pg [MW]   Qg [MVAr]  P [MW]   Q [MVAr]  Pres [MW]  Qres[MVAr] 
    -----   -----  --------  --------  ---------  -------  -------   ---------  ---------
      1       1      1.041*   87.562     99.575    0.000    0.000           -          -
      1       2      1.093   134.529    300.000    0.000    0.000           -          -
      1       3      1.034    93.127     81.335    0.000    0.000           -          -
      1       4      1.009         -          -    0.000    0.000           -          -
      1       5      1.000         -          -   90.000   30.000      40.000     -8.004

    ...... (omitted here)

2. You will see the plotted AC/DC OPF results like:

  <p align="left">
  <img src="assets\viz_C++.png" alt="Logo" width="700">
  </p>  


