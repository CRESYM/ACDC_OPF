"""
Module for extracting AC and DC grid parameters.

Two functions, `params_dc` and `params_ac`, extract key parameters 
for DC and AC networks

"""
import math
import numpy as np
from makeYbus import makeYbus
from create_acdc import create_ac, create_dc 

def params_dc(dcgrid_name: str) -> dict:
    """
    Compute and return DC grid parameters by reading the DC grid data from CSV files.

    This function extracts and computes parameters for the DC network from the
    specified case.

    Returns dictionrary with the following keys:
        - network_dc   : dict. DC network containing all network data.
        - baseMW_dc    : ndarray (float64). DC network MW base.
        - pol_dc       : ndarray (int64). DC network pole(s).
        - nbuses_dc    : scalar (int64). Number of DC buses.
        - nbranches_dc : scalar (int64). Number of DC branches.
        - nconvs_dc    : scalar (int64). Number of converters.
        - bus_dc       : ndarray (float64). DC bus data matrix.
        - branch_dc    : ndarray (float64). DC branch data matrix.
        - conv_dc      : ndarray (float64). VSC converter data matrix.
        - ybus_dc      : ndarray (float64). DC network admittance matrix (absolute values).
        - basekV_dc    : ndarray (float64). AC voltage base for VSC converters.
        - fbus_dc      : ndarray (int64). "From" bus indices for branches.
        - tbus_dc      : ndarray (int64). "To" bus indices for branches.
        - rtf_dc       : ndarray (int64). PCC side transformer resistances (p.u.).
        - xtf_dc       : ndarray (int64). PCC side transformer reactances (p.u.).
        - bf_dc        : ndarray (int64). Filter susceptances (p.u.).
        - rec_dc       : ndarray (int64). AC terminal side converter resistances (p.u.).
        - xc_dc        : ndarray (int64). AC terminal side converter reactances (p.u.).
        - ztfc_dc      : ndarray (complex128). VSC impedances for PCC side to AC terminal side (p.u.).
        - gtfc_dc      : ndarray (float64). Real parts of 1/ztfc_dc (p.u.).
        - btfc_dc      : ndarray (float64). Imaginary parts of 1/ztfc_dc (p.u.).
        - aloss_dc     : ndarray (float64). Converter loss parameters A (p.u.).
        - bloss_dc     : ndarray (float64). Converter loss parameters B (p.u.).
        - closs_dc     : ndarray (float64). Converter loss parameters C (p.u.).
        - convState    : ndarray (int64). Converter state indicators (1 for inverter, 0 for rectifier).

    See also: create_dc.py, makeYbus.py
    """
    #--------------------------------------------------------------------------
    # Load DC grid data
    #--------------------------------------------------------------------------   
    network_dc = create_dc(dcgrid_name)
    baseMW_dc = np.array(network_dc["baseMW"], dtype = np.int64)
    bus_dc = np.array(network_dc["bus"], dtype = np.float64)
    branch_dc = np.array(network_dc["branch"], dtype = np.float64)[np.array(network_dc["branch"])[:, 10] == 1]
    conv_dc = np.array(network_dc["converter"], dtype = np.float64)
    pol_dc = np.array(network_dc["pol"], dtype = np.int64)
    basekV_dc = conv_dc[:, 13].astype(np.float64)

    # Determine the number of buses, branches, and converters
    nbuses_dc = np.int64(bus_dc.shape[0])
    nbranches_dc = np.int64(branch_dc.shape[0])
    nconvs_dc = np.int64(conv_dc.shape[0])

    # Extract branch "from" and "to" bus indices
    fbus_dc = branch_dc[:, 0].astype(np.int64)
    tbus_dc = branch_dc[:, 1].astype(np.int64)

    #--------------------------------------------------------------------------
    # Compute DC network admittance matrix (Ybus)
    #--------------------------------------------------------------------------
    ybus_dc = makeYbus(baseMW_dc, bus_dc, branch_dc)
    ybus_dc = np.abs(ybus_dc)

    #--------------------------------------------------------------------------
    # Extract VSC Impedance parameters
    # The equivalent circuit for the VSC converter is as follows:
    #
    # U_s  ● --[ r_tf + j*x_tf ]-- ● --[ r_c + j*x_c ]-- ● U_c --(VSC)--
    # PCC                                             AC terminal
    #
    # PCC side parameters (r_tf, x_tf, bf_dc) and AC terminal side 
    # parameters (r_c, x_c) are combined to form the overall converter impedance.
    #--------------------------------------------------------------------------
    # PCC side transformer parameters   
    rtf_dc = conv_dc[:, 8]
    xtf_dc = conv_dc[:, 9]
    
    # Filter parameters
    bf_dc = conv_dc[:, 10]
    
    # AC terminal side converter impedance parameters
    rc_dc = conv_dc[:, 11]
    xc_dc = conv_dc[:, 12]

    # Combined converter impedance and admittance
    ztfc_dc = (rtf_dc + rc_dc) + 1j * (xtf_dc + xc_dc)
    ztfc_dc = ztfc_dc.astype(np.complex128)
    gtfc_dc = np.real(1 / ztfc_dc).astype(np.float64)
    btfc_dc = np.imag(1 / ztfc_dc).astype(np.float64)

    #--------------------------------------------------------------------------
    # Converter Loss Parameters and State Determination
    #--------------------------------------------------------------------------
    closs_dc = np.zeros(nconvs_dc)
    convState = np.zeros(nconvs_dc)
    
    for i in range(nconvs_dc):
        if conv_dc[i, 5] >= 0:  # inverter state
            closs_dc[i] = conv_dc[i, 21]
            convState[i] = 1
        else:  # rectifier state
            closs_dc[i] = conv_dc[i, 20]
            convState[i] = 0

    # Convert loss parameters to per unit values
    closs_dc /= (basekV_dc**2 / baseMW_dc)
    aloss_dc = (conv_dc[:, 18] / baseMW_dc)
    bloss_dc = (conv_dc[:, 19] / basekV_dc)

    return {
        "network_dc": network_dc,
        "baseMW_dc": baseMW_dc,
        "bus_dc": bus_dc,
        "branch_dc": branch_dc,
        "conv_dc": conv_dc,
        "pol_dc": pol_dc,
        "basekV_dc": basekV_dc,
        "nbuses_dc": nbuses_dc,
        "nbranches_dc": nbranches_dc,
        "nconvs_dc": nconvs_dc,
        "fbus_dc": fbus_dc,
        "tbus_dc": tbus_dc,
        "ybus_dc": ybus_dc,
        "rtf_dc": rtf_dc,
        "xtf_dc": xtf_dc,
        "bf_dc": bf_dc,
        "rc_dc": rc_dc,
        "xc_dc": xc_dc,
        "ztfc_dc": ztfc_dc,
        "gtfc_dc": gtfc_dc,
        "btfc_dc": btfc_dc,
        "aloss_dc": aloss_dc,
        "bloss_dc": bloss_dc,
        "closs_dc": closs_dc,
        "convState": convState,
    }


def params_ac(acgrid_name: str) -> dict:
    """
    Compute and return AC grid parameters by reading the AC grid data from CSV files.

    This function extracts and computes parameters for the AC network from the
    specified case.

    Returns: A dictionary `ac` with the following keys:
        - network_ac            : dict. AC network containing all network data.
        - ngrids                : scalar (int64). Number of AC grids.
        - baseMVA_ac            : ndarray (float64). AC base MVA.
        - bus_entire_ac         : ndarray (float64). Complete bus data.
        - branch_entire_ac      : ndarray (float64). Complete branch data.
        - generator_entire_ac   : ndarray (float64). Complete generator data.
        - gencost_entire_ac     : ndarray (float64). Complete generation cost data.
        - res_entire_ac         : ndarray (float64). Complete RES data.
        - bus_ac                : list[ndarray (float64)]. Bus data for each AC grid.
        - branch_ac             : list[ndarray (float64)]. Branch data for each AC grid.
        - generator_ac          : list[ndarray (float64)]. Generator data for each AC grid.
        - gencost_ac            : list[ndarray (float64)]. Generator cost for each AC grid.
        - res_ac                : list[ndarray (float64)]. RES data for each AC grid.
        - recRef_ac             : list[ndarry [int64]]. Recording the reference bus for each AC grid.
        - pd_ac                 : list[ndarray (float64)]. Active/reactive loads (per unit).
        - qd_ac                 : list[ndarray (float64)]. Mapping AC bus IDs to connected DC converters.
        - nbuses_ac             : list[int64]. Number of buses for each AC grid.
        - nbranches_ac          : list[int64]. Number of branches for each AC grid.
        - ngens_ac              : list[int64]. Number of generators for each AC grid.
        - nress_ac              : list[int64]. Number of RESs for each AC grid.
        - GG_ac, BB_ac          : list[ndarray (float64)]. Real and Imaginary parts of the AC admittance matrix (per unit).
        - GG_ft_ac, BB_ft_ac    : list[ndarray (float64)]. Branch off-diagonal entries (from-to) (per unit).
        - GG_tf_ac, BB_tf_ac    : list[ndarray (float64)]. Branch off-diagonal entries (to-from) (per unit).
        - fbus_ac, tbus_ac      : list[ndarray (int64)]. "From" and "to” bus indices per grid.

    See also: create_ac.py, makeYbus.py
    """
   
    #--------------------------------------------------------------------------
    # 1. Load AC grid data 
    #--------------------------------------------------------------------------
    network_ac = create_ac(acgrid_name)
    baseMVA_ac = np.array(network_ac["baseMVA"], dtype = np.float64)
    bus_entire_ac = np.array(network_ac["bus"], dtype = np.float64)
    branch_entire_ac = np.array(network_ac["branch"], dtype = np.float64)[np.array(network_ac["branch"])[:, 10] == 1]
    generator_entire_ac = np.array(network_ac["generator"], dtype = np.float64)
    gencost_entire_ac = np.array(network_ac["gencost"], dtype = np.float64)
    res_entire_ac = np.array(network_ac["res"], dtype = np.float64)
    ngrids = np.int64(len(np.unique(bus_entire_ac[:, 13])))
    
    #--------------------------------------------------------------------------
    # 2. Initialize arrays to store grid data
    #--------------------------------------------------------------------------
    bus_ac = [None] * ngrids
    branch_ac = [None] * ngrids
    generator_ac = [None] * ngrids
    gencost_ac = [None] * ngrids
    res_ac = [None] * ngrids
    pd_ac = [None] * ngrids
    qd_ac = [None] * ngrids
    sres_ac = [None] * ngrids
    nbuses_ac = [0] * ngrids
    nbranches_ac = [0] * ngrids
    ngens_ac = [0] * ngrids
    nress_ac = [0] * ngrids
    
    # AC network admittance components for each grid
    YY_ac = [None] * ngrids
    GG_ac = [None] * ngrids
    BB_ac = [None] * ngrids

    # Branch indices and flow parameters for each grid
    fbus_ac = [None] * ngrids
    tbus_ac = [None] * ngrids
    GG_ft_ac = [None] * ngrids
    BB_ft_ac = [None] * ngrids
    GG_tf_ac = [None] * ngrids
    BB_tf_ac = [None] * ngrids

    # AC network admittance components for each grid
    IDtoCountmap = [None] * ngrids
    refbuscount = [0] * ngrids
    recRef_ac = [None] * ngrids

    #--------------------------------------------------------------------------
    # 3. Process each AC grid separately
    #--------------------------------------------------------------------------
    for ng in range(ngrids):

        recRef_ac[ng] = []

        # Partition bus, branch, generator, and gencost data for grid #ng
        bus_ac[ng] = (bus_entire_ac[bus_entire_ac[:, 13] == ng + 1])
        branch_ac[ng] = branch_entire_ac[branch_entire_ac[:, 13] == ng + 1]
        generator_ac[ng] = generator_entire_ac[generator_entire_ac[:, 21] == ng + 1]
        gencost_ac[ng] = gencost_entire_ac[gencost_entire_ac[:, 7] == ng + 1]
        res_ac[ng] = res_entire_ac[res_entire_ac[:, 11] == ng + 1]

        # Record the number of buses and branches in grid #ng
        nbuses_ac[ng] = np.int64(bus_ac[ng].shape[0])
        nbranches_ac[ng] = np.int64(branch_ac[ng].shape[0])
        ngens_ac[ng] = np.int64(generator_ac[ng].shape[0])
        nress_ac[ng] = np.int64(res_ac[ng].shape[0])

        # Record the reference bus index in grid #ng
        IDtoCountmap[ng] = np.zeros(nbuses_ac[ng], dtype=np.int64)
        for i in range(nbuses_ac[ng]):
            bus_id = np.int64(bus_ac[ng][i, 0])
            IDtoCountmap[ng][bus_id - 1] = np.int64(i)
            if bus_ac[ng][i, 1] == 3:
                refbuscount[ng] = i+1
        recRef_ac[ng].append(refbuscount[ng])
     
        # Compute AC network admittance matrix
        YY_ac[ng] = makeYbus(baseMVA_ac, bus_ac[ng], branch_ac[ng])
        GG_ac[ng] = YY_ac[ng].real
        BB_ac[ng] = YY_ac[ng].imag

        # Extract branch "from" and "to" indices for grid #ng
        fbus_ac[ng] = branch_ac[ng][:, 0].astype(np.int64)
        tbus_ac[ng] = branch_ac[ng][:, 1].astype(np.int64)
        GG_ft_ac[ng] = GG_ac[ng][fbus_ac[ng] - 1, tbus_ac[ng] - 1]
        BB_ft_ac[ng] = BB_ac[ng][fbus_ac[ng] - 1, tbus_ac[ng] - 1]
        GG_tf_ac[ng] = GG_ac[ng][tbus_ac[ng] - 1, fbus_ac[ng] - 1]
        BB_tf_ac[ng] = BB_ac[ng][tbus_ac[ng] - 1, fbus_ac[ng] - 1]

        # Normalize load values
        pd_ac[ng] = bus_ac[ng][:, 2] / baseMVA_ac
        qd_ac[ng] = bus_ac[ng][:, 3] / baseMVA_ac

        # Normalize RES capacity
        sres_ac[ng] = res_ac[ng][:, 2] / baseMVA_ac

    return {
        "network_ac": network_ac,
        "baseMVA_ac": baseMVA_ac,
        "bus_entire_ac": bus_entire_ac,
        "branch_entire_ac": branch_entire_ac,
        "generator_entire_ac": generator_entire_ac,
        "gencost_entire_ac": gencost_entire_ac,
        "res_entire_ac": res_entire_ac,
        "ngrids": ngrids,
        "bus_ac": bus_ac,
        "branch_ac": branch_ac,
        "generator_ac": generator_ac,
        "gencost_ac": gencost_ac,
        "res_ac": res_ac,
        "recRef_ac": recRef_ac,
        "pd_ac": pd_ac,
        "qd_ac": qd_ac,
        "sres_ac": sres_ac,
        "nbuses_ac": nbuses_ac,
        "nbranches_ac": nbranches_ac,
        "ngens_ac": ngens_ac,
        "nress_ac": nress_ac,
        "GG_ac": GG_ac,
        "BB_ac": BB_ac,
        "GG_ft_ac": GG_ft_ac,
        "BB_ft_ac": BB_ft_ac,
        "GG_tf_ac": GG_tf_ac,
        "BB_tf_ac": BB_tf_ac,
        "fbus_ac": fbus_ac,
        "tbus_ac": tbus_ac
    }


if __name__ == "__main__":
    result_dc = params_dc("mtdc3slack_a")
    for key, value in result_dc.items():
        print(f"{key}:")
        print(value)
        print("=")

    result_ac = params_ac("ac14ac57")
    for key, value in result_ac.items():
        print(f"{key}:")
        print(value)
        print("=")
