import numpy as np
import networkx as nx
import matplotlib.pyplot as plt
from matplotlib import cm, colors
from matplotlib.lines import Line2D
from typing import Sequence
"""
=== viz_opf ===

This function is used to visualize AC/DC OPF results 

The following optimized varaibles are required for OPF visulization
    - bus_entire_ac         : Complete bus data from the AC network.
    - branch_entire_ac      : Complete branch data from the AC network.
    - gen_entire_ac         : Complete generator data from the AC network.
    - res_entire_ac         : Complete RES data from the DC network.
    - pgen_ac_k             : Optimized resutls of generator active power.
    - qgen_ac_k             : Optimized results of generator reactive power.
    - pij_ac_k              : Optimized results of the AC branch active power.
    - qij_ac_k              : Optimized results of the AC branch reactive power.
    - pres_ac_k             : Optimized results of the AC RES active power.
    - qres_ac_k             : Optimized results of the AC RES reactive power.
    - vn2_ac_k              : Optimized results of the squared AC voltage.
    - baseMVA_ac            : AC system base MVA value.

    - bus_dc:               : Bus data from the DC network.
    - branch_dc:            : Branch data from the DC network.
    - conv_dc:              : Converter data.
    - pij_dc_k:             : Optimized resutls of the DC branch active power.
    - ps_dc_k:              : Optimized results of the VSC PCC active power.
    - qs_dc_k:              : Optimized results of the VSC PCC reactive power.
    - vn2_dc_k:             : Optimized results of the squared DC voltage
    - pol_dc:               : Polarity of the DC network.
    - baseMW_dc:            : DC system base MW value.

"""
def viz_opf(
    bus_entire_ac:        np.ndarray,           
    branch_entire_ac:     np.ndarray,                  
    generator_entire_ac:  np.ndarray,    
    res_entire_ac:        np.ndarray,      
    pgen_ac_k:            Sequence[np.ndarray],  
    qgen_ac_k:            Sequence[np.ndarray],                        
    pij_ac_k:             Sequence[np.ndarray],  
    qij_ac_k:             Sequence[np.ndarray], 
    pres_ac_k:            Sequence[np.ndarray], 
    qres_ac_k:            Sequence[np.ndarray], 
    vn2_ac_k:             Sequence[np.ndarray],   
    baseMVA_ac:           float,  
    bus_dc:               np.ndarray, 
    branch_dc:            np.ndarray,          
    conv_dc:              np.ndarray, 
    pij_dc_k:             np.ndarray,          
    ps_dc_k:              np.ndarray,            
    qs_dc_k:              np.ndarray,           
    vn2_dc_k:             np.ndarray,                     
    pol_dc:               float,  
    baseMW_dc:            float,            
) -> None:
    
    # -------------------------------
    # Reorder AC Data
    # -------------------------------
    numBuses_ac = bus_entire_ac.shape[0]
    oldBusNums_ac = bus_entire_ac[:, 0]
    busArea_ac = bus_entire_ac[:, -1]
    
    newBusNums_ac = np.arange(1, numBuses_ac + 1)
    bus_entire_ac_new = bus_entire_ac.copy()
    bus_entire_ac_new[:, 0] = newBusNums_ac

    mappingMatrix_ac = np.column_stack((oldBusNums_ac, busArea_ac))
    branchAreas_ac = branch_entire_ac[:, -1]

    branchFrom = np.column_stack((branch_entire_ac[:, 0], branchAreas_ac))
    idxFrom = ismember_rows(branchFrom, mappingMatrix_ac)
    newFrom = newBusNums_ac.flatten()[idxFrom]

    branchTo = np.column_stack((branch_entire_ac[:, 1], branchAreas_ac))
    idxTo = ismember_rows(branchTo, mappingMatrix_ac)
    newTo = newBusNums_ac.flatten()[idxTo]

    branch_entire_ac_new = branch_entire_ac.copy()
    branch_entire_ac_new[:, 0] = newFrom
    branch_entire_ac_new[: ,1] = newTo

    # -------------------------------
    # Reorder DC Data
    # -------------------------------
    numBuses_dc = bus_dc.shape[0]
    bus_dc_new = bus_dc.copy()
    newBusNums_dc = bus_dc[:, 0] + numBuses_ac
    bus_dc_new[:, 0] = newBusNums_dc

    branch_dc_new = branch_dc.copy()
    branch_dc_new[:, 0] = branch_dc[:, 0] + numBuses_ac
    branch_dc_new[:, 1] = branch_dc[:, 1] + numBuses_ac

    # -------------------------------
    # Reorder Conv Data
    # -------------------------------
    conv_dc_new = conv_dc.copy()
    conv_dc_new[:, 0] = conv_dc[:, 0] + numBuses_ac
    mappingMatrixConv = np.column_stack((bus_entire_ac[:, 0], bus_entire_ac_new[:, 0], bus_entire_ac[:, -1]))
    idxConv = ismember_rows(conv_dc[:, 1:3], mappingMatrixConv[:, [0, 2]])
    conv_dc_new[:, 1] = mappingMatrixConv[idxConv, 1]

    # -------------------------------
    # Reorder Generator Data
    # -------------------------------
    mappingMatrixGen = np.column_stack((bus_entire_ac[:, 0], bus_entire_ac_new[:, 0], bus_entire_ac[:, -1]))
    idxGen = ismember_rows(generator_entire_ac[:, [0, -1]], mappingMatrixGen[:, [0, 2]])
    gen_entire_ac_new = generator_entire_ac.copy()
    gen_entire_ac_new[:, 0] = mappingMatrixGen[idxGen, 1]
    gen_entire_ac_new[:, 1] = np.concatenate(pgen_ac_k) * baseMVA_ac
    gen_entire_ac_new[:, 2] = np.concatenate(qgen_ac_k) * baseMVA_ac

    # -------------------------------
    # Reorder RES Data
    # -------------------------------
    mappingMatrixRES = np.column_stack((bus_entire_ac[:, 0], bus_entire_ac_new[:, 0], bus_entire_ac[:, -1]))
    idxRES = ismember_rows(res_entire_ac[:, [0, -1]], mappingMatrixRES[:, [0, 2]])
    res_entire_ac_new = res_entire_ac.copy()
    res_entire_ac_new[:, 0] = mappingMatrixGen[idxRES, 1]
    res_entire_ac_new[:, 1] = np.concatenate(pres_ac_k) * baseMVA_ac
    res_entire_ac_new[:, 2] = np.concatenate(qres_ac_k) * baseMVA_ac

    # -------------------------------
    # Get Node Number
    # -------------------------------
    nodeNums = np.concatenate((bus_entire_ac_new[:, 0], bus_dc_new[:, 0]))
    numNodes = numBuses_ac + numBuses_dc 
    acNodes = bus_entire_ac_new[:, 0]
    dcNodes = bus_dc_new[:, 0]
    genNodes = gen_entire_ac_new[:, 0]
    resNodes = res_entire_ac_new[:, 0]
    
    # -------------------------------
    # Construct Network Graph
    # -------------------------------
    # Combine branch "from" and "to" nodes for AC, DC and converter branches
    fromNode = np.concatenate((branch_entire_ac_new[:, 0],
                              branch_dc_new[:, 0],
                              conv_dc_new[:, 0]))
    
    toNode = np.concatenate((branch_entire_ac_new[:, 1],
                             branch_dc_new[:, 1],
                             conv_dc_new[:, 1]))
    
    # Get node coordinates 
    allNodes = np.unique(np.concatenate((fromNode, toNode)))
    edges = list(zip(fromNode, toNode))
    G = nx.from_edgelist(edges)

    for node in G.nodes:
        if 'Name' not in G.nodes[node]:
            G.nodes[node]['Name'] = str(node)

    sorted_nodes = sorted(G.nodes)
    mapping = {node: node for node in sorted_nodes}
    G = nx.relabel_nodes(G, mapping)
    fig, ax = plt.subplots()
    ax.axis('off')
    pos = nx.spring_layout(G, seed=1234)

    ax.set_title("AC/DC OPF Results", fontsize=12, fontweight='bold')

    # -------------------------------
    # Edito Node Size Related to Power 
    # -------------------------------
    numEdges = G.number_of_edges()
    edgeColors = np.zeros((numEdges, 3))
    numACedges = branch_entire_ac_new.shape[0]
    numDCedges = branch_dc_new.shape[0]
    numConvEdges = conv_dc_new.shape[0]

    factor = 0.8           

    for idx, coord in pos.items():

        nodeInfo = []         

        if idx in acNodes:         

            idx_ac = np.where(bus_entire_ac_new[:, 0] == idx)[0]
            loadPower = np.sqrt(bus_entire_ac_new[idx_ac, 2]**2 +
                                bus_entire_ac_new[idx_ac, 3]**2)
            loadSize = 1e-3 + loadPower * factor
            nodeInfo.append((loadSize, 'red', 'o'))

            if idx in genNodes:
                idx_gen = np.where(gen_entire_ac_new[:, 0] == idx)[0]
                genPower = np.sqrt(gen_entire_ac_new[idx_gen, 1]**2 +
                                gen_entire_ac_new[idx_gen, 2]**2)
                genSize = 1e-3 + genPower * factor
                nodeInfo.append((genSize, 'lightskyblue', 'o'))  

            if idx in resNodes:
                idx_res = np.where(res_entire_ac_new[:, 0] == idx)[0]
                resPower = np.sqrt(res_entire_ac_new[idx_res, 1]**2 +
                                res_entire_ac_new[idx_res, 2]**2)
                resSize = 1e-3 + resPower * factor
                nodeInfo.append((resSize, 'green', 'o'))       

        else:                     
            nodeInfo.append((50.0, 'blue', '^'))               

        for size, color, shape in sorted(nodeInfo, key=lambda t: t[0], reverse=True):
            nx.draw_networkx_nodes(G, pos,
                nodelist=[idx],
                node_color=color,
                node_size=size,
                node_shape=shape,
                ax=ax)
    
    # -------------------------------
    # Add Node Text Related to Voltage
    # -------------------------------
    voltMag_ac = np.sqrt(np.concatenate(vn2_ac_k).reshape(-1, 1))
    voltMag_dc = np.sqrt(vn2_dc_k)
    voltLabels = {}
    orderLabels = {}
    for idx, coord in pos.items():
        if idx in acNodes:
            row = np.where(bus_entire_ac_new[:, 0] == idx)[0]
            if row.size > 0:
                orderStr = f"#{int(bus_entire_ac[row[0], 0])}"
                voltStr = f"{voltMag_ac[row[0], 0]:.3f} p.u."
            orderLabels[idx] = orderStr
            voltLabels[idx] = voltStr

        elif idx in dcNodes:
            row = np.where(bus_dc_new[:, 0] == idx)[0]
            if row.size > 0:
                orderStr = f"#{int(bus_entire_ac[row[0], 0])}"
                voltStr = f"{voltMag_dc[row[0]]:.3f} p.u. "
            orderLabels[idx] = orderStr
            voltLabels[idx] = voltStr

    nx.draw_networkx_labels(G, pos, labels=orderLabels, font_size=10, font_color='brown', 
        horizontalalignment='center', verticalalignment='top', ax=ax)
    
    nx.draw_networkx_labels(G, pos, labels=voltLabels, font_size=10, font_color='purple', 
        horizontalalignment='left', verticalalignment='bottom', ax=ax)

    # -------------------------------
    # Edit Edge Color
    # -------------------------------
    edgePower = np.zeros(numEdges)
    edgeList = list(G.edges())
    for k, edge in enumerate(edgeList):
        fromN = float(edge[0])
        toN = float(edge[1])

        if (fromN in acNodes) and (toN in acNodes):
            Newi = fromN
            Newj = toN
            rows = np.where( ((branch_entire_ac_new[:, 0] == Newi) & (branch_entire_ac_new[:, 1] == Newj)) | 
                         ((branch_entire_ac_new[:, 0] == Newj) & (branch_entire_ac_new[:, 1] == Newi)) )[0]
            # Multiple matches found; using the first one
            row = rows[0]
            i   = int(branch_entire_ac[row, 0])
            j   = int(branch_entire_ac[row, 1])
            ng  = int(branch_entire_ac[row, -1])
            branchPowerAC = np.sqrt( pij_ac_k[ng-1][i-1, j-1]**2 + qij_ac_k[ng-1][i-1, j-1]**2 ) * baseMVA_ac
            edgePower[k] = branchPowerAC

        elif (fromN in dcNodes) and (toN in dcNodes): 
            Newi = fromN
            Newj = toN
            rows = np.where( ((branch_dc_new[:, 0] == Newi) & (branch_dc_new[:, 1] == Newj)) |
                         ((branch_dc_new[:, 0] == Newj) & (branch_dc_new[:, 1] == Newi)) )[0]
            row  = rows[0]
            i    = int(branch_dc[row, 0])
            j    = int(branch_dc[row, 1])
            branchPowerDC = abs( pij_dc_k[i-1, j-1] ) * baseMW_dc * pol_dc
            edgePower[k] = branchPowerDC

        else:
            Newi = fromN
            Newj = toN
            rows = np.where( ((conv_dc_new[:, 0] == Newi) & (conv_dc_new[:, 1] == Newj)) |
                         ((conv_dc_new[:, 0] == Newj) & (conv_dc_new[:, 1] == Newi)) )[0]
            row  = rows[0]
            branchPowerConv = np.sqrt( ps_dc_k[row]**2 + qs_dc_k[row]**2 ) * baseMVA_ac
            edgePower[k] = branchPowerConv

        norm = colors.Normalize(vmin=edgePower.min(), vmax=edgePower.max())
        cmap = cm.Oranges
        edge_colors = [cmap(norm(val)) for val in edgePower]

        nx.draw_networkx_edges(G, pos, ax=ax, width=1, edge_color=edge_colors)


    sm = cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])  
    cbar = plt.colorbar(sm, ax=ax)
    cbar.set_label("Branch Power/MVA(MW)", rotation=90, labelpad=15)

    # -------------------------------
    # Add Legend
    # -------------------------------
    acLoads = Line2D(
        [], [],  
        marker='o',            
        color='none',          
        markerfacecolor='red',
        markeredgecolor='red',
        markersize=10,
        label='AC Loads')
    
    acGens = Line2D(
        [], [],  
        marker='o',            
        color='none',          
        markerfacecolor='lightskyblue',
        markeredgecolor='lightskyblue',
        markersize=10,
        label='AC Generators')
    
    acRESs = Line2D(
        [], [],  
        marker='o',            
        color='none',          
        markerfacecolor='green',
        markeredgecolor='green',
        markersize=10,
        label='AC RESs')
    
    dcBuses = Line2D(
        [], [],
        marker='^',           
        color='none',
        markerfacecolor='blue',
        markeredgecolor='blue',
        markersize=10,
        label='VSC Converters')

    branchLines = Line2D(
        [], [],
        color='orange',
        linewidth=2,
        label='Branch Lines')
    
    legend_handles = [acLoads, acGens, acRESs, dcBuses, branchLines]

    plt.legend(handles=legend_handles,
        loc='lower right',
        fontsize='small',
        frameon=False)
    
    plt.show()

    return

def ismember_rows(A: np.ndarray, B: np.ndarray) -> np.ndarray:
    idx = []
    for a in A:
        found = False
        for i, b in enumerate(B):
            if np.array_equal(a, b):
                idx.append(i)
                found = True
                break
        if not found:
            idx.append(-1)
    return np.array(idx)

