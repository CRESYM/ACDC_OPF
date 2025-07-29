import time
import itertools
import os         
import sys  
import math
import numpy as np
import networkx as nx
import matplotlib.pyplot as plt
from typing import Dict, Any
from contextlib import nullcontext
from pyomo.environ import *
from pyomo.opt import SolverFactory
from params_acdc import params_ac, params_dc
from viz_opf import viz_opf

def solve_opf(dcgrid_name: str, acgrid_name: str, *,
            vscControl: bool = True,    # enable vsc control constraint
            writeTxt: bool = False,     # enable text output of ac/dc opf
            plotResult: bool = True     # enable plots output of ac/dc opf
            ):
    
    start = time.perf_counter()
    
    # -------------------------------
    # 1: Load DC and AC Parameters
    # -------------------------------
    res_params_dc       = params_dc(dcgrid_name)
    network_dc          = res_params_dc["network_dc"]
    baseMW_dc           = res_params_dc["baseMW_dc"]
    bus_dc              = res_params_dc["bus_dc"]
    branch_dc           = res_params_dc["branch_dc"]
    conv_dc             = res_params_dc["conv_dc"]
    pol_dc              = res_params_dc["pol_dc"]
    nbuses_dc           = res_params_dc["nbuses_dc"]
    nbranches_dc        = res_params_dc["nbranches_dc"]
    nconvs_dc           = res_params_dc["nconvs_dc"]
    fbus_dc             = res_params_dc["fbus_dc"]
    tbus_dc             = res_params_dc["tbus_dc"]
    ybus_dc             = res_params_dc["ybus_dc"]
    rtf_dc              = res_params_dc["rtf_dc"]
    xtf_dc              = res_params_dc["xtf_dc"]
    bf_dc               = res_params_dc["bf_dc"]
    rc_dc               = res_params_dc["rc_dc"]
    xc_dc               = res_params_dc["xc_dc"]
    ztfc_dc             = res_params_dc["ztfc_dc"]
    gtfc_dc             = res_params_dc["gtfc_dc"]
    btfc_dc             = res_params_dc["btfc_dc"]
    aloss_dc            = res_params_dc["aloss_dc"]
    bloss_dc            = res_params_dc["bloss_dc"]
    closs_dc            = res_params_dc["closs_dc"]
    convState           = res_params_dc["convState"]
    basekV_dc           = res_params_dc["basekV_dc"]

    res_params_ac       = params_ac(acgrid_name)
    network_ac          = res_params_ac["network_ac"]
    baseMVA_ac          = res_params_ac["baseMVA_ac"]
    bus_entire_ac       = res_params_ac["bus_entire_ac"]
    branch_entire_ac    = res_params_ac["branch_entire_ac"]
    generator_entire_ac = res_params_ac["generator_entire_ac"]
    gencost_entire_ac   = res_params_ac["gencost_entire_ac"]
    res_entire_ac       = res_params_ac["res_entire_ac"]
    ngrids              = res_params_ac["ngrids"]
    bus_ac              = res_params_ac["bus_ac"]
    branch_ac           = res_params_ac["branch_ac"]
    generator_ac        = res_params_ac["generator_ac"]
    gencost_ac          = res_params_ac["gencost_ac"]
    res_ac              = res_params_ac["res_ac"]
    recRef_ac           = res_params_ac["recRef_ac"]
    pd_ac               = res_params_ac["pd_ac"]
    qd_ac               = res_params_ac["qd_ac"]
    sres_ac             = res_params_ac["sres_ac"]
    nbuses_ac           = res_params_ac["nbuses_ac"]
    nbranches_ac        = res_params_ac["nbranches_ac"]
    ngens_ac            = res_params_ac["ngens_ac"]
    nress_ac            = res_params_ac["nress_ac"]
    GG_ac               = res_params_ac["GG_ac"]
    BB_ac               = res_params_ac["BB_ac"]
    GG_ft_ac            = res_params_ac["GG_ft_ac"]
    BB_ft_ac            = res_params_ac["BB_ft_ac"]
    GG_tf_ac            = res_params_ac["GG_tf_ac"]
    BB_tf_ac            = res_params_ac["BB_tf_ac"]
    fbus_ac             = res_params_ac["fbus_ac"]
    tbus_ac             = res_params_ac["tbus_ac"]

    # -------------------------------
    # 2: Build the Optimization Model and Set Up Constraints
    # -------------------------------
    model = ConcreteModel()
    model.addconstraints = ConstraintList()

    setup_dc(model, res_params_dc, vscControl)
    setup_ac(model, res_params_ac)
    setup_cp(model, res_params_dc, res_params_ac)
    setup_obj(model, res_params_dc, res_params_ac)

    # -------------------------------
    # 3: Solve AC/DC OPF
    # -------------------------------
    solver = SolverFactory("gurobi") 
    solver.options["TimeLimit"] = 600  
    solver.options["Threads"] = 8          
    solver.options["Presolve"] = 2         
    solver.options["OutputFlag"] = 1  
    solver.options["NumericFocus"] = 3
  
    solver.solve(model, tee=True)
    
    end = time.perf_counter()


    # ============================ Print Results =============================
    outfile = os.path.join(os.getcwd(), "opf_results.txt")
    io_ctx  = open(outfile, "w", encoding="utf-8") if writeTxt else nullcontext()
    io      = io_ctx if writeTxt else sys.stdout
    with io_ctx if writeTxt else nullcontext():
        # ----------------------------
        # Print AC Grid Bus Data
        # ---------------------------- 
        print("=======================================================================================", file=io)
        print("|   AC Grid Bus Data                                                                  |", file=io)
        print("=======================================================================================", file=io)
        print("Area     Bus   Voltage       Generation             Load                 RES", file=io)
        print("#        #     Mag [pu]  Pg [MW]  Qg [MVAr]    P [MW]  Q [MVAr]  Pres [MW]  Qres [MVAr]", file=io)
        print("-----   -----  --------  --------  --------  ---------   ------  ---------  -----------", file=io)
        formatted_vm_ac = {ng: [np.sqrt(value(model.vn2_ac[ng, i])) for i in range(nbuses_ac[ng])] for ng in range(ngrids)}
        formatted_pgen_ac = {ng: [value(model.pgen_ac[ng, j]) * baseMVA_ac for j in range(ngens_ac[ng])] for ng in range(ngrids)}
        formatted_qgen_ac = {ng: [value(model.qgen_ac[ng, j]) * baseMVA_ac for j in range(ngens_ac[ng])] for ng in range(ngrids)}
        formatted_pres_ac = {ng: [value(model.pres_ac[ng, j]) * baseMVA_ac for j in range(nress_ac[ng])] for ng in range(ngrids)}
        formatted_qres_ac = {ng: [value(model.qres_ac[ng, j]) * baseMVA_ac for j in range(nress_ac[ng])] for ng in range(ngrids)}
        formatted_pd_ac = {ng: [pd_ac[ng][i] * baseMVA_ac for i in range(nbuses_ac[ng])] for ng in range(ngrids)}
        formatted_qd_ac = {ng: [qd_ac[ng][i] * baseMVA_ac for i in range(nbuses_ac[ng])] for ng in range(ngrids)}
        for ng in range(ngrids):
            genidx = [int(generator_ac[ng][j, 0]) for j in range(ngens_ac[ng])]  
            residx = [int(res_ac[ng][j, 0]) for j in range(nress_ac[ng])]  
            for i in range(nbuses_ac[ng]):
                printed_vm_ac = formatted_vm_ac[ng][i]
                if i == 0 and ng == 0:
                    print(f"{ng+1:3}{i+1:9}{printed_vm_ac:10.3f}", end="", file=io)
                else:
                    print(f"\n{ng+1:3}{i+1:9}{printed_vm_ac:10.3f}", end="", file=io)

                if i in recRef_ac[ng]:
                    print("*", end="", file=io)

                if i + 1 in genidx:
                    gen_idx = genidx.index(i + 1)
                    printed_pgen = formatted_pgen_ac[ng][gen_idx]
                    printed_qgen = formatted_qgen_ac[ng][gen_idx]
                    
                    if i in recRef_ac[ng]:
                        print(f"{printed_pgen:10.3f}{printed_qgen:9.3f}", end="", file=io)
                    else:
                        print(f"{printed_pgen:11.3f}{printed_qgen:9.3f}", end="", file=io)

                    printed_pd = formatted_pd_ac[ng][i]
                    printed_qd = formatted_qd_ac[ng][i]
                    print(f"{printed_pd:11.3f}{printed_qd:9.3f}", end="", file=io)

                else:
                    print("          -       -", end="", file=io)
                    printed_pd = formatted_pd_ac[ng][i]
                    printed_qd = formatted_qd_ac[ng][i]
                    print(f"{printed_pd:12.3f}{printed_qd:9.3f}", end="", file=io)

                if i + 1 in residx:
                    res_idx = residx.index(i + 1)
                    printed_pres = formatted_pres_ac[ng][res_idx]
                    printed_qres = formatted_qres_ac[ng][res_idx]
                    print(f"{printed_pres:11.3f}{printed_qres:13.3f}", end="", file=io)
                else:
                    print("          -            -",  end="", file=io)

        print("\n-----   -----  --------  --------  --------  ---------   ------  ---------  -----------", file=io)
        
        totalGenerationCost = value(model.objective)
        print(f"The total generation costs is ＄{totalGenerationCost:.2f}/MWh (€{totalGenerationCost / 1.08:.2f}/MWh)", file=io)
        print("\n", file=io)

        # ----------------------------
        # Print AC Grid Branch Data
        # ----------------------------
        print("===========================================================================================", file=io)
        print("|     AC Grid Branch Data                                                                 |", file=io)
        print("===========================================================================================", file=io)
        print("Area   Branch  From   To        From Branch Flow         To Branch Flow        Branch Loss", file=io)
        print("#      #       Bus#   Bus#    Pij [MW]   Qij [MVAr]    Pij [MW]   Qij [MVAr]  Pij_loss [MW]", file=io)
        print("----   ------  -----  -----  ---------  ----------   ----------  ----------  -------------", file=io)
        
        formatted_pij_ac = {
            ng: [[value(model.pij_ac[ng, i, j]) * baseMVA_ac for j in range(nbuses_ac[ng])] 
            for i in range(nbuses_ac[ng])]
        for ng in range(ngrids)
        }
        
        formatted_qij_ac = {
            ng: [[value(model.qij_ac[ng, i, j]) * baseMVA_ac for j in range(nbuses_ac[ng])] 
            for i in range(nbuses_ac[ng])]
        for ng in range(ngrids)
        }

        totalACPowerLoss = 0.0
        for ng in range(ngrids):
            for i in range(nbranches_ac[ng]):
                printed_fbus_ac = fbus_ac[ng][i] 
                printed_tbus_ac = tbus_ac[ng][i] 
                
                printed_pij_from_to = formatted_pij_ac[ng][printed_fbus_ac-1][printed_tbus_ac-1]
                printed_qij_from_to = formatted_qij_ac[ng][printed_fbus_ac-1][printed_tbus_ac-1]
                printed_pij_to_from = formatted_pij_ac[ng][printed_tbus_ac-1][printed_fbus_ac-1]
                printed_qij_to_from = formatted_qij_ac[ng][printed_tbus_ac-1][printed_fbus_ac-1]
            
                
                printed_pij_loss_ac = abs(printed_pij_from_to + printed_pij_to_from)
                totalACPowerLoss += printed_pij_loss_ac
                
                print(f"{ng+1:2} {i+1:6} {printed_fbus_ac:7} {printed_tbus_ac:6}"
                    f" {printed_pij_from_to:12.3f} {printed_qij_from_to:11.3f}"
                    f" {printed_pij_to_from:12.3f} {printed_qij_to_from:11.3f} {printed_pij_loss_ac:11.3f}", file=io)
        
        print("----   ------  -----  -----  ---------  -----------    --------  ----------  -------------", file=io)
        
        print(f"The total AC network losses is {totalACPowerLoss:.3f} MW\n", file=io)
        print("\n", file=io)

        # ----------------------------
        # Print DC Grid Bus Data
        # ---------------------------- 
        print("================================================================================", file=io)
        print("|   MTDC Bus Data                                                              |", file=io)
        print("================================================================================", file=io)
        print(" Bus   Bus    AC   DC Voltage   DC Power   PCC Bus Injection   Converter loss", file=io)
        print(" DC #  AC #  Area   Vdc [pu]    Pdc [MW]   Ps [MW]  Qs [MVAr]  Conv_Ploss [MW]", file=io)
        print("-----  ----  ----  ---------    --------   -------  --------    --------", file=io)
        formatted_vm_dc = np.sqrt([value(model.vn2_dc[i]) for i in range(nbuses_dc)])
        formatted_pn_dc = [value(model.pn_dc[i]) * baseMW_dc for i in range(nbuses_dc)]
        formatted_ps_dc = [value(model.ps_dc[i]) * baseMW_dc for i in range(nconvs_dc)]
        formatted_qs_dc = [value(model.qs_dc[i]) * baseMW_dc for i in range(nconvs_dc)]
        formatted_convPloss_dc = [value(model.convPloss_dc[i]) * baseMW_dc for i in range(nbuses_dc)]
        TotalConvPloss = 0.0
        for i in range(nbuses_dc):
            printed_ac_bus = int(conv_dc[i, 1])
            printed_ac_area = int(conv_dc[i, 2])
            printed_vm_dc = formatted_vm_dc[i]
            printed_pn_dc = formatted_pn_dc[i]
            printed_ps_dc = formatted_ps_dc[i]
            printed_qs_dc = formatted_qs_dc[i]
            printed_convPloss_dc =  formatted_convPloss_dc[i]
            TotalConvPloss += printed_convPloss_dc
            print(f"{i+1:4}{printed_ac_bus:6}{printed_ac_area:6}{printed_vm_dc:10.3f}{printed_pn_dc:14.3f}"
                f"{printed_ps_dc:10.3f}{printed_qs_dc:9.3f}{printed_convPloss_dc:11.3f}", file=io)
        print("-----  ----  ----  ---------    --------   -------  --------    --------", file=io)

        print(f"The total converter losses is {TotalConvPloss:.3f} MW\n", file=io)
        print("\n", file=io)

        # ----------------------------
        # Print DC Grid Branch Data
        # ---------------------------- 
        print("===================================================================", file=io)
        print(" |     MTDC Branch Data                                            |", file=io)
        print(" ===================================================================", file=io)
        print(" Branch  From   To     From Branch    To Branch      Branch Loss", file=io)
        print(" #       Bus#   Bus#   Flow Pij [MW]  Flow Pij [MW]  Pij_loss [MW]", file=io)
        print(" ------  -----  -----   ---------      ---------      ---------", file=io)
        formatted_pij_dc = [[value(model.pij_dc[i, j]) for j in range(nbuses_dc)] for i in range(nbuses_dc)] * baseMW_dc * pol_dc
        
        totalDCPowerLoss = 0.0
        for i in range(nbranches_dc):
            printed_from_bus_dc = fbus_dc[i] 
            printed_to_bus_dc = tbus_dc[i] 

            printed_pij_from_to_dc = formatted_pij_dc[printed_from_bus_dc-1][printed_to_bus_dc-1] 
            printed_pij_to_from_dc = formatted_pij_dc[printed_to_bus_dc-1][printed_from_bus_dc-1]
            printed_pij_loss_dc = abs(printed_pij_from_to_dc + printed_pij_to_from_dc)

            print(f"{i+1:5} {printed_from_bus_dc:6} {printed_to_bus_dc:6}"
                f" {printed_pij_from_to_dc:11.3f} {printed_pij_to_from_dc:14.3f} {printed_pij_loss_dc:13.3f}", file=io)
            
            totalDCPowerLoss += printed_pij_loss_dc
        
        print(" ------  -----  -----   ---------      ---------      ---------", file=io)
        print(f" The total DC network losses is {totalDCPowerLoss:.3f} MW.\n", file=io)

        elapsed_time = end - start
        print(f"Excution time is {elapsed_time:.3f} s.", file=io)

    if writeTxt:
        print(f"[info] OPF results saved to {outfile}")   

    (vn2_dc_k, pn_dc_k, ps_dc_k, qs_dc_k, pc_dc_k, qc_dc_k, v2s_dc_k, v2c_dc_k,
     Ic_dc_k, lc_dc_k, pij_dc_k, lij_dc_k, Ctt_dc_k, Ccc_dc_k, Ctc_dc_k, 
     Stc_dc_k, Cct_dc_k, Sct_dc_k, convPloss_dc_k) = extract_vals_dc(model, nbuses_dc, nconvs_dc)
    
    (vn2_ac_k, pn_ac_k, qn_ac_k, pgen_ac_k, qgen_ac_k,
     pij_ac_k, qij_ac_k, ss_ac_k, cc_ac_k, pres_ac_k, qres_ac_k) = extract_vals_ac(model, ngrids, nbuses_ac, ngens_ac, nress_ac)
    
    if plotResult:
        viz_opf(
        bus_entire_ac,
        branch_entire_ac,
        generator_entire_ac,
        res_entire_ac,
        pgen_ac_k,
        qgen_ac_k,
        pij_ac_k,
        qij_ac_k,
        pres_ac_k,
        qres_ac_k,
        vn2_ac_k,
        baseMVA_ac,
        bus_dc,
        branch_dc,
        conv_dc,
        pij_dc_k,
        ps_dc_k,
        qs_dc_k,
        vn2_dc_k,
        pol_dc,
        baseMW_dc,
        )

    return model

"""
=== setup_dc ===

This function defines the DC grid optimization variables, their bounds,
and operational constraints.

The decision variable vector is partitioned into blocks as follows:
    - 1. vn2_dc         : DC bus voltage squared 
    - 2. pn_dc          : DC nodal active power injection 
    - 3. ps_dc          : Active power injection at VSC AC side 
    - 4. qs_dc          : Reactive power injection at VSC AC side 
    - 5. pc_dc          : Active power injection at VSC DC side 
    - 6. qc_dc          : Reactive power injection at VSC DC side 
    - 7. v2s_dc         : Squared voltage at VSC AC side 
    - 8. v2c_dc         : Squared voltage at VSC DC side 
    - 9. Ic_dc          : VSC current magnitude 
    - 10. lc_dc         : Squared VSC current 
    - 11. pij_dc        : DC branch power flow 
    - 12. lij_dc        : Squared DC branch current 
    - 13. Ctt_dc        : VSC SOC relaxed term no.1 
    - 14. Ccc_dc        : VSC SOC relaxed term no.2 
    - 15. Ctc_dc        : VSC SOC relaxed term no.3 
    - 16. Stc_dc        : VSC SOC relaxed term no.4 
    - 17. Cct_dc        : VSC SOC relaxed term no.5 
    - 18. Sct_dc        : VSC SOC relaxed term no.6 
    - 19. convPloss_dc  : Converter power loss 

Inputs:
    - model: A Pyomo model.
    - res_params_dc : Dictionary containing DC grid data, including:
          nbuses_dc, nconvs_dc, bus_dc, conv_dc, ybus_dc, pol_dc,
          baseMW_dc, gtfc_dc, btfc_dc, aloss_dc, bloss_dc, closs_dc, convState."

"""

def setup_dc(model:ConcreteModel, 
             res_params_dc: Dict[str, Any],
             vscControl: bool) -> None:

    # Extract DC parameters will be used
    baseMW_dc       = res_params_dc["baseMW_dc"]
    bus_dc          = res_params_dc["bus_dc"]
    conv_dc         = res_params_dc["conv_dc"]
    pol_dc          = res_params_dc["pol_dc"]
    nbuses_dc       = res_params_dc["nbuses_dc"]
    nconvs_dc       = res_params_dc["nconvs_dc"]
    ybus_dc         = res_params_dc["ybus_dc"]
    gtfc_dc         = res_params_dc["gtfc_dc"]
    btfc_dc         = res_params_dc["btfc_dc"]
    aloss_dc        = res_params_dc["aloss_dc"]
    bloss_dc        = res_params_dc["bloss_dc"]
    closs_dc        = res_params_dc["closs_dc"]
    convState       = res_params_dc["convState"]

    # --- Initialization (a totoal of 19 kinds of variables) ---
    lb_dc = [None] * 19
    ub_dc = [None] * 19
    lb_default = -1e4
    ub_default = 1e4

    # --- 1 DC nodal voltage squared -vn2_dc: nbuses_dc x 1 ---
    model.vn2_dc = Var(range(nbuses_dc), domain=Reals)
    lb_dc[0] = bus_dc[:, 12] ** 2
    ub_dc[0] = bus_dc[:, 11] ** 2
    for i in range(nbuses_dc):
        model.addconstraints.add(model.vn2_dc[i] >= lb_dc[0][i])
        model.addconstraints.add(model.vn2_dc[i] <= ub_dc[0][i])

    # --- 2. DC nodal active power injection - pn_dc: nbuses_dc x 1 ---
    model.pn_dc = Var(range(nbuses_dc), domain=Reals)
    lb_dc[1] = np.full(nbuses_dc, lb_default)  
    ub_dc[1] = np.full(nbuses_dc, ub_default)
    for i in range(nbuses_dc):
        model.addconstraints.add(model.pn_dc[i] >= lb_dc[1][i])
        model.addconstraints.add(model.pn_dc[i] <= ub_dc[1][i])

    # --- 3 VSC active power injection at node s -ps_dc: nconvs_dc x 1 ---
    model.ps_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[2] = np.full(nconvs_dc, lb_default)
    ub_dc[2] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.ps_dc[i] >= lb_dc[2][i])
        model.addconstraints.add(model.ps_dc[i] <= ub_dc[2][i])
 
    # --- 4. VSC reactive power injection at node s - qs_dc: nconvs_dc x 1 ---
    model.qs_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[3] = np.full(nconvs_dc, lb_default)
    ub_dc[3] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.qs_dc[i] >= lb_dc[3][i])
        model.addconstraints.add(model.qs_dc[i] <= ub_dc[3][i])
   
    # --- 5. VSC active power injection at node c - pc_dc: nconvs_dc x 1 ---
    model.pc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[4] = np.full(nconvs_dc, lb_default)
    ub_dc[4] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.pc_dc[i] >= lb_dc[4][i])
        model.addconstraints.add(model.pc_dc[i] <= ub_dc[4][i])

    # --- 6. VSC reactive power injection at node c - qc_dc: nconvs_dc x 1 ---
    model.qc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[5] = np.full(nconvs_dc, lb_default)
    ub_dc[5] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.qc_dc[i] >= lb_dc[5][i])
        model.addconstraints.add(model.qc_dc[i] <= ub_dc[5][i])

    # --- 7. PCC side voltage squared - v2s_dc: nconvs_dc x 1 ---
    model.v2s_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[6] = conv_dc[:, 15] ** 2
    ub_dc[6] = conv_dc[:, 14] ** 2
    for i in range(nconvs_dc):
        model.addconstraints.add(model.v2s_dc[i] >= lb_dc[6][i])
        model.addconstraints.add(model.v2s_dc[i] <= ub_dc[6][i])

    # --- 8. Converter side voltage squared - v2c_dc: nconvs_dc x 1 ---
    model.v2c_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[7] = conv_dc[:, 15] ** 2
    ub_dc[7] = conv_dc[:, 14] ** 2
    for i in range(nconvs_dc):
        model.addconstraints.add(model.v2c_dc[i] >= lb_dc[7][i])
        model.addconstraints.add(model.v2c_dc[i] <= ub_dc[7][i])

    # --- 9. VSC current magnitude - Ic_dc: nconvs_dc x 1 ---
    model.Ic_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[8] = np.zeros(nconvs_dc)
    ub_dc[8] = conv_dc[:, 16]
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Ic_dc[i] >= lb_dc[8][i])
        model.addconstraints.add(model.Ic_dc[i] <= ub_dc[8][i])
   
    # --- 10. VSC current squared - lc_dc: nconvs_dc x 1 ---
    model.lc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[9] = np.zeros(nconvs_dc)
    ub_dc[9] = conv_dc[:, 16] ** 2
    for i in range(nconvs_dc):
        model.addconstraints.add(model.lc_dc[i] >= lb_dc[9][i])
        model.addconstraints.add(model.lc_dc[i] <= ub_dc[9][i])

    # --- 11. DC branch power flow - pij_dc: nbuses_dc x nbuses_dc ---
    model.pij_dc = Var(range(nbuses_dc), range(nbuses_dc), domain=Reals)
    lb_dc[10] = np.full(nconvs_dc * nconvs_dc, lb_default)
    ub_dc[10] = np.full(nconvs_dc * nconvs_dc, ub_default)
    lb_dc[10] = lb_dc[10].reshape(nbuses_dc, nbuses_dc)
    ub_dc[10] = ub_dc[10].reshape(nbuses_dc, nbuses_dc)
    for i in range(nbuses_dc):
        for j in range(nbuses_dc):
            model.addconstraints.add(model.pij_dc[i, j] >= lb_dc[10][i, j])
            model.addconstraints.add(model.pij_dc[i, j] <= ub_dc[10][i, j])

    # --- 12. DC branch current squared - lij_dc: nbuses_dc x nbuses_dc ---
    model.lij_dc = Var(range(nbuses_dc), range(nbuses_dc), domain=Reals)
    lb_dc[11] = np.full(nconvs_dc * nconvs_dc, lb_default)
    ub_dc[11] = np.full(nconvs_dc * nconvs_dc, ub_default)
    lb_dc[11] = lb_dc[11].reshape(nbuses_dc, nbuses_dc)
    ub_dc[11] = ub_dc[11].reshape(nbuses_dc, nbuses_dc)
    for i in range(nbuses_dc):
        for j in range(nbuses_dc):
            model.addconstraints.add(model.lij_dc[i, j] >= lb_dc[11][i, j])
            model.addconstraints.add(model.lij_dc[i, j] <= ub_dc[11][i, j])

    # --- 13 VSC SOC relaxed term no.1 -Ctt_dc: nconvs_dc x 1 ---
    model.Ctt_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[12] = np.full(nconvs_dc, lb_default)
    ub_dc[12] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Ctt_dc[i] >= lb_dc[12][i])
        model.addconstraints.add(model.Ctt_dc[i] <= ub_dc[12][i])
   
    # --- 14 VSC SOC relaxed term no.2 -Ccc_dc: nconvs_dc x 1 ---
    model.Ccc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[13] = np.full(nconvs_dc, lb_default)
    ub_dc[13] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Ccc_dc[i] >= lb_dc[13][i])
        model.addconstraints.add(model.Ccc_dc[i] <= ub_dc[13][i])

    # --- 15 VSC SOC relaxed term no.3 -Ctc_dc: nconvs_dc x 1 ---
    model.Ctc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[14] = np.full(nconvs_dc, lb_default)
    ub_dc[14] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Ctc_dc[i] >= lb_dc[14][i])
        model.addconstraints.add(model.Ctc_dc[i] <= ub_dc[14][i])

    # --- 16 VSC SOC relaxed term no.4 -Stc_dc: nconvs_dc x 1 ---
    model.Stc_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[15] = np.full(nconvs_dc, lb_default)
    ub_dc[15] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Stc_dc[i] >= lb_dc[15][i])
        model.addconstraints.add(model.Stc_dc[i] <= ub_dc[15][i])

    # --- 17 VSC SOC relaxed term no.5 -Cct_dc: nconvs_dc x 1 ---
    model.Cct_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[16] = np.full(nconvs_dc, lb_default)
    ub_dc[16] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Cct_dc[i] >= lb_dc[16][i])
        model.addconstraints.add(model.Cct_dc[i] <= ub_dc[16][i])

    # --- 18 VSC SOC relaxed term no.6 -Sct_dc: nconvs_dc x 1 ---
    model.Sct_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[17] = np.full(nconvs_dc, lb_default)
    ub_dc[17] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.Sct_dc[i] >= lb_dc[17][i])
        model.addconstraints.add(model.Sct_dc[i] <= ub_dc[17][i])

    # --- 19 VSC power loss -convPloss_dc: nconvs_dc x 1 ---
    model.convPloss_dc = Var(range(nconvs_dc), domain=Reals)
    lb_dc[18] = np.full(nconvs_dc, lb_default)
    ub_dc[18] = np.full(nconvs_dc, ub_default)
    for i in range(nconvs_dc):
        model.addconstraints.add(model.convPloss_dc[i] >= lb_dc[18][i])
        model.addconstraints.add(model.convPloss_dc[i] <= ub_dc[18][i])

    # ------------------------------
    # DC Power Flow Constraints (Second-Order Cone Relaxation)
    # ------------------------------
    zij_dc = 1.0 / np.abs(ybus_dc.toarray())
    zij_dc = zij_dc - np.diag(np.diag(zij_dc))
    zij_dc[np.isinf(zij_dc)] = 1e4

    for i in range(nbuses_dc):
        model.addconstraints.add(model.pn_dc[i]  == pol_dc * sum(model.pij_dc[i, j] for j in range(nbuses_dc)))
        model.addconstraints.add(model.vn2_dc[i] >= 0)
        for j in range(nbuses_dc):
            model.addconstraints.add(model.pij_dc[i, j] + model.pij_dc[j, i] == zij_dc[i, j] * model.lij_dc[i, j])
            model.addconstraints.add(model.vn2_dc[i] - model.vn2_dc[j] == zij_dc[i, j] * (model.pij_dc[i, j] - model.pij_dc[j, i]))
            model.addconstraints.add(model.pij_dc[i, j]**2 <= model.lij_dc[i, j] * model.vn2_dc[i])
            model.addconstraints.add(model.lij_dc[i, j] >= 0)

    # ------------------------------
    # VSC AC Side Power Flow Constraints (Second-Order Cone Relaxation)
    # ------------------------------
    for i in range(nbuses_dc):
        model.addconstraints.add(model.ps_dc[i] == model.Ctt_dc[i]*gtfc_dc[i] - model.Ctc_dc[i]*gtfc_dc[i] + model.Stc_dc[i]*btfc_dc[i])
        model.addconstraints.add(model.qs_dc[i] == -model.Ctt_dc[i]*btfc_dc[i] + model.Ctc_dc[i]*btfc_dc[i] + model.Stc_dc[i]*gtfc_dc[i])
        model.addconstraints.add(model.pc_dc[i] == model.Ccc_dc[i]*gtfc_dc[i] - model.Cct_dc[i]*gtfc_dc[i] + model.Sct_dc[i]*btfc_dc[i])
        model.addconstraints.add(model.qc_dc[i] == -model.Ccc_dc[i]*btfc_dc[i] + model.Cct_dc[i]*btfc_dc[i] + model.Sct_dc[i]*gtfc_dc[i])
        model.addconstraints.add(model.Ctc_dc[i] == model.Cct_dc[i])
        model.addconstraints.add(model.Stc_dc[i] + model.Sct_dc[i] == 0)   
        model.addconstraints.add(model.Cct_dc[i]**2 + model.Sct_dc[i]**2 <= model.Ccc_dc[i] * model.Ctt_dc[i])
        model.addconstraints.add(model.Ctc_dc[i]**2 + model.Stc_dc[i]**2 <= model.Ccc_dc[i] * model.Ctt_dc[i])
        model.addconstraints.add(model.Ccc_dc[i] >= 0)
        model.addconstraints.add(model.Ctt_dc[i] >= 0)
        model.addconstraints.add(model.v2s_dc[i] == model.Ctt_dc[i]) 
        model.addconstraints.add(model.v2c_dc[i] == model.Ccc_dc[i])
    
    # ------------------------------
    # Converter Loss Constraints (Second-Order Cone Relaxation)
    # ------------------------------   
    for i in range(nbuses_dc):
        model.addconstraints.add(model.pc_dc[i] + model.pn_dc[i] + model.convPloss_dc[i] == 0)
        model.addconstraints.add(model.convPloss_dc[i] >= 0)
        model.addconstraints.add(model.convPloss_dc[i] <= 1)
        model.addconstraints.add(model.convPloss_dc[i] == aloss_dc[i] + bloss_dc[i] * model.Ic_dc[i] + closs_dc[i] * model.lc_dc[i])
        model.addconstraints.add(model.pc_dc[i]**2 + model.qc_dc[i]**2 <= model.lc_dc[i] * model.v2c_dc[i])
        model.addconstraints.add(model.lc_dc[i] >= 0)
        model.addconstraints.add(model.Ic_dc[i] >= 0)
        model.addconstraints.add(model.v2c_dc[i] >= 0)
        model.addconstraints.add(model.Ic_dc[i]**2 <= model.lc_dc[i])

    # ------------------------------
    # VSC Converter Control Constraints
    # ------------------------------
    # If we hope control setpoints of VSC converter be optimized, 
    # the below constraints need to be removed
    if vscControl:
        for i in range(nbuses_dc):
            # dc side control
            if conv_dc[i, 3] == 1: # dc p control
                model.addconstraints.add(model.pn_dc[i] == -conv_dc[i, 5] / baseMW_dc)
            elif conv_dc[i, 3] == 2: # dc voltage control
                model.addconstraints.add(model.vn2_dc[i] == conv_dc[i, 7] ** 2)
            else:
                model.pn_dc[i] == (conv_dc[i, 23] - 1 / conv_dc[i, 22] * (0.5 + 0.5 * model.vn2_dc[i] - conv_dc[i, 24])) / baseMW_dc * (-1)
            # ac side control
            if conv_dc[i, 4] == 1: # ac q control
                model.addconstraints.add(model.qs_dc[i] == -conv_dc[i, 6] / baseMW_dc)
            else: # ac voltage control
                model.addconstraints.add(model.v2s_dc[i] == conv_dc[i, 7] ** 2)
            # converter mode
            if convState[i] == 0:  # Rectifier mode
                model.addconstraints.add(model.ps_dc[i] >= 0)
                model.addconstraints.add(model.pn_dc[i] >= 0)
                model.addconstraints.add(model.pc_dc[i] <= 0)
            else: # inverter mode
                model.addconstraints.add(model.ps_dc[i] <= 0)
                model.addconstraints.add(model.pn_dc[i] <= 0)
                model.addconstraints.add(model.pc_dc[i] >= 0)


"""
=== setup_ac ===

This function defines the AC grid optimization variables, their bounds,
and operational constraints.

The decision variable vector is partitioned into blocks as follows:
    - 1. vn2_ac         : AC nodal voltage squared
    - 2. pn_ac          : AC active power injection
    - 3. qn_ac          : AC reactive power injection
    - 4. pgen_ac        : Generator active power output
    - 5. qgen_ac        : Generator reactive power output
    - 6. pij_ac         : AC branch active power flow
    - 7. qij_ac         : AC branch reactive power flow
    - 8. ss_ac          : AC SOC relaxed term no.1
    - 9. cc_ac          : AC SOC relaxed term no.2
    - 10. pres_ac       : RES active power output
    - 11. qres_ac       : RES reactive power output
 
Inputs:
    - model: A Pyomo model.
    - res_params_ac : Dictionary containing AC grid data, including:
          baseMVA_ac, ngrids, nbuses_ac, ngens_ac, bus_ac, generator_ac,
          BB_ac, GG_ac.

"""
def setup_ac(model:ConcreteModel, res_params_ac: Dict[str, Any]) -> None:

    # Extract AC parameters will be used
    baseMVA_ac      = res_params_ac["baseMVA_ac"]
    ngrids          = res_params_ac["ngrids"]
    nbuses_ac       = res_params_ac["nbuses_ac"]
    ngens_ac        = res_params_ac["ngens_ac"]
    nress_ac        = res_params_ac["nress_ac"]
    bus_ac          = res_params_ac["bus_ac"]
    generator_ac    = res_params_ac["generator_ac"]
    res_ac          = res_params_ac["res_ac"]
    BB_ac           = res_params_ac["BB_ac"]
    GG_ac           = res_params_ac["GG_ac"]
    sres_ac         = res_params_ac["sres_ac"]

    # Pre-allocate 
    lb_ac = [None] * ngrids
    ub_ac = [None] * ngrids
    
     # --- Initialization (a totoal of 9 kinds of variables) ---
    for ng in range(ngrids):
        lb_ac[ng] = [None] * 11
        ub_ac[ng] = [None] * 11
        lb_default = -1e4
        ub_default = 1e4

    # --- 1 AC nodal voltage squared -vn2_ac: nbuses x 1 ---
    model.vn2_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][0] = bus_ac[ng][:, 12] **2
        ub_ac[ng][0] = bus_ac[ng][:, 11] **2
        for i in range(nbuses_ac[ng]):
            model.addconstraints.add(model.vn2_ac[ng, i] >= lb_ac[ng][0][i])
            model.addconstraints.add(model.vn2_ac[ng, i] <= ub_ac[ng][0][i])

    # --- 2 AC active power injection -pn_ac: nbuses x 1 ---
    model.pn_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][1] = np.full(nbuses_ac[ng], lb_default)
        ub_ac[ng][1] = np.full(nbuses_ac[ng], ub_default)
        for i in range(nbuses_ac[ng]):
            model.addconstraints.add(model.pn_ac[ng, i] >= lb_ac[ng][1][i])
            model.addconstraints.add(model.pn_ac[ng, i] <= ub_ac[ng][1][i])

    # --- 3 AC reactive power injection -qn_ac: nbuses x 1 ---
    model.qn_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][2] = np.full(nbuses_ac[ng], lb_default)
        ub_ac[ng][2] = np.full(nbuses_ac[ng], ub_default)
        for i in range(nbuses_ac[ng]):
            model.addconstraints.add(model.qn_ac[ng, i] >= lb_ac[ng][2][i])
            model.addconstraints.add(model.qn_ac[ng, i] <= ub_ac[ng][2][i])
    
    # --- 4 AC generator active power output -pgen_ac: ngens x 1 ---
    model.pgen_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(ngens_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][3] = generator_ac[ng][:, 9] * generator_ac[ng][:, 7] / baseMVA_ac
        ub_ac[ng][3] = generator_ac[ng][:, 8] * generator_ac[ng][:, 7] / baseMVA_ac
        for i in range(ngens_ac[ng]):
            model.addconstraints.add(model.pgen_ac[ng, i] >= lb_ac[ng][3][i])
            model.addconstraints.add(model.pgen_ac[ng, i] <= ub_ac[ng][3][i])
        
    # --- 5 AC generator reactive power output -qgen_ac: ngens x 1 ---
    model.qgen_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(ngens_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][4] = generator_ac[ng][:, 4] * generator_ac[ng][:, 7] / baseMVA_ac
        ub_ac[ng][4] = generator_ac[ng][:, 3] * generator_ac[ng][:, 7] / baseMVA_ac
        for i in range(ngens_ac[ng]):
            model.addconstraints.add(model.qgen_ac[ng, i] >= lb_ac[ng][4][i])
            model.addconstraints.add(model.qgen_ac[ng, i] <= ub_ac[ng][4][i])

    # --- 6 AC branch active power flow  -pij_ac: nbuses x nbuses ---
    model.pij_ac = Var(
        [(ng, i, j) for ng in range(ngrids) for i in range(nbuses_ac[ng]) for j in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][5] = np.full((nbuses_ac[ng], nbuses_ac[ng]), lb_default)
        ub_ac[ng][5] = np.full((nbuses_ac[ng], nbuses_ac[ng]), ub_default)
        for i in range(nbuses_ac[ng]):
            for j in range(nbuses_ac[ng]):
                model.addconstraints.add(model.pij_ac[ng, i, j] >= lb_ac[ng][5][i, j])
                model.addconstraints.add(model.pij_ac[ng, i, j] <= ub_ac[ng][5][i, j])

    # --- 7 AC branch reactive power flow -qij_ac: nbuses x nbuses ---
    model.qij_ac = Var(
        [(ng, i, j) for ng in range(ngrids) for i in range(nbuses_ac[ng]) for j in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][6] = np.full((nbuses_ac[ng], nbuses_ac[ng]), lb_default)
        ub_ac[ng][6] = np.full((nbuses_ac[ng], nbuses_ac[ng]), ub_default)
        for i in range(nbuses_ac[ng]):
            for j in range(nbuses_ac[ng]):
                model.addconstraints.add(model.qij_ac[ng, i, j] >= lb_ac[ng][6][i, j])
                model.addconstraints.add(model.qij_ac[ng, i, j] <= ub_ac[ng][6][i, j])

    # --- 8 AC SOC relaxed term no.1 -ss_ac: nbuses x nbuses ---
    model.ss_ac = Var(
        [(ng, i, j) for ng in range(ngrids) for i in range(nbuses_ac[ng]) for j in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][7] = np.full((nbuses_ac[ng], nbuses_ac[ng]), lb_default)
        ub_ac[ng][7] = np.full((nbuses_ac[ng], nbuses_ac[ng]), ub_default)
        for i in range(ngens_ac[ng]):
            for j in range(ngens_ac[ng]):
                model.addconstraints.add(model.ss_ac[ng, i, j] >= lb_ac[ng][7][i, j])
                model.addconstraints.add(model.ss_ac[ng, i, j] <= ub_ac[ng][7][i, j])

    # --- 9 AC SOC relaxed term no.2 -cc_ac: nbuses x nbuses ---
    model.cc_ac = Var(
        [(ng, i, j) for ng in range(ngrids) for i in range(nbuses_ac[ng]) for j in range(nbuses_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):           
        lb_ac[ng][8] = np.full((nbuses_ac[ng], nbuses_ac[ng]), lb_default)
        ub_ac[ng][8] = np.full((nbuses_ac[ng], nbuses_ac[ng]), ub_default)
        for i in range(nbuses_ac[ng]):
            for j in range(nbuses_ac[ng]):
                model.addconstraints.add(model.cc_ac[ng, i, j] >= lb_ac[ng][8][i, j])
                model.addconstraints.add(model.cc_ac[ng, i, j] <= ub_ac[ng][8][i, j])

    # --- 10 AC RES active power output -pres_ac: nress x 1 ---
    model.pres_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(nress_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][9] = np.full(nress_ac[ng], 0)
        ub_ac[ng][9] = res_ac[ng][:, 1] / baseMVA_ac
        for i in range(nress_ac[ng]):
            model.addconstraints.add(model.pres_ac[ng, i] >= lb_ac[ng][9][i])
            model.addconstraints.add(model.pres_ac[ng, i] <= ub_ac[ng][9][i])

    # --- 11 AC RES reactive power output -qres_ac: nress x 1 ---
    model.qres_ac = Var(
        [(ng, i) for ng in range(ngrids) for i in range(nress_ac[ng])],
        domain=Reals)
    for ng in range(ngrids):
        lb_ac[ng][10] = np.full(nress_ac[ng], lb_default)
        ub_ac[ng][10] = np.full(nress_ac[ng], ub_default)
        for i in range(nress_ac[ng]):
            model.addconstraints.add(model.qres_ac[ng, i] >= lb_ac[ng][10][i])
            model.addconstraints.add(model.qres_ac[ng, i] <= ub_ac[ng][10][i])

      
    for ng in range(ngrids):
        # ------------------------------
        # AC Nodal Power Balance Constraints 
        # ------------------------------
        for i in range(nbuses_ac[ng]):
            pn_constraint_ac_expr = BB_ac[ng][i, i] * model.ss_ac[ng, i, i]
            qn_constraint_ac_expr = GG_ac[ng][i, i] * model.ss_ac[ng, i, i]
            for j in range(nbuses_ac[ng]):
                pn_constraint_ac_expr += model.cc_ac[ng, i, j] * GG_ac[ng][i, j] - model.ss_ac[ng, i, j] * BB_ac[ng][i, j]
                qn_constraint_ac_expr -= model.cc_ac[ng, i, j] * BB_ac[ng][i, j] + model.ss_ac[ng, i, j] * GG_ac[ng][i, j]
           
            model.addconstraints.add(model.pn_ac[ng, i] == pn_constraint_ac_expr)
            model.addconstraints.add(model.qn_ac[ng, i] == qn_constraint_ac_expr)
        
        # ------------------------------
        # Branch Flow Calculation Constraints
        # ------------------------------    
        for i in range(nbuses_ac[ng]):
            for j in range(nbuses_ac[ng]):
                pij_constraint_ac_expr = (model.cc_ac[ng, i, i] - model.cc_ac[ng, i, j]) * (-GG_ac[ng][i, j]) \
                                + model.ss_ac[ng, i, j] * (-BB_ac[ng][i, j])
                model.addconstraints.add(model.pij_ac[ng, i, j] == pij_constraint_ac_expr)

                qij_constraint_ac_expr = -(model.cc_ac[ng, i, i] - model.cc_ac[ng, i, j]) * (-BB_ac[ng][i, j]) \
                                + model.ss_ac[ng, i, j] * (-GG_ac[ng][i, j])
                model.addconstraints.add(model.qij_ac[ng, i, j] == qij_constraint_ac_expr)

        # ------------------------------
        # Symmetry and Relaxation
        # ------------------------------
        for i in range(nbuses_ac[ng]):
            model.addconstraints.add(model.cc_ac[ng, i, i] == model.vn2_ac[ng, i])
            model.addconstraints.add(model.cc_ac[ng, i, i] >= 0)
            # for j in range(nbuses_ac[ng]):
            #     model.addconstraints.add(model.cc_ac[ng, i, j] == model.cc_ac[ng, j, i])
            #     model.addconstraints.add(model.ss_ac[ng, i, j] + model.ss_ac[ng, j, i] == 0)
            #     model.addconstraints.add(model.cc_ac[ng, i, j] ** 2 + model.ss_ac[ng, i, j] ** 2 <= model.cc_ac[ng, i, i] * model.cc_ac[ng, j, j])
        for i, j in itertools.combinations(range(nbuses_ac[ng]), 2):
            model.addconstraints.add(model.cc_ac[ng, i, j] == model.cc_ac[ng, j, i])
            model.addconstraints.add(model.ss_ac[ng, i, j] + model.ss_ac[ng, j, i] == 0)
            model.addconstraints.add(model.cc_ac[ng, i, j]**2 + model.ss_ac[ng, i, j]**2 <= model.cc_ac[ng, i, i] * model.cc_ac[ng, j, j])

        # ------------------------------
        # AC RES Capacity Constraints (Polygon approximation)
        # ------------------------------
        for k in range(8):
            ck = math.cos(k * math.pi / 8)
            sk = math.sin(k * math.pi / 8)
            for i in range(nress_ac[ng]):
                model.addconstraints.add(ck * model.pres_ac[ng, i] + sk * model.qres_ac[ng, i] <= sres_ac[ng][i])
                model.addconstraints.add(-sres_ac[ng][i] <= ck * model.pres_ac[ng, i] + sk * model.qres_ac[ng, i])

        

"""
=== setup_cp ===

This function creates two groups of constraints:
    1. Power Coupling Constraints
    2. Voltage Coupling Constraints
 
Inputs:
    - model: A Pyomo model.
    - res_params_dc : Dictionary containing DC grid data.
    - res_params_ac : Dictionary containing AC grid data.

"""
def setup_cp(model:ConcreteModel, res_params_dc: Dict[str, Any], res_params_ac: Dict[str, Any]) -> None:
    
    # Extract required parameters
    ngrids          = res_params_ac["ngrids"]
    nbuses_ac       = res_params_ac["nbuses_ac"]
    ngens_ac        = res_params_ac["ngens_ac"]
    nress_ac        = res_params_ac["nress_ac"]
    generator_ac    = res_params_ac["generator_ac"]
    res_ac          = res_params_ac["res_ac"]
    pd_ac           = res_params_ac["pd_ac"]
    qd_ac           = res_params_ac["qd_ac"]
    conv_dc         = res_params_dc["conv_dc"]
    nconvs_dc       = res_params_dc["nconvs_dc"]

    # Loop over each AC grid to set up nodal power balance constraints
    for ng in range(ngrids): 
        pm_ac = {i: 0.0 for i in range(nbuses_ac[ng])}
        qm_ac = {i: 0.0 for i in range(nbuses_ac[ng])}
        
        #  If the AC node connected with generator
        for i in range(ngens_ac[ng]):
            index = int(generator_ac[ng][i, 0]) - 1
            pm_ac[index] += model.pgen_ac[ng, i]
            qm_ac[index] += model.qgen_ac[ng, i]
        # If the AC node connected with VSC
        for i in range(nconvs_dc):
            if int(conv_dc[i, 2]) == ng + 1:  
                index = int(conv_dc[i, 1]) - 1
                pm_ac[index] -= model.ps_dc[i]
                qm_ac[index] -= model.qs_dc[i]
        # If the AC node connected with RES
        for i in range(nress_ac[ng]):
            index = int(res_ac[ng][i, 0]) - 1
            pm_ac[index] += model.pres_ac[ng, i]
            qm_ac[index] += model.qres_ac[ng, i]

        #  Every AC node have load 
        for i in range(nbuses_ac[ng]):
            model.addconstraints.add(model.pn_ac[ng, i] == pm_ac[i] - pd_ac[ng][i])
            model.addconstraints.add(model.qn_ac[ng, i] == qm_ac[i] - qd_ac[ng][i])

    # Voltage coupling constraints:
    for i in range(nconvs_dc):
        bus_index = int(conv_dc[i, 1]) - 1 
        ng = int(conv_dc[i, 2]) - 1 
        model.addconstraints.add(model.vn2_ac[ng, bus_index] == model.v2s_dc[i])

"""
=== setup_obj ===

This function creates two groups of constraints:
    1. Power Coupling Constraints
    2. Voltage Coupling Constraints
 
Inputs:
    - model: A Pyomo model.
    - res_params_dc : Dictionary containing DC grid data.
    - res_params_ac : Dictionary containing AC grid data.

"""
def setup_obj(model:ConcreteModel, res_params_dc: Dict[str, Any], res_params_ac: Dict[str, Any]) -> None:

    # Extract parameters from the input dictionary
    ngrids = res_params_ac["ngrids"]
    generator_ac = res_params_ac["generator_ac"]
    gencost_ac = res_params_ac["gencost_ac"]
    res_ac = res_params_ac["res_ac"]
    baseMVA_ac = res_params_ac["baseMVA_ac"]
    ngens_ac = res_params_ac["ngens_ac"]
    nress_ac = res_params_ac["nress_ac"]
   
    # Pre-allocate 
    obj = [None] * ngrids
    actgen_ac = [None] * ngrids
    actres_ac = [None] * ngrids

    # Define generation and RES costs
    for ng in range(ngrids):
        actgen_ac[ng] = generator_ac[ng][:, 7] 
        actres_ac[ng] = res_ac[ng][:, 10]  
         # Quadratic cost type
        if gencost_ac[ng][0, 3] == 3: 
            obj[ng] = sum(
                actgen_ac[ng][i] * (
                    baseMVA_ac**2 * gencost_ac[ng][i, 4] * model.pgen_ac[ng, i]**2 +
                    baseMVA_ac * gencost_ac[ng][i, 5] * model.pgen_ac[ng, i] +
                    gencost_ac[ng][i, 6]
                ) for i in range(ngens_ac[ng])
            )
        if res_ac[ng][0, 6] == 3: 
            obj[ng] += sum(
                actres_ac[ng][i] * (
                    baseMVA_ac**2 * res_ac[ng][i, 7] * model.pres_ac[ng, i]**2 +
                    baseMVA_ac * res_ac[ng][i, 8] * model.pres_ac[ng, i] +
                    res_ac[ng][i, 9]
                ) for i in range(nress_ac[ng])
            )

        # Linear cost type
        if gencost_ac[ng][0, 3] == 2:  
             obj[ng] = sum(
                actgen_ac[ng][i] * (
                    baseMVA_ac * gencost_ac[ng][i, 4] * model.pgen_ac[ng, i] +
                    gencost_ac[ng][i, 5]
                ) for i in range(ngens_ac[ng])
            )
             
        if res_ac[ng][0, 6] == 2:  
             obj[ng] += sum(
                actres_ac[ng][i] * (
                    baseMVA_ac * res_ac[ng][i, 8] * model.pres_ac[ng, i] +
                    res_ac[ng][i, 9]
                ) for i in range(nress_ac[ng])
            )
             
       
       
    def objective_rule(model):
        return sum(obj[ng] for ng in range(ngrids))

    model.objective = Objective(rule=objective_rule, sense=minimize)

def extract_vals_dc(
    model: ConcreteModel,
    nbuses_dc: int,
    nconvs_dc: int,
) -> None:
    """
    Extract DC side optimization variable values from the Pyomo model.
    
    Returns a tuple of NumPy arrays corresponding to:
      vn2_dc_k, pn_dc_k, ps_dc_k, qs_dc_k, pc_dc_k, qc_dc_k,
      v2s_dc_k, v2c_dc_k, Ic_dc_k, lc_dc_k, pij_dc_k, lij_dc_k,
      Ctt_dc_k, Ccc_dc_k, Ctc_dc_k, Stc_dc_k, Cct_dc_k, Sct_dc_k, convPloss_dc_k
    """
    vn2_dc_k = np.array([value(model.vn2_dc[i]) for i in range(nbuses_dc)])
    pn_dc_k  = np.array([value(model.pn_dc[i]) for i in range(nbuses_dc)])
    ps_dc_k  = np.array([value(model.ps_dc[i]) for i in range(nconvs_dc)])
    qs_dc_k  = np.array([value(model.qs_dc[i]) for i in range(nconvs_dc)])
    pc_dc_k  = np.array([value(model.pc_dc[i]) for i in range(nconvs_dc)])
    qc_dc_k  = np.array([value(model.qc_dc[i]) for i in range(nconvs_dc)])
    v2s_dc_k = np.array([value(model.v2s_dc[i]) for i in range(nconvs_dc)])
    v2c_dc_k = np.array([value(model.v2c_dc[i]) for i in range(nconvs_dc)])
    Ic_dc_k  = np.array([value(model.Ic_dc[i]) for i in range(nconvs_dc)])
    lc_dc_k  = np.array([value(model.lc_dc[i]) for i in range(nconvs_dc)])
    
    pij_dc_k = np.array([[value(model.pij_dc[i, j]) for j in range(nbuses_dc)]
                           for i in range(nbuses_dc)])
    lij_dc_k = np.array([[value(model.lij_dc[i, j]) for j in range(nbuses_dc)]
                           for i in range(nbuses_dc)])
    
    Ctt_dc_k = np.array([value(model.Ctt_dc[i]) for i in range(nconvs_dc)])
    Ccc_dc_k = np.array([value(model.Ccc_dc[i]) for i in range(nconvs_dc)])
    Ctc_dc_k = np.array([value(model.Ctc_dc[i]) for i in range(nconvs_dc)])
    Stc_dc_k = np.array([value(model.Stc_dc[i]) for i in range(nconvs_dc)])
    Cct_dc_k = np.array([value(model.Cct_dc[i]) for i in range(nconvs_dc)])
    Sct_dc_k = np.array([value(model.Sct_dc[i]) for i in range(nconvs_dc)])
    convPloss_dc_k = np.array([value(model.convPloss_dc[i]) for i in range(nconvs_dc)])
    
    return (vn2_dc_k, pn_dc_k, ps_dc_k, qs_dc_k, pc_dc_k, qc_dc_k,
            v2s_dc_k, v2c_dc_k, Ic_dc_k, lc_dc_k, pij_dc_k, lij_dc_k,
            Ctt_dc_k, Ccc_dc_k, Ctc_dc_k, Stc_dc_k, Cct_dc_k, Sct_dc_k, convPloss_dc_k)

def extract_vals_ac(
    model: ConcreteModel,
    ngrids: int,
    nbuses_ac: int,
    ngens_ac: int,
    nress_ac: int,
) -> None:
    """
    Extract AC side optimization variable values from the model.
    Assumes variables are indexed by (ng, i) for scalar variables and (ng, i, j) for matrix variables.
    
    Returns a tuple containing lists (one entry per grid) for:
       vn2_ac_k, pn_ac_k, qn_ac_k, pgen_ac_k, qgen_ac_k,
       pij_ac_k, qij_ac_k, ss_ac_k, cc_ac_k.
    """
    vn2_ac_k  = []
    pn_ac_k   = []
    qn_ac_k   = []
    pgen_ac_k = []
    qgen_ac_k = []
    pij_ac_k  = []
    qij_ac_k  = []
    ss_ac_k   = []
    cc_ac_k   = []
    pres_ac_k = []
    qres_ac_k = []
    
    for ng in range(ngrids):
        vn2 = np.array([value(model.vn2_ac[ng, i]) for i in range(nbuses_ac[ng])])
        pn  = np.array([value(model.pn_ac[ng, i]) for i in range(nbuses_ac[ng])])
        qn  = np.array([value(model.qn_ac[ng, i]) for i in range(nbuses_ac[ng])])
        pgen = np.array([value(model.pgen_ac[ng, i]) for i in range(ngens_ac[ng])])
        qgen = np.array([value(model.qgen_ac[ng, i]) for i in range(ngens_ac[ng])])   
        pij = np.array([[value(model.pij_ac[ng, i, j]) for j in range(nbuses_ac[ng])]
                        for i in range(nbuses_ac[ng])])
        qij = np.array([[value(model.qij_ac[ng, i, j]) for j in range(nbuses_ac[ng])]
                        for i in range(nbuses_ac[ng])])
        ss = np.array([[value(model.ss_ac[ng, i, j]) for j in range(nbuses_ac[ng])]
                       for i in range(nbuses_ac[ng])])
        cc = np.array([[value(model.cc_ac[ng, i, j]) for j in range(nbuses_ac[ng])]
                       for i in range(nbuses_ac[ng])])
        pres = np.array([value(model.pres_ac[ng, i]) for i in range(nress_ac[ng])])
        qres = np.array([value(model.qres_ac[ng, i]) for i in range(nress_ac[ng])])  
        
        vn2_ac_k.append(vn2)
        pn_ac_k.append(pn)
        qn_ac_k.append(qn)
        pgen_ac_k.append(pgen)
        qgen_ac_k.append(qgen)
        pij_ac_k.append(pij)
        qij_ac_k.append(qij)
        ss_ac_k.append(ss)
        cc_ac_k.append(cc)
        pres_ac_k.append(pres)
        qres_ac_k.append(qres)
    
    return (vn2_ac_k, pn_ac_k, qn_ac_k, pgen_ac_k, qgen_ac_k,
        pij_ac_k, qij_ac_k, ss_ac_k, cc_ac_k, pres_ac_k, qres_ac_k)
    
   
if __name__ == "__main__":
    result_opf = solve_opf("mtdc3slack_a", "ac14ac57")
