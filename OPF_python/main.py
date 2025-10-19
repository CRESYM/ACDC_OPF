# =======================================================
#         __   __   __      __   __   ___       __       
#    /\  /  ` |  \ /  ` __ /  \ |__) |__  |    /  \ |  | 
#   /~~\ \__, |__/ \__,    \__/ |    |    |___ \__/ |/\| 
#
# ========================================================
#  Purpose : ACDC Optimal Power Flow Computation
#  GitHub  : https://github.com/CRESYM/ACDC_OPF.git
#  Version : v0.1
# --------------------------------------------------------
#  Contributors: Haixiao Li, Azadeh Kermansaravi, 
#               Aleksandra Lekic
#  Email       : haixiaoli.ee@gmail.com
#  Created on  : 2025-05-01
# --------------------------------------------------------  
# References:
# [1] J.Beerten, S.Cole and R.Belmans, "Generalized Steady-State VSC MTDC Model 
# for Sequential AC / DC Power Flow Algorithms, " in IEEE Transactions on Power Systems, 
# vol. 27, no. 2, pp. 821 - 829, May 2012, doi : 10.1109 / TPWRS.2011.2177867.
# [2]  Mauro Escobar, https ://github.com/me2533/acopf
# [3]  Matacdc1.0 unser's manual, https://www.esat.kuleuven.be/electa/teaching/matacdc/MatACDCManual

# Remind: move ac/dc .csv files in "ACDC_CSV" folder to "OPF_python" folder
# Below case fix the generation outputs to do powerflow compuation
# (benchmark in Matacdc1.0 unser's manual, p31-p33)
from opf_acdc import solve_opf
result_opf = solve_opf("mtdc3", "ac5", 
                       vscControl=True,
                       writeTxt=False,
                       plotResult=False)




