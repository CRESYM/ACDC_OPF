using JuMP, Gurobi
using SparseArrays, LinearAlgebra
using Printf

function solve_opf(dc_name::String, ac_name::String;
    vscControl::Bool = true,    # enable vsc control constraint
    writeTxt::Bool = false,     # enable text output of ac/dc opf
    plotResult::Bool = true)    # enable plots output of ac/dc opf
    
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
        - model             : A JuMP model.
        - nbuses_dc         : Number of DC buses.
        - nconvs_dc         : Number of converters in the DC grid.
        - bus_dc            : DC bus data matrix.
        - conv_dc           : DC converter data matrix.
        - ybus_dc           : DC network admittance matrix.
        - pol_dc            : DC branch polarity.
        - baseMW_dc         : DC base power.
        - gtfc_dc           : Real part of converter admittance.
        - btfc_dc           : Imaginary part of converter admittance.
        - aloss_dc, bloss_dc, closs_dc: Converter loss parameters.
        - convState_dc      : Converter state indicator.

    Outputs (NamedTuple):
        - var_dc: Decision variable vector for the DC grid.
        - lb_dc: Lower bounds vector for var_dc.
        - ub_dc: Upper bounds vector for var_dc.
    """
    function setup_dc(model::JuMP.Model,
                    nbuses_dc::Int64,
                    nconvs_dc::Int64,
                    bus_dc::Matrix{Float64},
                    conv_dc::Matrix{Float64},
                    ybus_dc::AbstractMatrix{Float64},
                    pol_dc::Int64,
                    baseMW_dc::Int64,
                    gtfc_dc::Vector{Float64},
                    btfc_dc::Vector{Float64},
                    aloss_dc::Vector{Float64},
                    bloss_dc::Vector{Float64},
                    closs_dc::Vector{Float64},
                    convState_dc::Vector{Int64},
                    vscControl::Bool)
        
        # --- Initialization (a totoal of 19 kinds of variables) ---
        lb_dc = Vector{Vector{Float64}}(undef, 19)
        ub_dc = Vector{Vector{Float64}}(undef, 19)
        lb_default = -1e4
        ub_default = 1e4

        # --- 1 DC nodal voltage squared -vn2_dc: nbuses_dc x 1 ---
        vn2_dc = @variable(model, [1:nbuses_dc])
        lb_dc[1] = bus_dc[:, 13].^2
        ub_dc[1] = bus_dc[:, 12].^2
        @constraint(model, vn2_dc .>= lb_dc[1])
        @constraint(model, vn2_dc .<= ub_dc[1])

        # --- 2 DC nodal active power injection -pn_dc: nbuses_dc x 1 ---
        pn_dc = @variable(model, [1:nbuses_dc])
        lb_dc[2] = fill(lb_default, nbuses_dc)
        ub_dc[2] = fill(ub_default, nbuses_dc)
        @constraint(model, pn_dc .>= lb_dc[2])
        @constraint(model, pn_dc .<= ub_dc[2])

        # --- 3 VSC active power injection at node s -ps_dc: nconvs_dc x 1 ---
        ps_dc = @variable(model, [1:nconvs_dc])
        lb_dc[3] = fill(lb_default, nconvs_dc)
        ub_dc[3] = fill(ub_default, nconvs_dc)
        @constraint(model, ps_dc .>= lb_dc[3])
        @constraint(model, ps_dc .<= ub_dc[3])

        # --- 4 VSC reactive power injection at node s -qs_dc: nconvs_dc x 1 ---
        qs_dc = @variable(model, [1:nconvs_dc])
        lb_dc[4] = fill(lb_default, nconvs_dc)
        ub_dc[4] = fill(ub_default, nconvs_dc)
        @constraint(model, qs_dc .>= lb_dc[4])
        @constraint(model, qs_dc .<= ub_dc[4])

        # --- 5 VSC active power injection at node c -pc_dc: nconvs_dc x 1 ---
        pc_dc = @variable(model, [1:nconvs_dc])
        lb_dc[5] = fill(lb_default, nconvs_dc)
        ub_dc[5] = fill(ub_default, nconvs_dc)
        @constraint(model, pc_dc .>= lb_dc[5])
        @constraint(model, pc_dc .<= ub_dc[5])

        # --- 6 VSC active power injection at node c -qc_dc: nconvs_dc x 1 ---
        qc_dc = @variable(model, [1:nconvs_dc])
        lb_dc[6] = fill(lb_default, nconvs_dc)
        ub_dc[6] = fill(ub_default, nconvs_dc)
        @constraint(model, qc_dc .>= lb_dc[6])
        @constraint(model, qc_dc .<= ub_dc[6])

        # --- 7 PCC side voltage squared -v2s_dc: nconvs_dc x 1 ---
        v2s_dc = @variable(model, [1:nconvs_dc])
        lb_dc[7] = conv_dc[:, 16].^2
        ub_dc[7] = conv_dc[:, 15].^2
        @constraint(model, v2s_dc .>= lb_dc[7])
        @constraint(model, v2s_dc .<= ub_dc[7])

        # --- 8 Converter side voltage squared -v2c_dc: nconvs_dc x 1 ---
        v2c_dc = @variable(model, [1:nconvs_dc])
        lb_dc[8] = conv_dc[:, 16].^2
        ub_dc[8] = conv_dc[:, 15].^2
        @constraint(model, v2c_dc .>= lb_dc[8])
        @constraint(model, v2c_dc .<= ub_dc[8])

        # --- 9 VSC current magnitude -Ic_dc: nconvs_dc x 1 ---
        Ic_dc = @variable(model, [1:nconvs_dc])
        lb_dc[9] = zeros(nconvs_dc) 
        ub_dc[9] = conv_dc[:, 17]
        @constraint(model, Ic_dc .>= lb_dc[9])
        @constraint(model, Ic_dc .<= ub_dc[9])

        # --- 10 VSC current squared -lc_dc: nconvs_dc x 1 ---
        lc_dc = @variable(model, [1:nconvs_dc])
        lb_dc[10] = zeros(nconvs_dc)
        ub_dc[10] = conv_dc[:, 17].^2
        @constraint(model, lc_dc .>= lb_dc[10])
        @constraint(model, lc_dc .<= ub_dc[10])

        # --- 11 DC branch power flow -pij_dc: nconvs_dc x nconvs_dc ---
        @variable(model, pij_dc[1:nbuses_dc, 1:nbuses_dc])
        lb_dc[11] = fill(lb_default, nconvs_dc * nconvs_dc)
        ub_dc[11] = fill(ub_default, nconvs_dc * nconvs_dc)
        @constraint(model, pij_dc[:] .>= lb_dc[11])
        @constraint(model, pij_dc[:] .<= ub_dc[11])

        # --- 12 DC branch current squared -lij_dc: nconvs_dc x nconvs_dc ---
        @variable(model, lij_dc[1:nbuses_dc, 1:nbuses_dc])
        lb_dc[12] = fill(lb_default, nconvs_dc * nconvs_dc)
        ub_dc[12] = fill(ub_default, nconvs_dc * nconvs_dc)
        @constraint(model, lij_dc[:] .>= lb_dc[12])
        @constraint(model, lij_dc[:] .<= ub_dc[12])

        # --- 13 VSC SOC relaxed term no.1 -Ctt_dc: nconvs_dc x 1 ---
        @variable(model, Ctt_dc[1:nconvs_dc])
        lb_dc[13] = fill(lb_default, nconvs_dc)
        ub_dc[13] = fill(ub_default, nconvs_dc)
        @constraint(model, Ctt_dc .>= lb_dc[13])
        @constraint(model, Ctt_dc .<= ub_dc[13])

        # --- 14 VSC SOC relaxed term no.2 -Ccc_dc: nconvs_dc x 1 ---
        @variable(model, Ccc_dc[1:nconvs_dc])
        lb_dc[14] = fill(lb_default, nconvs_dc)
        ub_dc[14] = fill(ub_default, nconvs_dc)
        @constraint(model, Ccc_dc .>= lb_dc[14])
        @constraint(model, Ccc_dc .<= ub_dc[14])

        # --- 15 VSC SOC relaxed term no.3 -Ctc_dc: nconvs_dc x 1 ---
        @variable(model, Ctc_dc[1:nconvs_dc])
        lb_dc[15] = fill(lb_default, nconvs_dc)
        ub_dc[15] = fill(ub_default, nconvs_dc)
        @constraint(model, Ctc_dc .>= lb_dc[15])
        @constraint(model, Ctc_dc .<= ub_dc[15])

        # --- 16 VSC SOC relaxed term no.4 -Stc_dc: nconvs_dc x 1 ---
        @variable(model, Stc_dc[1:nconvs_dc])
        lb_dc[16] = fill(lb_default, nconvs_dc)
        ub_dc[16] = fill(ub_default, nconvs_dc)
        @constraint(model, Stc_dc .>= lb_dc[16])
        @constraint(model, Stc_dc .<= ub_dc[16])

        # --- 17 VSC SOC relaxed term no.5 -Cct_dc: nconvs_dc x 1 ---
        @variable(model, Cct_dc[1:nconvs_dc])
        lb_dc[17] = fill(lb_default, nconvs_dc)
        ub_dc[17] = fill(ub_default, nconvs_dc)
        @constraint(model, Cct_dc .>= lb_dc[17])
        @constraint(model, Cct_dc .<= ub_dc[17])

        # --- 18 VSC SOC relaxed term no.6 -Sct_dc: nconvs_dc x 1 ---
        @variable(model, Sct_dc[1:nconvs_dc])
        lb_dc[18] = fill(lb_default, nconvs_dc)
        ub_dc[18] = fill(ub_default, nconvs_dc)
        @constraint(model, Sct_dc .>= lb_dc[18])
        @constraint(model, Sct_dc .<= ub_dc[18])

        # --- 19 VSC power loss -convPloss_dc: nconvs_dc x 1 ---
        @variable(model, convPloss_dc[1:nconvs_dc])
        lb_dc[19] = fill(lb_default, nconvs_dc)
        ub_dc[19] = fill(ub_default, nconvs_dc)
        @constraint(model, convPloss_dc .>= lb_dc[19])
        @constraint(model, convPloss_dc .<= ub_dc[19])

        # ------------------------------
        # DC Power Flow Constraints (Second-Order Cone Relaxation)
        # ------------------------------
        # Compute effective line impedance matrix zij_dc
        zij_dc = 1.0 ./ abs.(ybus_dc)
        zij_dc = zij_dc .- Diagonal(diag(zij_dc))
        zij_dc[isinf.(zij_dc)] .= 1e4
        @constraint(model, pn_dc .== pol_dc * sum(pij_dc, dims=2))
        @constraint(model, pij_dc .+ pij_dc' .== zij_dc .* lij_dc)
        @constraint(model, vn2_dc .- vn2_dc' .== zij_dc .* (pij_dc .- pij_dc'))
        @constraint(model, pij_dc.^2 .<= lij_dc .* repeat(vn2_dc, 1, nbuses_dc))
        @constraint(model, vn2_dc .>= 0)
        @constraint(model, lij_dc .>= 0)

        # ------------------------------
        # VSC AC Side Power Flow Constraints (Second-Order Cone Relaxation)
        # ------------------------------
        @constraint(model, ps_dc .== Ctt_dc .* gtfc_dc .- Ctc_dc .* gtfc_dc .+ Stc_dc .* btfc_dc)
        @constraint(model, qs_dc .== -Ctt_dc .* btfc_dc .+ Ctc_dc .* btfc_dc .+ Stc_dc .* gtfc_dc)
        @constraint(model, pc_dc .== Ccc_dc .* gtfc_dc .- Cct_dc .* gtfc_dc .+ Sct_dc .* btfc_dc)
        @constraint(model, qc_dc .== -Ccc_dc .* btfc_dc .+ Cct_dc .* btfc_dc .+ Sct_dc .* gtfc_dc)
        @constraint(model, Ctc_dc .== Cct_dc)
        @constraint(model, Stc_dc .+ Sct_dc .== 0)
        @constraint(model, Cct_dc.^2 .+ Sct_dc.^2 .<= Ccc_dc .* Ctt_dc)
        @constraint(model, Ctc_dc.^2 .+ Stc_dc.^2 .<= Ccc_dc .* Ctt_dc)
        @constraint(model, Ccc_dc .>= 0)
        @constraint(model, Ctt_dc .>= 0)
        @constraint(model, v2s_dc .== Ctt_dc)
        @constraint(model, v2c_dc .== Ccc_dc)

        # ------------------------------
        # Converter Loss Constraints (Second-Order Cone Relaxation)
        # ------------------------------
        @constraint(model, pc_dc .+ pn_dc .+ convPloss_dc .== 0)
        @constraint(model, 0 .<= convPloss_dc)
        @constraint(model, convPloss_dc .<= 1)
        @constraint(model, convPloss_dc .== aloss_dc .+ bloss_dc .* Ic_dc .+ closs_dc .* lc_dc)  
        @constraint(model, pc_dc.^2 .+ qc_dc.^2 .<= lc_dc .* v2c_dc)  
        @constraint(model, lc_dc .>= 0)
        @constraint(model, v2c_dc .>= 0)
        @constraint(model, Ic_dc.^2 .<= lc_dc)
        @constraint(model, Ic_dc .>= 0)

        # ------------------------------
        # VSC Converter Control Constraints
        # ------------------------------
        # If we hope control setpoints of VSC converter be optimized, 
        # the below constraints need to be removed
        if vscControl
            for i in 1:nconvs_dc
                # dc side control
                if conv_dc[i, 4] == 1 # dc p control
                    @constraint(model, pn_dc[i] == -conv_dc[i, 6] / baseMW_dc)
                elseif conv_dc[i, 4] == 2 # dc voltage control
                    @constraint(model, vn2_dc[i] == conv_dc[i, 8]^2)
                else # droop control
                    @constraint(model, pn_dc[i] == (conv_dc[i, 24] - 1 / conv_dc[i, 23] * (.5 + .5*vn2_dc[i] - conv_dc[i, 25])) / baseMW_dc * (-1))
                end
                # ac side control
                if conv_dc[i, 5] == 1 # ac q control
                    @constraint(model, qs_dc[i] == -conv_dc[i, 7] / baseMW_dc)
                else # ac voltage control
                    @constraint(model, v2s_dc[i] == conv_dc[i, 8] ^2)
                end
                # converter mode
                if convState_dc[i] == 0 # rectifier mode
                    @constraint(model, ps_dc[i] >=0)
                    @constraint(model, pn_dc[i] >=0)
                    @constraint(model, pc_dc[i] <=0)
                else # inverter mode
                    @constraint(model, ps_dc[i] <=0)
                    @constraint(model, pn_dc[i] <=0)
                    @constraint(model, pc_dc[i] >=0)
                end
            end
        end

        # Bundle DC variables into a NamedTuple for convenience
        var_dc = (
            vn2_dc = vn2_dc,
            pn_dc = pn_dc,
            ps_dc = ps_dc,
            qs_dc = qs_dc,
            pc_dc = pc_dc,
            qc_dc = qc_dc,
            v2s_dc = v2s_dc,
            v2c_dc = v2c_dc,
            Ic_dc = Ic_dc,
            lc_dc = lc_dc,
            pij_dc = pij_dc,
            lij_dc = lij_dc,
            Ctt_dc = Ctt_dc,
            Ccc_dc = Ccc_dc,
            Ctc_dc = Ctc_dc,
            Stc_dc = Stc_dc,
            Cct_dc = Cct_dc,
            Sct_dc = Sct_dc,
            convPloss_dc = convPloss_dc
            )
        
        return (var_dc = var_dc, lb_dc = lb_dc, ub_dc = ub_dc)
    end
        

    """
    === setup_ac ===

    This function defines the AC grid optimization variables, their bounds,
    and operational constraints.

    The decision variable vector is partitioned into blocks as follows:
        1. vn2_ac   - AC nodal voltage squared
        2. pn_ac    - AC active power injection
        3. qn_ac    - AC reactive power injection
        4. pgen_ac  - Generator active power output
        5. qgen_ac  - Generator reactive power output
        6. pij_ac   - AC branch active power flow
        7. qij_ac   - AC branch reactive power flow
        8. ss_ac    - AC SOC relaxed term no.1
        9. cc_ac    - AC SOC relaxed term no.2
        10.pres_ac  - AC RES active power 
        11.qres_ac  - AC RES reactive power 

    INPUTS:
        - model: JuMP model.
        - ngrids: Number of AC grids.
        - nbuses_ac: Vectors containing the number of buses for each grid.
        - ngens_ac: Vectors containing the number of generators for each grid.
        - nress_ac: Vectors containing the number of RESs for each grid.
        - bus_ac: Vectors of bus data matrices for each grid.
        - generator_ac: Vectors of generator data for each grid.
        - res_ac: Vectors of RES data for each grid.
        - BB_ac: Vectors of Imaginary part of the AC admittance matrix.
        - GG_ac: Vectors of Real part of the AC admittance matrix.
        - sres_ac: Vectors of the rated capacity of RESs. 
        - baseMVA_ac: AC base MVA

    Outputs (NamedTuple):
        - var_ac: Decision variable vector for the AC grid.
        - lb_ac: Lower bounds vector for var_ac.
        - ub_ac: Upper bounds vector for var_ac.

    """
    function setup_ac(model::JuMP.Model,
                    ngrids::Int64,
                    nbuses_ac::Vector{Int64},
                    ngens_ac::Vector{Int64},
                    nress_ac::Vector{Int64},
                    bus_ac::Vector{Matrix{Float64}},
                    generator_ac::Vector{Matrix{Float64}},
                    res_ac::Vector{Matrix{Float64}},
                    BB_ac::Vector{Matrix{Float64}},
                    GG_ac::Vector{Matrix{Float64}},
                    sres_ac::Vector{Vector{Float64}},
                    baseMVA_ac::Number)

        # Pre-allocate 
        lb_ac        = Vector{Any}(undef, ngrids)
        ub_ac        = Vector{Any}(undef, ngrids)
        var_ac       = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        vn2_ac       = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        pn_ac        = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        qn_ac        = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        pgen_ac      = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        qgen_ac      = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        pij_ac       = Vector{Matrix{JuMP.VariableRef}}(undef, ngrids)
        qij_ac       = Vector{Matrix{JuMP.VariableRef}}(undef, ngrids)
        ss_ac        = Vector{Matrix{JuMP.VariableRef}}(undef, ngrids)
        cc_ac        = Vector{Matrix{JuMP.VariableRef}}(undef, ngrids)
        pres_ac      = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)
        qres_ac      = Vector{Vector{JuMP.VariableRef}}(undef, ngrids)

        # Loop over each AC grid to define variables and constraints
        for ng in 1:ngrids
            
            # --- Initialization (a totoal of 9 kinds of variables) ---
            lb_ac[ng] = Vector{Vector{Float64}}(undef, 11)
            ub_ac[ng] = Vector{Vector{Float64}}(undef, 11)
            lb_default = -1e4
            ub_default = 1e4
            nbuses = nbuses_ac[ng]
            ngens = ngens_ac[ng]
            nress = nress_ac[ng]

            # --- 1 AC nodal voltage squared -vn2_ac: nbuses x 1 ---
            vn2_ac[ng] = @variable(model, [1:nbuses])
            lb_ac[ng][1] = bus_ac[ng][:, 13].^2
            ub_ac[ng][1] = bus_ac[ng][:, 12].^2
            @constraint(model, vn2_ac[ng] .>= lb_ac[ng][1])
            @constraint(model, vn2_ac[ng] .<= ub_ac[ng][1])

            # --- 2 AC active power injection -pn_ac: nbuses x 1 ---
            pn_ac[ng] = @variable(model, [1:nbuses])
            lb_ac[ng][2] = fill(lb_default, nbuses)
            ub_ac[ng][2] = fill(ub_default, nbuses)
            @constraint(model, pn_ac[ng] .>= lb_ac[ng][2])
            @constraint(model, pn_ac[ng] .<= ub_ac[ng][2])

            # --- 3 AC reactive power injection -qn_ac: nbuses x 1 ---
            qn_ac[ng] = @variable(model, [1:nbuses])
            lb_ac[ng][3] = fill(lb_default, nbuses)
            ub_ac[ng][3] = fill(ub_default, nbuses)
            @constraint(model, qn_ac[ng] .>= lb_ac[ng][3])
            @constraint(model, qn_ac[ng] .<= ub_ac[ng][3])

            # --- 4 AC generator active power output -pgen_ac: ngens x 1 ---
            pgen_ac[ng] = @variable(model, [1:ngens])
            lb_ac[ng][4] = generator_ac[ng][:, 10] .* generator_ac[ng][:, 8] ./ baseMVA_ac
            ub_ac[ng][4] = generator_ac[ng][:, 9] .* generator_ac[ng][:, 8] ./ baseMVA_ac
            @constraint(model, pgen_ac[ng] .>= lb_ac[ng][4])
            @constraint(model, pgen_ac[ng] .<= ub_ac[ng][4])

            # --- 5 AC generator reactive power output -qgen_ac: ngens x 1 ---
            qgen_ac[ng] = @variable(model, [1:ngens])
            lb_ac[ng][5] = generator_ac[ng][:, 5] .* generator_ac[ng][:, 8] ./ baseMVA_ac
            ub_ac[ng][5] = generator_ac[ng][:, 4] .* generator_ac[ng][:, 8] ./ baseMVA_ac
            @constraint(model, qgen_ac[ng] .>= lb_ac[ng][5])
            @constraint(model, qgen_ac[ng] .<= ub_ac[ng][5])
    
            # --- 6 AC branch active power flow  -pij_ac: nbuses x nbuses ---
            pij_ac[ng] = @variable(model, [1:nbuses, 1:nbuses])
            lb_ac[ng][6] = fill(lb_default, nbuses * nbuses)
            ub_ac[ng][6] = fill(ub_default, nbuses * nbuses)
            @constraint(model, pij_ac[ng][:] .>= lb_ac[ng][6])
            @constraint(model, pij_ac[ng][:] .<= ub_ac[ng][6])

            # --- 7 AC branch reactive power flow -qij_ac: nbuses x nbuses ---
            qij_ac[ng] = @variable(model, [1:nbuses, 1:nbuses])
            lb_ac[ng][7] = fill(lb_default, nbuses * nbuses)
            ub_ac[ng][7] = fill(ub_default, nbuses * nbuses)
            @constraint(model, qij_ac[ng][:] .>= lb_ac[ng][7])
            @constraint(model, qij_ac[ng][:] .<= ub_ac[ng][7])

            # --- 8 AC SOC relaxed term no.1 -ss_ac: nbuses x nbuses ---
            ss_ac[ng] = @variable(model, [1:nbuses, 1:nbuses])
            lb_ac[ng][8] = fill(lb_default, nbuses * nbuses)
            ub_ac[ng][8] = fill(ub_default, nbuses * nbuses)
            @constraint(model, ss_ac[ng][:] .>= lb_ac[ng][8])
            @constraint(model, ss_ac[ng][:] .<= ub_ac[ng][8])
    
            # --- 9 AC SOC relaxed term no.2 -cc_ac: nbuses x nbuses ---
            cc_ac[ng] = @variable(model, [1:nbuses, 1:nbuses])
            lb_ac[ng][9] = fill(lb_default, nbuses * nbuses)
            ub_ac[ng][9] = fill(ub_default, nbuses * nbuses)
            @constraint(model, cc_ac[ng][:] .>= lb_ac[ng][9])
            @constraint(model, cc_ac[ng][:] .<= ub_ac[ng][9])

            # --- 10 AC RES active power output -pres_ac: nress x 1 ---
            pres_ac[ng] = @variable(model, [1:nress])
            lb_ac[ng][10] = fill(0, nress)
            ub_ac[ng][10] = res_ac[ng][:, 2] ./ baseMVA_ac
            @constraint(model, pres_ac[ng] .>= lb_ac[ng][10])
            @constraint(model, pres_ac[ng] .<= ub_ac[ng][10])

            # --- 11 AC RES reactive power output -qres_ac: nress x 1 ---
            qres_ac[ng] = @variable(model, [1:nress])
            lb_ac[ng][11] = fill(lb_default, nress)
            ub_ac[ng][11] = fill(ub_default, nress)
            @constraint(model, qres_ac[ng] .>= lb_ac[ng][11])
            @constraint(model, qres_ac[ng] .<= ub_ac[ng][11])

            # ------------------------------
            # AC Nodal Power Balance Constraints 
            # ------------------------------
            diag_ss_ac = [ss_ac[ng][i, i] for i in 1:nbuses]
            diag_cc_ac = [cc_ac[ng][i, i] for i in 1:nbuses]
            diag_BB_ac = [BB_ac[ng][i, i] for i in 1:nbuses]
            diag_GG_ac = [GG_ac[ng][i, i] for i in 1:nbuses]
            pn_matrix_ac = diag_ss_ac .* diag_BB_ac .+ sum(cc_ac[ng] .* GG_ac[ng] .- ss_ac[ng] .* BB_ac[ng], dims=2)
            @constraint(model, pn_ac[ng] .== pn_matrix_ac)
            qn_matrix_ac = diag_ss_ac .* diag_GG_ac .- sum(cc_ac[ng] .* BB_ac[ng] .+ ss_ac[ng] .* GG_ac[ng], dims=2)
            @constraint(model, qn_ac[ng] .== qn_matrix_ac)

            # ------------------------------
            # Branch Flow Calculation Constraints
            # ------------------------------
            diagC_ac = repeat(reshape(diag_cc_ac, nbuses, 1), 1, nbuses)
            @constraint(model,
                vec(pij_ac[ng]) .== -vec(GG_ac[ng]) .* (vec(diagC_ac) - vec(cc_ac[ng])) - vec(BB_ac[ng]) .* vec(ss_ac[ng]))
            @constraint(model,
                vec(qij_ac[ng]) .==  vec(BB_ac[ng]) .* (vec(diagC_ac) - vec(cc_ac[ng])) - vec(GG_ac[ng]) .* vec(ss_ac[ng]))

            # ------------------------------
            # Symmetry and Relaxation
            # ------------------------------
            @constraint(model, cc_ac[ng] .== transpose(cc_ac[ng]))
            @constraint(model, ss_ac[ng] .+ transpose(ss_ac[ng]) .== 0)
            upper_mask = triu(ones(Bool, nbuses, nbuses))
            cc_upper = cc_ac[ng] .* upper_mask
            ss_upper = ss_ac[ng] .* upper_mask
            @constraint(model, cc_upper.^2 .+ ss_upper.^2 .<= diag_cc_ac * transpose(diag_cc_ac))
            @constraint(model, diag_cc_ac .>= 0)
            @constraint(model, diag_cc_ac .== vn2_ac[ng])

            # ------------------------------
            # AC RES Capacity Constraints (Polygon approximation)
            # ------------------------------
            theta = collect(1:8) .* (π/8)         
            C = cos.(theta)                     
            S = sin.(theta)              

            Pres = pres_ac[ng]          
            Qres = qres_ac[ng]
            Sres = sres_ac[ng]         

            nress = length(Pres)

            Cmat = C .* ones(1, nress)          
            Smat = S .* ones(1, nress)         

            L = Cmat .* Pres' .+ Smat .* Qres'   
            R = repeat(Sres', 8, 1)

            @constraint(model, vec(L) .<= vec(R))     
            @constraint(model, vec(-L) .<= vec(R))   

        end

        # Bundle AC variables into a NamedTuple for convenience
        var_ac = (
            vn2_ac = vn2_ac,
            pn_ac = pn_ac,
            qn_ac = qn_ac,
            pgen_ac = pgen_ac,
            qgen_ac = qgen_ac,
            pij_ac = pij_ac,
            qij_ac = qij_ac,
            ss_ac = ss_ac,
            cc_ac = cc_ac,
            pres_ac = pres_ac,
            qres_ac = qres_ac
        )
        return (var_ac = var_ac, lb_ac = lb_ac, ub_ac = ub_ac)
    end


    """
    === setup_cp ===

    This function creates two groups of constraints:
        1. Power Coupling Constraints
        2. Voltage Coupling Constraints

    INPUTS:
        - ngrids: Number of AC grids
        - pn_ac: Active power injection of AC grids.
        - qn_ac: Reactive power injection of AC grids.
        - pgen_ac: Active generator power output of AC grids.
        - qgen_ac: Reactive generator power output of AC grids.
        - pd_ac: Active power load of AC grids.
        - qd_ac: Reactive power load of AC grids.
        - vn2_ac: Squared node voltage of AC grids.
        - generator_ac: Generator data matrices for AC grids.
        - ps_dc: Active power injections (PCC) from converters.
        - qs_dc: Reactor power injections (PCC) from converters.
        - v2s_dc: Squared voltage (PCC) from converters.
        - conv_dc: Converter data matrices for converters.

    OUTPUTS:
        Nothing.

    """
    function setup_cp(model::JuMP.Model,
        ngrids::Int,
        nbuses_ac::Vector{Int},
        ngens_ac::Vector{Int},
        nress_ac::Vector{Int},
        pn_ac::Vector{Vector{JuMP.VariableRef}},
        qn_ac::Vector{Vector{JuMP.VariableRef}},
        pgen_ac::Vector{Vector{JuMP.VariableRef}},
        qgen_ac::Vector{Vector{JuMP.VariableRef}},
        pd_ac::Vector{Vector{Float64}},
        qd_ac::Vector{Vector{Float64}},
        pres_ac::Vector{Vector{JuMP.VariableRef}},
        qres_ac::Vector{Vector{JuMP.VariableRef}},
        vn2_ac::Vector{Vector{JuMP.VariableRef}},
        generator_ac::Vector{Matrix{Float64}},
        res_ac::Vector{Matrix{Float64}},
        nconvs_dc::Int,
        ps_dc::Vector{JuMP.VariableRef},
        qs_dc::Vector{JuMP.VariableRef},
        v2s_dc::Vector{JuMP.VariableRef},
        conv_dc::Matrix{Float64})

        # Loop over each AC grid to set up nodal power balance constraints
        for ng in 1:ngrids
            pm_ac = [AffExpr(0.0) for _ in 1:nbuses_ac[ng]]
            qm_ac = [AffExpr(0.0) for _ in 1:nbuses_ac[ng]]
            #  Every AC node have load 
            pm_ac .-= pd_ac[ng]
            qm_ac .-= qd_ac[ng]
            #  If the AC node connected with generator
            for i in 1:ngens_ac[ng]
                bus_index = Int(generator_ac[ng][i, 1])
                pm_ac[bus_index] += pgen_ac[ng][i]
                qm_ac[bus_index] += qgen_ac[ng][i]
            end
            #  If the AC node connected with RES
            for i in 1:nress_ac[ng]
                bus_index = Int(res_ac[ng][i, 1])
                pm_ac[bus_index] += pres_ac[ng][i]
                qm_ac[bus_index] += qres_ac[ng][i]
            end
            # If the AC node connected with VSC
            for i in 1:nconvs_dc
                if Int(conv_dc[i, 3]) == ng
                    bus_index = Int(conv_dc[i, 2])
                    pm_ac[bus_index] -= ps_dc[i]
                    qm_ac[bus_index] -= qs_dc[i]
                end
            end
            
            @constraint(model, pn_ac[ng] .== pm_ac)
            @constraint(model, qn_ac[ng] .== qm_ac)
        end
        
        # Voltage coupling constraints:
        for i in 1:nconvs_dc
            ng = Int(conv_dc[i, 3])      
            bus_index = Int(conv_dc[i, 2])  
            @constraint(model, vn2_ac[ng][bus_index] == v2s_dc[i])
        end
        
        return nothing
    end


    """
    === setup_obj ===

    This function defines the objective of AC/DC OPF.

    INPUTS:
        - ngrids: Number of AC grids
        - generator_ac: Generator data matrices for AC grids.
        - gencost_ac: Generator cost data matrices for AC grids.
        - pgen_ac: Generator active power outputs for AC grids.
        - baseMVA_ac:  AC base MVA.

    OUTPUTS:
        - Obj: Optimization objective, the total generation cost across all AC grids.

    """
    function setup_obj(model::JuMP.Model,
        ngrids::Int,
        generator_ac::Vector{Matrix{Float64}},
        gencost_ac::Vector{Matrix{Float64}},
        pgen_ac::Vector{Vector{JuMP.VariableRef}},
        res_ac::Vector{Matrix{Float64}},
        pres_ac::Vector{Vector{JuMP.VariableRef}},
        baseMVA_ac::Number)

        # Pre-allocate 
        actgen_ac = Vector{Vector{Float64}}(undef, ngrids)
        actres_ac = Vector{Vector{Float64}}(undef, ngrids)
        obj       = Vector{Any}(undef, ngrids)

        # Define generation and RES costs
        for ng in 1:ngrids
            obj[ng] = 0.0

            # Gen cost
            if size(generator_ac[ng], 1) > 0 && size(gencost_ac[ng], 1) > 0
                actgen_ac[ng] = generator_ac[ng][:, 8]

                if gencost_ac[ng][1, 4] == 3  # Quadratic cost type
                    obj[ng] = sum( actgen_ac[ng] .* (baseMVA_ac^2 .* gencost_ac[ng][:, 5] .* pgen_ac[ng].^2 + 
                                baseMVA_ac .* gencost_ac[ng][:, 6] .* pgen_ac[ng] + 
                                gencost_ac[ng][:, 7]) )
                end

                if gencost_ac[ng][1, 4] == 2  # Linear cost type
                    obj[ng] = sum( actgen_ac[ng] .* (baseMVA_ac .* gencost_ac[ng][:, 6] .* pgen_ac[ng] + 
                                gencost_ac[ng][:, 7]) )
                end
                
            end
            
            # RES cost 
            if size(res_ac[ng], 1) > 0
                actres_ac[ng] = res_ac[ng][:, 11] # Quadratic cost 
                if res_ac[ng][1, 7] == 3 
                    obj[ng] += sum( actres_ac[ng] .* (baseMVA_ac^2 .* res_ac[ng][:, 8] .* pres_ac[ng].^2 + 
                                baseMVA_ac .* res_ac[ng][:, 9] .* pres_ac[ng] + 
                                res_ac[ng][:, 10]) )
                end

                if res_ac[ng][1, 7] == 2 # Linear cost type
                    obj[ng] += sum( actres_ac[ng] .* (baseMVA_ac .* res_ac[ng][:, 9] .* pres_ac[ng] + 
                                res_ac[ng][:, 10]) )
                end
            end
        end
            
        Obj = sum(obj) 

        return Obj

    end

    """
    === reconver_angle ===

    This function reconstructs the voltage phase angles
    from the second-order cone (SOC) relaxation variables of the AC grid.
    
    Inputs:
        - cc : Matrix{Float64}
            SOC variable |Vi||Vj|cos(θi - θj)
        - ss : Matrix{Float64}
            SOC variable |Vi||Vj|sin(θi - θj)
        - ref_bus : Int

    Output:
        - theta : np.ndarray (nb,)
        - Reconstructed nodal voltage phase angles

    """
    function recover_angle(cc::Matrix{Float64}, ss::Matrix{Float64}, ref::Int)
        nb = size(cc, 1)
        theta = fill(NaN, nb)
        theta[ref] = 0.0

        visited = falses(nb)
        visited[ref] = true

        G = abs.(cc) .> 1e-6
        for i in 1:nb
            G[i, i] = false
        end

        stack = [ref]
        while !isempty(stack)
            i = pop!(stack)
            for j in findall(G[i, :])
                if !visited[j]
                    dtheta = atan(ss[i, j], cc[i, j])
                    theta[j] = theta[i] - dtheta
                    visited[j] = true
                    push!(stack, j)
                end
            end
        end
        return theta
    end

    # ============================ Main Program =============================
    elapsed_time = @elapsed begin

        # -------------------------------
        # 1: Load DC and AC Parameters
        # -------------------------------

        # Load DC parameters 
        res_params_dc = params_dc(dc_name)
        # Unpack DC parameters into meaningful variable names
        network_dc   = res_params_dc.network_dc
        baseMW_dc    = res_params_dc.baseMW_dc
        bus_dc       = res_params_dc.bus_dc
        branch_dc    = res_params_dc.branch_dc
        conv_dc      = res_params_dc.conv_dc
        pol_dc       = res_params_dc.pol_dc
        nbuses_dc    = res_params_dc.nbuses_dc
        nbranches_dc = res_params_dc.nbranches_dc
        nconvs_dc    = res_params_dc.nconvs_dc
        fbus_dc      = res_params_dc.fbus_dc
        tbus_dc      = res_params_dc.tbus_dc
        ybus_dc      = res_params_dc.ybus_dc
        rtf_dc       = res_params_dc.rtf_dc
        xtf_dc       = res_params_dc.xtf_dc
        bf_dc        = res_params_dc.bf_dc
        rc_dc        = res_params_dc.rc_dc
        xc_dc        = res_params_dc.xc_dc
        ztfc_dc      = res_params_dc.ztfc_dc
        gtfc_dc      = res_params_dc.gtfc_dc
        btfc_dc      = res_params_dc.btfc_dc
        aloss_dc     = res_params_dc.aloss_dc
        bloss_dc     = res_params_dc.bloss_dc
        closs_dc     = res_params_dc.closs_dc
        convState_dc = res_params_dc.convState_dc
        basekV_dc    = res_params_dc.basekV_dc

        # Load AC parameters
        res_params_ac = params_ac(ac_name)
        # Unpack AC parameters into meaningful variable names
        network_ac        = res_params_ac.network_ac
        baseMVA_ac        = res_params_ac.baseMVA_ac
        bus_entire_ac     = res_params_ac.bus_entire_ac
        branch_entire_ac  = res_params_ac.branch_entire_ac
        gen_entire_ac     = res_params_ac.gen_entire_ac
        gencost_entire_ac = res_params_ac.gencost_entire_ac
        res_entire_ac     = res_params_ac.res_entire_ac
        ngrids            = res_params_ac.ngrids
        bus_ac            = res_params_ac.bus_ac
        branch_ac         = res_params_ac.branch_ac
        generator_ac      = res_params_ac.generator_ac
        gencost_ac        = res_params_ac.gencost_ac
        res_ac            = res_params_ac.res_ac
        recRef_ac         = res_params_ac.recRef_ac
        pd_ac             = res_params_ac.pd_ac
        qd_ac             = res_params_ac.qd_ac
        sres_ac           = res_params_ac.sres_ac
        nbuses_ac         = res_params_ac.nbuses_ac
        nbranches_ac      = res_params_ac.nbranches_ac
        ngens_ac          = res_params_ac.ngens_ac
        nress_ac          = res_params_ac.nress_ac
        GG_ac             = res_params_ac.GG_ac
        BB_ac             = res_params_ac.BB_ac
        GG_ft_ac          = res_params_ac.GG_ft_ac
        BB_ft_ac          = res_params_ac.BB_ft_ac
        GG_tf_ac          = res_params_ac.GG_tf_ac
        BB_tf_ac          = res_params_ac.BB_tf_ac
        fbus_ac           = res_params_ac.fbus_ac
        tbus_ac           = res_params_ac.tbus_ac

        # -------------------------------
        # 2: Build the Optimization Model and Set Up Constraints
        # -------------------------------
        # Setup model
        model = direct_model(Gurobi.Optimizer())

        # Set up DC variables and constraints
        res_setup_dc = setup_dc(model, nbuses_dc, nconvs_dc, bus_dc, conv_dc, ybus_dc, pol_dc, baseMW_dc, 
                            gtfc_dc, btfc_dc, aloss_dc, bloss_dc, closs_dc, convState_dc, vscControl)
        # Unpack DC variables for further use
        vn2_dc       = res_setup_dc.var_dc.vn2_dc
        pn_dc        = res_setup_dc.var_dc.pn_dc
        ps_dc        = res_setup_dc.var_dc.ps_dc
        qs_dc        = res_setup_dc.var_dc.qs_dc
        pc_dc        = res_setup_dc.var_dc.pc_dc
        qc_dc        = res_setup_dc.var_dc.qc_dc
        v2s_dc       = res_setup_dc.var_dc.v2s_dc
        v2c_dc       = res_setup_dc.var_dc.v2c_dc
        Ic_dc        = res_setup_dc.var_dc.Ic_dc
        lc_dc        = res_setup_dc.var_dc.lc_dc
        pij_dc       = res_setup_dc.var_dc.pij_dc
        lij_dc       = res_setup_dc.var_dc.lij_dc
        Ctt_dc       = res_setup_dc.var_dc.Ctt_dc
        Ccc_dc       = res_setup_dc.var_dc.Ccc_dc
        Ctc_dc       = res_setup_dc.var_dc.Ctc_dc
        Stc_dc       = res_setup_dc.var_dc.Stc_dc
        Cct_dc       = res_setup_dc.var_dc.Cct_dc
        Sct_dc       = res_setup_dc.var_dc.Sct_dc
        convPloss_dc = res_setup_dc.var_dc.convPloss_dc

        #  Set up AC variables and constraints
        res_setup_ac = setup_ac(model, ngrids, nbuses_ac, ngens_ac, nress_ac, bus_ac, generator_ac, res_ac, BB_ac, GG_ac, sres_ac, baseMVA_ac)
        # Unpack AC variables for further use
        vn2_ac   = res_setup_ac.var_ac.vn2_ac
        pn_ac    = res_setup_ac.var_ac.pn_ac
        qn_ac    = res_setup_ac.var_ac.qn_ac
        pgen_ac  = res_setup_ac.var_ac.pgen_ac
        qgen_ac  = res_setup_ac.var_ac.qgen_ac
        pij_ac   = res_setup_ac.var_ac.pij_ac
        qij_ac   = res_setup_ac.var_ac.qij_ac
        ss_ac    = res_setup_ac.var_ac.ss_ac
        cc_ac    = res_setup_ac.var_ac.cc_ac
        pres_ac  = res_setup_ac.var_ac.pres_ac
        qres_ac  = res_setup_ac.var_ac.qres_ac

        # Set up AC/DC coupling constraints
        # setup_cp(model, ngrids, nbuses_ac, ngens_ac, pn_ac, qn_ac, pgen_ac, qgen_ac, 
        #         pd_ac, qd_ac, vn2_ac, generator_ac, nconvs_dc, ps_dc, qs_dc, v2s_dc, conv_dc)

        setup_cp(model, ngrids, nbuses_ac, ngens_ac, nress_ac, pn_ac, qn_ac, pgen_ac, qgen_ac, 
                pd_ac, qd_ac, pres_ac, qres_ac, vn2_ac, generator_ac, res_ac, nconvs_dc, ps_dc, qs_dc, v2s_dc, conv_dc)

    
        # Set up Objectives
        Obj = setup_obj(model, ngrids, generator_ac, gencost_ac, pgen_ac, res_ac, pres_ac, baseMVA_ac)

        # Define overall objective as the sum of grid costs.
        @objective(model, Min, Obj)
        
        # -------------------------------
        # 3: Solve AC/DC OPF
        # -------------------------------
        set_optimizer_attribute(model, "TimeLimit", 600)    
        set_optimizer_attribute(model, "Threads", 8)       
        set_optimizer_attribute(model, "Presolve", 2)       
        set_optimizer_attribute(model, "OutputFlag", 1)  
        set_optimizer_attribute(model, "NumericFocus", 3)
    
        optimize!(model)

    end  # end @elapsed block


    (vn2_dc_k, pn_dc_k, ps_dc_k, qs_dc_k, pc_dc_k, qc_dc_k, v2s_dc_k, v2c_dc_k, 
    Ic_dc_k, lc_dc_k, pij_dc_k, lij_dc_k, Ctt_dc_k, Ccc_dc_k, Ctc_dc_k, 
    Stc_dc_k, Cct_dc_k, Sct_dc_k, convPloss_dc_k) =
    (JuMP.value.(x) for x in (vn2_dc, pn_dc, ps_dc, qs_dc, pc_dc, qc_dc, v2s_dc, v2c_dc, 
                        Ic_dc, lc_dc, pij_dc, lij_dc, Ctt_dc, Ccc_dc, Ctc_dc, 
                        Stc_dc, Cct_dc, Sct_dc, convPloss_dc))

    vn2_ac_k   = Vector{Any}(undef, ngrids)
    pn_ac_k    = Vector{Any}(undef, ngrids)
    qn_ac_k    = Vector{Any}(undef, ngrids)
    pgen_ac_k  = Vector{Any}(undef, ngrids)
    qgen_ac_k  = Vector{Any}(undef, ngrids)
    pij_ac_k   = Vector{Any}(undef, ngrids)
    qij_ac_k   = Vector{Any}(undef, ngrids)
    ss_ac_k    = Vector{Any}(undef, ngrids)
    cc_ac_k    = Vector{Any}(undef, ngrids)
    pres_ac_k  = Vector{Any}(undef, ngrids)
    qres_ac_k  = Vector{Any}(undef, ngrids)

    for ng in 1:ngrids
        (vn2_ac_k[ng], pn_ac_k[ng], qn_ac_k[ng], pgen_ac_k[ng], qgen_ac_k[ng], 
        pij_ac_k[ng], qij_ac_k[ng], ss_ac_k[ng], cc_ac_k[ng], pres_ac_k[ng], qres_ac_k[ng] ) =
        (JuMP.value.(x) for x in (vn2_ac[ng], pn_ac[ng], qn_ac[ng], pgen_ac[ng], qgen_ac[ng], 
        pij_ac[ng], qij_ac[ng], ss_ac[ng], cc_ac[ng], pres_ac[ng], qres_ac[ng] ))
    end


    # =============================================================
    # 4: Voltage Angle Reconstruction
    # =============================================================

    theta_ac_k = Vector{Vector{Float64}}(undef, ngrids)
    theta_s_k  = zeros(nconvs_dc)
    theta_c_k  = zeros(nconvs_dc)

    # ---- AC bus angles reconstruction ----
    for ng in 1:ngrids
        # ---- Find reference bus ----
        ref_bus = !isempty(recRef_ac[ng]) ? recRef_ac[ng][] : begin
            # If not specified, use PCC bus of first converter connected to this grid
            vsc_idx = findfirst(x -> x == ng, conv_dc[:, 3])
            isnothing(vsc_idx) && error("No converter found for grid $ng to set as reference bus.")
            Int(conv_dc[vsc_idx, 2])
        end

        theta_ac_k[ng] = recover_angle(cc_ac_k[ng], ss_ac_k[ng], ref_bus)
    end

    # ---- θ_s (VSC PCC-side angle) ----
    for i in 1:nconvs_dc
        k = Int(conv_dc[i, 3])   # AC grid index
        j = Int(conv_dc[i, 2])   # PCC bus number
        theta_s_k[i] = theta_ac_k[k][j]
    end

    # ---- θ_c (VSC AC-side angle) ----
    for i in 1:nconvs_dc
        dtheta_sc = atan(Stc_dc_k[i], Ctc_dc_k[i])
        theta_c_k[i] = theta_s_k[i] - dtheta_sc
    end


    # ============================ Print Results =============================
    outfile = joinpath(pwd(), "opf_results.txt")
    io = writeTxt ? open(outfile, "w") : stdout

    # ----------------------------
    # Print AC Grid Bus Data
    # ---------------------------- 
    println(io, "======================================================================================================")
    println(io, "|      AC Grid Bus Data                                                                              |")
    println(io, "======================================================================================================")
    println(io, " Area   Bus        Voltage             Generation               Load                    RES")
    println(io, " #      #      Mag [pu]/Ang [deg]   Pg [MW]   Qg [MVAr]   Pd [MW]   Qd [MVAr]   Pres [MW]  Qres [MVAr]")
    println(io, "-----   -----   ------------------  --------   ---------   -------   ---------   ---------  ----------")

    for ng in 1:ngrids
        genidx = generator_ac[ng][:, 1]
        residx = res_ac[ng][:, 1]

        for i in 1:nbuses_ac[ng][]
            # ---- Voltage magnitude and angle ----
            formatted_vm_ac = @sprintf("%.3f", sqrt(vn2_ac_k[ng][i]))
            formatted_va_ac = @sprintf("%.2f", theta_ac_k[ng][i] * 180 / pi)
            ref_mark = (i == recRef_ac[ng][]) ? "*" : " "

            print(io, lpad(ng, 3), " ", lpad(i, 7), " ",
                lpad(formatted_vm_ac, 11), " / ", rpad(formatted_va_ac, 6), ref_mark)

            # ---- Generator data ----
            if i in genidx
                m = generator_ac[ng][:, 1]
                idx = findfirst(x -> x == i, m)
                formatted_pgen_ac = @sprintf("%.3f", pgen_ac_k[ng][idx] * baseMVA_ac)
                formatted_qgen_ac = @sprintf("%.3f", qgen_ac_k[ng][idx] * baseMVA_ac)
                formatted_pd = @sprintf("%.3f", pd_ac[ng][i] * baseMVA_ac)
                formatted_qd = @sprintf("%.3f", qd_ac[ng][i] * baseMVA_ac)
                print(io, lpad(formatted_pgen_ac, 11), lpad(formatted_qgen_ac, 10),
                        lpad(formatted_pd, 11), lpad(formatted_qd, 11))
            else
                formatted_pd = @sprintf("%.3f", pd_ac[ng][i] * baseMVA_ac)
                formatted_qd = @sprintf("%.3f", qd_ac[ng][i] * baseMVA_ac)
                print(io, "       -         -", lpad(formatted_pd, 14), lpad(formatted_qd, 11))
            end

            # ---- RES data ----
            if i in residx
                m = res_ac[ng][:, 1]
                idx = findfirst(x -> x == i, m)
                formatted_pres = @sprintf("%.3f", pres_ac_k[ng][idx] * baseMVA_ac)
                formatted_qres = @sprintf("%.3f", qres_ac_k[ng][idx] * baseMVA_ac)
                println(io, lpad(formatted_pres, 12), lpad(formatted_qres, 12))
            else
                println(io, "          -           -")
            end
        end
    end
        
    totalGenerationCost = objective_value(model)
    println(io, "-----   -----   ------------------  --------   ---------   -------   ---------   ---------  ----------")
    println(io, @sprintf("The total generation costs is ＄%.2f/MWh (€%.2f/MWh)", totalGenerationCost, totalGenerationCost / 1.08))
    print(io, "\n") 

    # ----------------------------
    # Print AC Grid Branch Data
    # ----------------------------
    println(io, "===========================================================================================")
    println(io, "|     AC Grid Branch Data                                                                 |")
    println(io, "===========================================================================================")
    println(io, " Area   Branch  From   To        From Branch Flow         To Branch Flow      Branch Loss")
    println(io, " #      #       Bus#   Bus#    Pij [MW]   Qij [MVAr]    Pij [MW]   Qij [MVAr]  Pij_loss [MW]")
    println(io, " ----   ------  -----  -----  ---------  ----------   ----------  ----------    --------")

        global totalACPowerLoss  = 0.0

        for ng in 1:ngrids
            for i in 1:nbranches_ac[ng][]
                formatted_pij_fwd = @sprintf("%.3f", value(pij_ac[ng][fbus_ac[ng][i], tbus_ac[ng][i]]) * baseMVA_ac)
                formatted_qij_fwd = @sprintf("%.3f", value(qij_ac[ng][fbus_ac[ng][i], tbus_ac[ng][i]]) * baseMVA_ac)
                formatted_pij_bwd = @sprintf("%.3f", value(pij_ac[ng][tbus_ac[ng][i], fbus_ac[ng][i]]) * baseMVA_ac)
                formatted_qij_bwd = @sprintf("%.3f", value(qij_ac[ng][tbus_ac[ng][i], fbus_ac[ng][i]]) * baseMVA_ac)
                branch_loss = abs(value(pij_ac[ng][fbus_ac[ng][i], tbus_ac[ng][i]]) * baseMVA_ac + value(pij_ac[ng][tbus_ac[ng][i], fbus_ac[ng][i]]) * 100)
            
                global totalACPowerLoss += branch_loss

            println(io,
                lpad(ng, 4), " ", 
                lpad(i, 8), " ", 
                lpad(fbus_ac[ng][i], 6), " ", 
                lpad(tbus_ac[ng][i], 6), " ", 
                lpad(formatted_pij_fwd, 10), " ", 
                lpad(formatted_qij_fwd, 11), " ", 
                lpad(formatted_pij_bwd, 12), " ", 
                lpad(formatted_qij_bwd, 11), " ", 
                lpad(@sprintf("%.3f", branch_loss), 11)
                )
            end
        end

    println(io, " ----   ------  -----  -----  ---------  ----------   ----------  ----------    --------")
    println(io, "The total AC network losses is ", @sprintf("%.3f MW", totalACPowerLoss))
    println(io, " ")
        
    # ----------------------------
    # Print DC Grid Bus Data
    # ---------------------------- 
    println(io, "================================================================================")
    println(io, "|   MTDDC Bus Data                                                             |")
    println(io, "================================================================================")
    println(io, " Bus   Bus    AC   DC Voltage   DC Power   PCC Bus Injection   Converter loss")
    println(io, " DC #  AC #  Area   Vdc [pu]    Pdc [MW]   Ps [MW]  Qs [MVAr]  Conv_Ploss [MW]")
    println(io, "-----  ----  ----  ---------    --------   -------  --------    --------")
        
    for i in 1:nbuses_dc
        formatted_vn_dc = @sprintf("%.3f", sqrt(value(vn2_dc[i])))
        formatted_pn_dc = @sprintf("%.3f", value(pn_dc[i]) * baseMW_dc)
        formatted_ps = @sprintf("%.3f", value(ps_dc[i]) * baseMW_dc)
        formatted_qs = @sprintf("%.3f", value(qs_dc[i]) * baseMW_dc)
        formatted_convPloss = @sprintf("%.3f", value(convPloss_dc[i]) * baseMW_dc)
        
        println(io, 
        lpad(i, 4), " ", 
        lpad(Int(conv_dc[i, 2]), 5), " ", 
        lpad(Int(conv_dc[i, 3]), 5), " ", 
        lpad(formatted_vn_dc, 9), " ", 
        lpad(formatted_pn_dc, 12), " ", 
        lpad(formatted_ps, 9), " ", 
        lpad(formatted_qs, 9), " ", 
        lpad(formatted_convPloss, 11),
        )
    end
        
    println(io, "-----  ----  ----  ---------    --------   -------  --------    --------")
    println(@sprintf("The total converter losses is %.3f MW", sum(value.(convPloss_dc)) * baseMW_dc))
    println(io, " ")

    # ----------------------------
    # Print DC Grid Branch Data
    # ---------------------------- 
    println(io, "================================================================================")
    println(io, "|     MTDC Branch Data                                                         |")
    println(io, "================================================================================")
    println(io, " Branch  From   To     From Branch    To Branch      Branch Loss")
    println(io, " #       Bus#   Bus#   Flow Pij [MW]  Flow Pij [MW]  Pij_loss [MW]")
    println(io, " ------  -----  -----   ---------      ---------      --------")

    for i in 1:nbranches_dc
        formatted_pij_fwd = @sprintf("%.3f", value(pij_dc[fbus_dc[i], tbus_dc[i]]) * baseMW_dc * pol_dc)
        formatted_pij_bwd = @sprintf("%.3f", value(pij_dc[tbus_dc[i], fbus_dc[i]]) * baseMW_dc * pol_dc)
        formatted_loss = @sprintf("%.3f", abs(value(pij_dc[fbus_dc[i], tbus_dc[i]] + pij_dc[tbus_dc[i], fbus_dc[i]]) * baseMW_dc) * pol_dc)
        
        println(io,
        lpad(i, 7), "  ",                  
        lpad(fbus_dc[i], 4), "  ",         
        lpad(tbus_dc[i], 5), "  ",        
        lpad(formatted_pij_fwd, 10), "  ", 
        lpad(formatted_pij_bwd, 13), "  ", 
        lpad(formatted_loss, 12)          
        )
    end

    println(io, " ------  -----  -----   ---------      ---------      --------")
            
    global totalDCPowerLoss = 0.0

    for i in 1:nbranches_dc
        global totalDCPowerLoss += abs(value(pij_dc[fbus_dc[i], tbus_dc[i]]) * baseMW_dc + value(pij_dc[tbus_dc[i], fbus_dc[i]]) * baseMW_dc) * pol_dc
    end

    println(io, "The total DC network losses is $(@sprintf("%.3f", totalDCPowerLoss)) MW.")
    println(io, " ")
    formatted_time = @sprintf("%.3fs", elapsed_time)
    println(io, "Excution time is ", formatted_time)

    if writeTxt
        close(io)
        @info "OPF results saved to $(outfile)"
    end

    # ----------------------------
    # Visualize OPF Results
    # ---------------------------- 
    if plotResult
        viz_opf(bus_entire_ac, branch_entire_ac, gen_entire_ac, res_entire_ac,
            pgen_ac_k, qgen_ac_k, pij_ac_k, qij_ac_k, pres_ac_k, qres_ac_k, vn2_ac_k, baseMVA_ac, 
            bus_dc, branch_dc, conv_dc, pij_dc_k, ps_dc_k, qs_dc_k, vn2_dc_k, pol_dc, baseMW_dc)
    end
    
end
