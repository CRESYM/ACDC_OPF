/* =======================================================
         __   __   __      __   __   ___       __
    /\  /  ` |  \ /  ` __ /  \ |__) |__  |    /  \ |  | 
   /~~\ \__, |__/ \__,    \__/ |    |    |___ \__/ |/\| 

  ========================================================
  Purpose : ACDC Optimal Power Flow Computation
  GitHub  : https ://github.com/CRESYM/ACDC_OPF.git
  Version : v0.1
 --------------------------------------------------------
  Contributors : Haixiao Li, Azadeh Kermansaravi,
                 Aleksandra Lekic
  Email        : haixiaoli.ee@gmail.com
  Created on   : 2025 - 05 - 01
 --------------------------------------------------------  
 References :
 [1] J.Beerten, S.Cole and R.Belmans, "Generalized Steady-State VSC MTDC Model 
     for Sequential AC / DC Power Flow Algorithms, " in IEEE Transactions on Power Systems, 
     vol. 27, no. 2, pp. 821 - 829, May 2012, doi : 10.1109 / TPWRS.2011.2177867.
 [2]  Mauro Escobar, https ://github.com/me2533/acopf
 [3]  Matacdc1.0 unser's manual, https://www.esat.kuleuven.be/electa/teaching/matacdc/MatACDCManual */

#include "benchmarkTools.h"
#include "solve_opf.h"

// Remind: move ac / dc.csv files in "ACDC_CSV" folder to "OPF_cpp" folder
int main() {
    solve_opf("mtdc3slack_a", "ac14ac57",
        /*vscControl*/ true,
        /*writeTxt  */ false,
        /*plotResult*/ false);

    //std::vector<std::string> test_cases = { "ac14ac57", "ac57ac118", "ac9ac14", "ac118ac300" };
    //std::string dc_case = "mtdc3slack_a";
    //std::vector<BenchmarkResult> results;

    //run_benchmark(test_cases, dc_case, results);
    //print_summary(results);
    //save_results_csv(results, "benchmark_cpp.csv");
}