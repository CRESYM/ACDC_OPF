function solve_opf(caseName_dc, caseName_ac, varargin)
% SOLVE_OPF - Perform AC/DC Optimal Power Flow (OPF) analysis using YALMIP.
%
%   Loads AC and DC network parameters from the specified case files, 
%   sets up the optimization variables and constraints
%   for both the DC grid and AC networks, and then solves the AC/DC OPF problem.
%  
%   INPUTS:
%       caseName_ac - Case name for the AC grid (e.g., 'ac14ac57')
%       caseName_dc - Case name for the DC grid (e.g., 'mtdc3slack_a')
%       vscControl  - Enable VSC control constraint (default is 'true')
%       writeTxt    - Enable save of printed AC/DC OPF results as a .txt
%       file (default is 'false')
%       plotResults - Enable visulization of AC/DC OPF results (default is
%       'true')
%
%   OUTPUTS:
%       Printed AC/DC OPF results.
% 
%   See also: params_ac.m, params_dc.m

    %% 0. Function Initialization
    p = inputParser;
    addParameter(p, 'vscControl', false);     
    addParameter(p, 'writeTxt', false);      
    addParameter(p, 'plotResult', true);    
    parse(p, varargin{:});

    vscControl = p.Results.vscControl;
    writeTxt   = p.Results.writeTxt;
    plotResult = p.Results.plotResult;

     %% 1. Load AC and DC Parameters
    [network_dc, baseMW_dc, bus_dc, branch_dc, conv_dc, pol_dc, nbuses_dc, nbranches_dc, nconvs_dc, fbus_dc, tbus_dc, ...
        ybus_dc, rtf_dc, xtf_dc, bf_dc, rc_dc, xc_dc, ztfc_dc, gtfc_dc, btfc_dc, ...
        aloss_dc, bloss_dc, closs_dc, convState_dc, baseKV_dc] = params_dc(caseName_dc);
    
    [network_ac, baseMVA_ac, bus_entire_ac, branch_entire_ac, ...
    gen_entire_ac, gencost_entire_ac, res_entire_ac, ...
    ngrids, bus_ac, branch_ac, generator_ac, gencost_ac, res_ac,...
    recRef_ac, pd_ac, qd_ac, sres_ac, nbuses_ac, nbranches_ac, ngens_ac, nress_ac, ...
    GG_ac, BB_ac, GG_ft_ac, BB_ft_ac, GG_tf_ac, BB_tf_ac, fbus_ac, tbus_ac] = params_ac(caseName_ac);
 
    tic; 
    %% 2. Execute AC/DC OPF
    % Set up DC variables and constraints
    [var_dc, lb_dc, ub_dc, con_dc] = setup_dc(nbuses_dc, nconvs_dc, bus_dc, conv_dc, ybus_dc, pol_dc, baseMW_dc, ...
        gtfc_dc, btfc_dc, aloss_dc, bloss_dc, closs_dc, convState_dc);
    % Unpack DC variables
    [vn2_dc, pn_dc, ps_dc, qs_dc, pc_dc, qc_dc, v2s_dc, v2c_dc, Ic_dc, lc_dc, pij_dc, lij_dc, ...
        Ctt_dc, Ccc_dc, Ctc_dc, Stc_dc, Cct_dc, Sct_dc, convPloss_dc] = var_dc{:};
    
    % Set up AC variables and constraints
    [var_ac, lb_ac, ub_ac, con_ac] = setup_ac(ngrids, nbuses_ac, ngens_ac, nress_ac, bus_ac, generator_ac, res_ac, ...
        GG_ac, BB_ac, sres_ac, baseMVA_ac);
    % Unpack AC variables for each grid
    for ng = 1:ngrids
        [vn2_ac{ng}, pn_ac{ng}, qn_ac{ng}, pgen_ac{ng}, qgen_ac{ng}, pij_ac{ng}, qij_ac{ng}, ...
            ss_ac{ng}, cc_ac{ng}, pres_ac{ng}, qres_ac{ng}] = var_ac{ng}{:};
    end
    
    % Set up AC/DC coupling constraints
    [con_cp] = setup_cp(ngrids, nbuses_ac, ngens_ac, nress_ac, pn_ac, qn_ac, pgen_ac, qgen_ac, pd_ac, qd_ac, ...
            pres_ac, qres_ac, vn2_ac, generator_ac, res_ac, nconvs_dc, ps_dc, qs_dc, v2s_dc, conv_dc);
    
    % Set up the objective function
    [Obj] = setup_obj(ngrids, generator_ac, gencost_ac, pgen_ac, res_ac, pres_ac, baseMVA_ac);
    
    % Combine all constraints
    Con = [con_dc; con_ac; con_cp];
    
    %% 3. Set solver options 
    ops = sdpsettings('solver', 'gurobi', 'verbose', 2, ...
            'gurobi.TimeLimit', 600, 'gurobi.Threads', 8, 'gurobi.Presolve', 2);
    
    opfout = optimize(Con, Obj, ops);
    cputime = toc;
    
    %% 4. Extract Optimization Results (Convert to Numeric Values)
    var_dc_k = cellfun(@value, var_dc, 'UniformOutput', false);
    [vn2_dc_k, pn_dc_k, ps_dc_k, qs_dc_k, pc_dc_k, qc_dc_k, v2s_dc_k, v2c_dc_k, Ic_dc_k, lc_dc_k, pij_dc_k, lij_dc_k, ...
        Ctt_dc_k, Ccc_dc_k, Ctc_dc_k, Stc_dc_k, Cct_dc_k, Sct_dc_k, convPloss_dc_k] = var_dc_k{:};
    
    var_ac_k = cell(ngrids, 1);
    for ng = 1:ngrids
        var_ac_k{ng} = cellfun(@value, var_ac{ng}, 'UniformOutput', false);
        [vn2_ac_k{ng}, pn_ac_k{ng}, qn_ac_k{ng}, pgen_ac_k{ng}, qgen_ac_k{ng}, pij_ac_k{ng}, qij_ac_k{ng}, ...
            ss_ac_k{ng}, cc_ac_k{ng}, pres_ac_k{ng}, qres_ac_k{ng}] = var_ac_k{ng}{:};
    end
    
    %% 5. Visulization AC/DC OPF Resutls
    if plotResult
        viz_opf(bus_entire_ac, branch_entire_ac, gen_entire_ac, res_entire_ac, ...
            pgen_ac_k, qgen_ac_k, pij_ac_k, qij_ac_k, pres_ac_k, qres_ac_k, vn2_ac_k, baseMVA_ac, ...
            bus_dc, branch_dc, conv_dc, pij_dc_k, ps_dc_k, qs_dc_k, vn2_dc_k, pol_dc, baseMW_dc)
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Set Output Directory (1 = command window)
    if writeTxt
        filePath = fullfile(pwd, 'opf_results.txt');
        fid = fopen(filePath, 'w', 'n', 'UTF-8');  
    else
        fid = 1;  
    end

    %% Voltage Anlge Reconstruction
    theta_ac_k = cell(ngrids, 1);     
    theta_s_k = zeros(nconvs_dc, 1); 
    theta_c_k = zeros(nconvs_dc, 1); 
    
    for ng = 1:ngrids
        % ---- find reference bus ----
        if ~isempty(recRef_ac{ng})
            ref_bus = recRef_ac{ng};   % have reference bus
        else
            % if no, the AC terminal (c node) of VSC is as the reference bus 
            vsc_idx = find(conv_dc(:,3) == ng, 1);
            ref_bus = conv_dc(vsc_idx, 2);
        end
    
        theta_ac_k{ng} = recover_angle(cc_ac_k{ng}, ss_ac_k{ng}, ref_bus);
    end
    
    % ---- θ_s ----
    for i = 1:nconvs_dc
        k = conv_dc(i,3);   % AC grid index
        j = conv_dc(i,2);   % PCC bus number
        theta_s_k(i) = theta_ac_k{k}(j);
    end
        
    % ---- θ_c ----
    for i = 1:nconvs_dc
        dtheta_sc = atan2(Stc_dc_k(i), Ctc_dc_k(i));  
        theta_c_k(i) = theta_s_k(i) - dtheta_sc;
    end
    
  
    %%  Print OPF Results of AC Grid Bus
        fprintf(fid, '\n=================================================================================================');
        fprintf(fid, '\n|      AC Grid Bus Data                                                                         |');
        fprintf(fid, '\n=================================================================================================');
        fprintf(fid, '\n Area   Branch       Voltage              Generation               Load                    RES');
        fprintf(fid, '\n #      #       Mag [pu]/Ang [deg]    Pg [MW]   Qg [MVAr]   Pd [MW]   Qd [MVAr]   Pres [MW]  Qres [MVAr] ');
        fprintf(fid, '\n-----   -----   ------------------   --------   ---------   -------   ---------   ---------  ----------- ');
        
        for ng = 1:ngrids
            % Obtain generator bus indices for current grid
            genidx = generator_ac{ng}(:, 1);
            residx = res_ac{ng}(:, 1);
        
            for i = 1:nbuses_ac{ng}
                % ---- Voltage magnitude and phase ----
                formatted_vm_ac = sprintf('%.3f', sqrt(vn2_ac_k{ng}(i)));
                formatted_va_ac = sprintf('%.2f', rad2deg(theta_ac_k{ng}(i)));  
        
                % Mark reference bus with an asterisk
                if i == recRef_ac{ng}
                    ref_mark = '*';
                else
                    ref_mark = ' ';   
                end
                fprintf(fid, '\n %3d %7d %8s / %-5s %1s', ng, i, formatted_vm_ac, formatted_va_ac, ref_mark);
        
                % ---- Generator data ----
                if ismember(i, genidx)
                    m = generator_ac{ng}(:,1);
                    idx = find(m == i, 1);
                    formatted_pgen_ac = sprintf('%.3f', pgen_ac_k{ng}(idx) * baseMVA_ac);
                    formatted_qgen_ac = sprintf('%.3f', qgen_ac_k{ng}(idx) * baseMVA_ac);
                    fprintf(fid, '%13s %10s', formatted_pgen_ac, formatted_qgen_ac);
        
                    formatted_pd = sprintf('%.3f', pd_ac{ng}(i) * baseMVA_ac);
                    formatted_qd = sprintf('%.3f', qd_ac{ng}(i) * baseMVA_ac);
                    fprintf(fid, '%11s %11s', formatted_pd, formatted_qd);
        
                else
                    fprintf(fid, '        -         -');
                    formatted_pd = sprintf('%.3f', pd_ac{ng}(i) * baseMVA_ac);
                    formatted_qd = sprintf('%.3f', qd_ac{ng}(i) * baseMVA_ac);
                    fprintf(fid, '%16s %11s', formatted_pd, formatted_qd);
                end
        
                % ---- RES data ----
                if ismember(i, residx)
                    m = res_ac{ng}(:,1);
                    idx = find(m == i, 1);
                    formatted_pres  = sprintf('%.3f', pres_ac_k{ng}(idx) * baseMVA_ac);
                    formatted_qres  = sprintf('%.3f', qres_ac_k{ng}(idx) * baseMVA_ac);
                    fprintf(fid,' %10s %12s', formatted_pres, formatted_qres);
                else                               
                    fprintf(fid,' %8s %11s','-','-');
                end
            end
        end
        fprintf(fid, '\n-----   -----   ------------------   --------   ---------   -------   ---------   ---------  ----------- ');

      % Print total generation cost
      totalGenerationCost = value(Obj);
      fprintf(fid, '\n The total generation cost is ＄%.2f/MWh(€%.2f/MWh)', totalGenerationCost, totalGenerationCost/1.08);
      fprintf(fid, '\n');
    
    %% Print OPF Results of AC Grid Branch
      fprintf(fid, '\n===========================================================================================');
      fprintf(fid, '\n|     AC Grid Branch Data                                                                 |');
      fprintf(fid, '\n===========================================================================================');
      fprintf(fid, '\n Area   Branch  From   To        From Branch Flow         To Branch Flow      Branch Loss');
      fprintf(fid, '\n #      #       Bus#   Bus#    Pij [MW]   Qij [MVAr]    Pij [MW]   Qij [MVAr]  Pij_loss [MW]');
      fprintf(fid, '\n ----   ------  -----  -----  ---------  ----------   ----------  ----------    --------');
      
      for ng = 1:ngrids
          for i = 1:nbranches_ac{ng}
              formatted_pij_fwd = sprintf('%.3f', pij_ac_k{ng}(fbus_ac{ng}(i), tbus_ac{ng}(i)) * baseMVA_ac);
              formatted_qij_fwd = sprintf('%.3f', qij_ac_k{ng}(fbus_ac{ng}(i), tbus_ac{ng}(i)) * baseMVA_ac);
              formatted_pij_bwd = sprintf('%.3f', pij_ac_k{ng}(tbus_ac{ng}(i), fbus_ac{ng}(i)) * baseMVA_ac);
              formatted_qij_bwd = sprintf('%.3f', qij_ac_k{ng}(tbus_ac{ng}(i), fbus_ac{ng}(i)) * baseMVA_ac);
              formatted_branch_loss = sprintf('%.3f', abs(pij_ac_k{ng}(fbus_ac{ng}(i), tbus_ac{ng}(i)) * baseMVA_ac + ...
                                                          pij_ac_k{ng}(tbus_ac{ng}(i), fbus_ac{ng}(i)) * baseMVA_ac));
              fprintf(fid, '\n %2d %6d %7d %6d %12s %11s %12s %11s %11s', ng, i, fbus_ac{ng}(i), tbus_ac{ng}(i), ...
                  formatted_pij_fwd, formatted_qij_fwd, formatted_pij_bwd, formatted_qij_bwd, formatted_branch_loss);
          end
      end
      fprintf(fid, '\n ----   ------  -----  -----  ---------  ----------   ----------  ----------    --------');
    
      totalACPowerLoss = 0;
      for ng = 1:ngrids
          for i = 1:nbranches_ac{ng}
              totalACPowerLoss = totalACPowerLoss + abs(pij_ac_k{ng}(fbus_ac{ng}(i), tbus_ac{ng}(i)) * baseMVA_ac + ...
                                              pij_ac_k{ng}(tbus_ac{ng}(i), fbus_ac{ng}(i)) * baseMVA_ac);
          end
      end
      fprintf(fid, '\n The total AC network losses is %.3f MW .', totalACPowerLoss);
      fprintf(fid, '\n');
     
     %% Print OPF Results of MTDC Bus
      fprintf(fid, '\n================================================================================');
      fprintf(fid, '\n|     MTDC Bus Data                                                            |');
      fprintf(fid, '\n================================================================================');
      fprintf(fid, '\n Bus   Bus   Area   DC Voltage   DC Power   PCC Bus Injection   Converter loss');
      fprintf(fid, '\n DC #  AC #  #       Vdc [pu]    Pdc [MW]   Ps [MW]  Qs [MVAr]  Conv_Ploss [MW]');
      fprintf(fid, '\n-----  ----  ----  ---------    --------   -------  --------    --------');
      
      for i = 1:nbuses_dc
          formatted_vn_dc = sprintf('%.3f', sqrt(vn2_dc_k(i)));
          formatted_pn_dc = sprintf('%.3f', pn_dc_k(i) * baseMW_dc);
          formatted_ps_dc = sprintf('%.3f', ps_dc_k(i) * baseMW_dc);
          formatted_qs_dc = sprintf('%.3f', qs_dc_k(i) * baseMW_dc);
          formatted_convPloss_dc = sprintf('%.3f', convPloss_dc_k(i) * baseMW_dc);
          fprintf(fid, '\n %3d %5d %5d %9s %12s %9s %9s %11s', i, conv_dc(i,2), conv_dc(i,3), ...
              formatted_vn_dc, formatted_pn_dc, formatted_ps_dc, formatted_qs_dc, formatted_convPloss_dc);
      end
      fprintf(fid, '\n-----  ----  ----  ---------    --------   -------  --------    --------');
      fprintf(fid, '\n The total converter losses is %.3f MW', sum(convPloss_dc_k) * baseMW_dc);
      fprintf(fid, '\n');
    
      %% 4. Print OPF Results of MTDC Branch
      fprintf(fid, '\n ===================================================================');
      fprintf(fid, '\n |     MTDC Branch Data                                            |');
      fprintf(fid, '\n ===================================================================');
      fprintf(fid, '\n Branch  From   To     From Branch    To Branch      Branch Loss');
      fprintf(fid, '\n #       Bus#   Bus#   Flow Pij [MW]  Flow Pij [MW]  Pij_loss [MW]'); 
      fprintf(fid, '\n ------  -----  -----   ---------      ---------      --------');
      
      for i = 1:nbranches_dc
          formatted_pij_fwd_dc = sprintf('%.3f', pij_dc_k(fbus_dc(i), tbus_dc(i)) * baseMW_dc * pol_dc);
          formatted_pij_bwd_dc = sprintf('%.3f', pij_dc_k(tbus_dc(i), fbus_dc(i)) * baseMW_dc * pol_dc);
          formatted_loss_dc = sprintf('%.3f', abs((pij_dc_k(fbus_dc(i), tbus_dc(i)) + pij_dc_k(tbus_dc(i), fbus_dc(i))) * baseMW_dc) * pol_dc);
          fprintf(fid, '\n %5d %6d %6d %11s %14s %13s', i, fbus_dc(i), tbus_dc(i), ...
              formatted_pij_fwd_dc, formatted_pij_bwd_dc, formatted_loss_dc);
      end
      fprintf(fid, '\n ------  -----  -----   ---------      ---------      --------');
    
      totalDCPowerLoss = 0;
      for i = 1:nbranches_dc
          totalDCPowerLoss = totalDCPowerLoss +  abs(value(pij_dc(fbus_dc(i), tbus_dc(i)))*baseMW_dc+value(pij_dc(tbus_dc(i), fbus_dc(i)))*baseMW_dc) * pol_dc;
      end
      fprintf(fid,'\n The totoal DC network losses is %.3f MW .', totalDCPowerLoss);
      fprintf(fid,'\n');
    
      fprintf(fid,'\n Execution time is %.3fs .',cputime);
      fprintf(fid,'\n');

      if writeTxt
          fclose(fid);
          fprintf('OPF results written to: %s\n', filePath);
      end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [var_dc, lb_dc, ub_dc, con_dc] = setup_dc(nbuses_dc, nconvs_dc, bus_dc, conv_dc, ybus_dc, pol_dc, baseMW_dc, ...
        gtfc_dc, btfc_dc, aloss_dc, bloss_dc, closs_dc, convState_dc)
    % SETUP_DC -Define DC grid optimization variables, bounds, and operational constraints.
    %
    %   INPUTS:
    %       nbuses_dc    - Scalar. Number of DC buses.
    %       nconvs_dc    - Scalar. Number of converters (VSCs) in the DC grid.
    %       bus_dc       - Matrix. DC bus data. 
    %       conv_dc      - Matrix. Converter data.
    %       ybus_dc      - Matrix. DC network admittance matrix.
    %       pol_dc       - Scalar. DC branch polarity. 
    %       baseMW_dc    - Scalar. DC base power value.
    %       gtfc_dc      - Vector. VSC branch Condutance (t-f-c).
    %       btfc_dc      - Vector. VSC branch Susceptance (t-f-c).
    %       aloss_dc     - Vector. VSC converter loss parameter A.
    %       bloss_dc     - Vector. VSC converter loss parameter B.
    %       closs_dc     - Vector. VSC converter loss parameter C.
    %       convState_dc - Vector. VSC converter state indicator.  
    %
    %   OUTPUTS:
    %       var_dc   - Cell arrary. Decision variables for the DC grid.
    %       lb_dc    - Cell arrary. Lower bounds for var_dc.
    %       ub_dc    - Cell arrary. Upper bounds for var_dc.
    %       con_dc   - Vector. Contain all DC network constraints.
    %
    %   The DC decision variable vector, var_dc, is constructed with the following blocks:
    %       1. DC nodal voltage squared (vn2_dc)
    %       2. DC nodal active power injection (pn_dc)
    %       3. VSC active power injection at node s (ps_dc)
    %       4. VSC reactive power injection at node s (qs_dc)
    %       5. VSC active power injection at node c (pc_dc)
    %       6. VSC reactive power injection at node c (qc_dc)
    %       7. PCC side voltage squared (v2s_dc)
    %       8. Converter side voltage squared (v2c_dc)
    %       9. VSC current magnitude (Ic_dc)
    %      10. VSC current squared (lc_dc)
    %      11. DC branch power flow (pij_dc)
    %      12. DC branch current squared (lij_dc)
    %      13. VSC SOC relaxed term no.1 (Ctt_dc)
    %      14. VSC SOC relaxed term no.2 (Ccc_dc)
    %      15. VSC SOC relaxed term no.3 (Ctc_dc)
    %      16. VSC SOC relaxed term no.4 (Stc_dc)
    %      17. VSC SOC relaxed term no.5 (Cct_dc)
    %      18. VSC SOC relaxed term no.6 (Sct_dc)
    %      19. VSC power loss (convPloss_dc)
    
        % Initialization (a totoal of 19 kinds of variables)
        var_dc = cell(19, 1);
        lb_dc = cell(19, 1);
        ub_dc = cell(19, 1);
        con_dc = [];
        lb_default = -inf;
        ub_default = inf;
    
        % #1 DC nodal voltage squared -vn2_dc: nbuses_dc x 1 
        vn2_dc = sdpvar(nbuses_dc, 1);
        lb_dc{1} = bus_dc(:,13).^2;
        ub_dc{1} = bus_dc(:,12).^2;
        con_dc = [con_dc; lb_dc{1} <= vn2_dc <= ub_dc{1}];
        
        % #2 DC nodal active power injection -pn_dc: nbuses_dc x 1 
        pn_dc = sdpvar(nbuses_dc, 1);
        lb_dc{2} = lb_default;
        ub_dc{2} = ub_default;
        con_dc = [con_dc; lb_dc{2} <= pn_dc <= ub_dc{2}];
    
        % #3 VSC active power injection at node s -ps_dc: nconvs_dc x 1
        ps_dc = sdpvar(nconvs_dc, 1);
        lb_dc{3} = lb_default;
        ub_dc{3} = ub_default;
        con_dc = [con_dc; lb_dc{3} <= ps_dc <= ub_dc{3}];
    
        % #4 VSC reactive power injection at node s -qs_dc: nconvs_dc x 1
        qs_dc = sdpvar(nconvs_dc, 1);
        lb_dc{4} = lb_default;
        ub_dc{4} = ub_default;
        con_dc = [con_dc; lb_dc{4} <= qs_dc <= ub_dc{4}];
    
        % #5 VSC active power injection at node c -pc_dc: nconvs_dc x 1
        pc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{5} = lb_default;
        ub_dc{5} = ub_default;
        con_dc = [con_dc; lb_dc{5} <= pc_dc <= ub_dc{5}];
    
        % #6 VSC active power injection at node c -qc_dc: nconvs_dc x 1
        qc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{6} = lb_default;
        ub_dc{6} = ub_default;
        con_dc = [con_dc; lb_dc{6} <= qc_dc <= ub_dc{6}];
    
        % #7 PCC side voltage squared -v2s_dc: nconvs_dc x 1
        v2s_dc = sdpvar(nconvs_dc, 1);
        lb_dc{7} = conv_dc(:,16).^2;
        ub_dc{7} = conv_dc(:,15).^2;
        con_dc = [con_dc; lb_dc{7} <= v2s_dc <= ub_dc{7}];
    
        % #8 Converter side voltage squared -v2c_dc: nconvs_dc x 1
        v2c_dc = sdpvar(nconvs_dc, 1);
        lb_dc{8} = conv_dc(:,16).^2;
        ub_dc{8} = conv_dc(:,15).^2;
        con_dc = [con_dc; lb_dc{8} <= v2c_dc <= ub_dc{8}];
    
        % #9 VSC current magnitude -Ic_dc: nconvs_dc x 1
        Ic_dc = sdpvar(nconvs_dc, 1);
        lb_dc{9} = 0;
        ub_dc{9} = conv_dc(:, 17);
        con_dc = [con_dc; lb_dc{9} <= Ic_dc <= ub_dc{9}];
    
        % #10 VSC current squared -lc_dc: nconvs_dc x 1
        lc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{10} = 0;
        ub_dc{10} = conv_dc(:, 17).^2;
        con_dc = [con_dc; lb_dc{10} <= lc_dc <= ub_dc{10}];
    
        % #11 DC branch power flow -pij_dc: nconvs_dc x nconvs_dc
        pij_dc = sdpvar(nconvs_dc, nconvs_dc, 'full');
        lb_dc{11} = lb_default;
        ub_dc{11} = ub_default;
        con_dc = [con_dc; lb_dc{11} <= pij_dc(:) <= ub_dc{11}];
    
        % #12 DC branch current squared -lij_dc: nconvs_dc x nconvs_dc
        lij_dc = sdpvar(nconvs_dc, nconvs_dc, 'full');
        lb_dc{12} = lb_default;
        ub_dc{12} = ub_default;
        con_dc = [con_dc; lb_dc{12} <= lij_dc(:) <= ub_dc{12}];
    
        % #13 VSC SOC relaxed term no.1 -Ctt_dc: nconvs_dc x 1
        Ctt_dc = sdpvar(nconvs_dc, 1);
        lb_dc{13} = lb_default;
        ub_dc{13} = ub_default;
        con_dc = [con_dc; lb_dc{13} <= Ctt_dc <= ub_dc{13}];
    
        % #14 VSC SOC relaxed term no.2 -Ccc_dc: nconvs_dc x 1
        Ccc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{14} = lb_default;
        ub_dc{14} = ub_default;
        con_dc = [con_dc; lb_dc{14} <= Ccc_dc <= ub_dc{14}];
    
        % #15 VSC SOC relaxed term no.3 -Ctc_dc: nconvs_dc x 1
        Ctc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{15} = lb_default;
        ub_dc{15} = ub_default;
        con_dc = [con_dc; lb_dc{15} <= Ctc_dc <= ub_dc{15}];
    
        % #16 VSC SOC relaxed term no.4 -Stc_dc: nconvs_dc x 1
        Stc_dc = sdpvar(nconvs_dc, 1);
        lb_dc{16} = lb_default;
        ub_dc{16} = ub_default;
        con_dc = [con_dc; lb_dc{16} <= Stc_dc <= ub_dc{16}];
    
        % #17 VSC SOC relaxed term no.5 -Cct_dc: nconvs_dc x 1
        Cct_dc = sdpvar(nconvs_dc, 1);
        lb_dc{17} = lb_default;
        ub_dc{17} = ub_default;
        con_dc = [con_dc; lb_dc{17} <= Cct_dc <= ub_dc{17}];
    
        % #18 VSC SOC relaxed term no.6 -Sct_dc: nconvs_dc x 1
        Sct_dc = sdpvar(nconvs_dc, 1);
        lb_dc{18} = lb_default;
        ub_dc{18} = ub_default;
        con_dc = [con_dc; lb_dc{18} <= Sct_dc <= ub_dc{18}];
    
        % #19 VSC power loss -convPloss_dc: nconvs_dc x 1
        convPloss_dc = sdpvar(nconvs_dc, 1);
        lb_dc{19} = lb_default;
        ub_dc{19} = ub_default;
        con_dc = [con_dc; lb_dc{19} <= convPloss_dc <= ub_dc{19}];
    
        var_dc = {vn2_dc, pn_dc, ps_dc, qs_dc, pc_dc, qc_dc, v2s_dc, v2c_dc, Ic_dc, lc_dc, pij_dc, lij_dc, ...
            Ctt_dc, Ccc_dc, Ctc_dc, Stc_dc, Cct_dc, Sct_dc, convPloss_dc};
    
        % --- DC Power Flow Constraints (Second-Order Cone Relaxation) ---
    
        % Calculate DC line impedance from the nodal admittance matrix
        zij_dc = 1./abs(ybus_dc); 
        zij_dc = zij_dc-diag(diag(zij_dc));
        zij_dc(isinf(zij_dc)) = 1e4; 
    
        con_dc = [con_dc; 
            pn_dc == sum(pij_dc, 2) * pol_dc;
            pij_dc + pij_dc' == zij_dc .* lij_dc;
            repmat(vn2_dc, 1, nbuses_dc) - repmat(vn2_dc', nbuses_dc, 1) == zij_dc .* (pij_dc - pij_dc');
            pij_dc.^2 <= lij_dc .* repmat(vn2_dc, 1, nbuses_dc);
            vn2_dc >= 0;
            lij_dc >= 0];
    
         % --- VSC AC Side Power Flow Constraints (Second-Order Cone Relaxation) ---
         con_dc = [con_dc;
            ps_dc == Ctt_dc .* gtfc_dc - Ctc_dc .* gtfc_dc + Stc_dc .* btfc_dc;
            qs_dc == -Ctt_dc .* btfc_dc + Ctc_dc .* btfc_dc + Stc_dc .* gtfc_dc;
            pc_dc == Ccc_dc .* gtfc_dc - Cct_dc .* gtfc_dc + Sct_dc .* btfc_dc;
            qc_dc == -Ccc_dc .* btfc_dc + Cct_dc .* btfc_dc + Sct_dc .* gtfc_dc;
            Ctc_dc == Cct_dc;
            Stc_dc + Sct_dc == 0;
            Cct_dc.^2 + Sct_dc.^2 <= Ccc_dc .* Ctt_dc;
            Ctc_dc.^2 + Stc_dc.^2 <= Ccc_dc .* Ctt_dc;
            Ccc_dc >= 0;
            Ctt_dc >= 0;
            v2s_dc == Ctt_dc;
            v2c_dc == Ccc_dc];
    
        % --- Converter Loss Constraints (Second-Order Cone Relaxation) ---
        con_dc = [con_dc;
            pc_dc + pn_dc + convPloss_dc == 0;
            0 <= convPloss_dc <=1;
            convPloss_dc == aloss_dc+bloss_dc .* Ic_dc + closs_dc .* lc_dc;
            pc_dc.^2 + qc_dc.^2 <= lc_dc .* v2c_dc;
            Ic_dc.^2 <= lc_dc;
            Ic_dc >= 0];
    
        % --- VSC Converter Control Constraints ---
        % If we hope control setpoints of VSC converter be optimized, 
        % the below constraints need to be removed
        if vscControl 
            for i = 1:nconvs_dc   
                % dc side control mode
                if conv_dc(i, 4) == 1   % p control
                    con_dc = [con_dc; pn_dc(i) == -conv_dc(i, 6)/baseMW_dc];
                elseif conv_dc(i,4) == 2 % dc v control
                    con_dc = [con_dc; vn2_dc(i) == conv_dc(i, 8)^2];
                else % droop control 
                    con_dc = [con_dc; pn_dc(i) == (conv_dc(i, 24)-1/conv_dc(i, 23)*(.5+.5*vn2_dc(i)-conv_dc(i,25)))/baseMW_dc*(-1)];
                end
        
                % ac side control mode
                if conv_dc(i,5) == 1   % q control
                    con_dc = [con_dc; qs_dc(i) == -conv_dc(i, 7)/baseMW_dc];
                else % ac v control
                    con_dc = [con_dc; v2s_dc(i) == conv_dc(i,8)^2];
                end
        
                % inverter or rectifier mode 
                if convState_dc(i) == 0 % rectifier 
                    con_dc = [con_dc; ps_dc(i)>=0; pn_dc(i)>=0; pc_dc(i)<=0];
                else % inverter 
                    con_dc = [con_dc; ps_dc(i)<=0; pn_dc(i)<=0; pc_dc(i)>=0];
                end
            end
        end
    
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [var_ac, lb_ac, ub_ac, con_ac] = setup_ac(ngrids, nbuses_ac, ngens_ac, nress_ac, bus_ac, generator_ac, res_ac, ...
            GG_ac, BB_ac, sres_ac, baseMVA_ac)
    % SETUP_AC -Define AC grid optimization variables, bounds, and operational constraints.
    %
    %   INPUTS:
    %       ngrids       - Scalar. Number of AC grids.
    %       nbuses_ac    - Cell array. Each cell contains the number of buses for a AC grid.
    %       ngens_ac     - Cell array. Each cell contains the number of generators for a AC grid.
    %       bus_ac       - Cell array. Each cell is a matrix of bus data for a grid.
    %       generator_ac - Cell array. Each cell is a matrix of generator data for a AC grid.
    %       GG_ac        - Cell array. Real part of the AC admittance matrix.
    %       BB_ac        - Cell array. Imaginary part of the AC admittance matrix.
    %       sres_ac      - Cell array. Each cell is the rated capacity of RESs.
    %       baseMVA_ac   - Scalar. AC base MVA.
    %
    %   OUTPUTS:
    %       var_ac   - Cell arrary. Decision variables for the AC grid.
    %       lb_ac    - Cell arrary. Lower bounds for var_ac.
    %       ub_ac    - Cell arrary. Upper bounds for var_ac.
    %       con_ac   - Vector. Contain all AC network constraints.
    %
    %   The AC decision variable vector, var_ac, is constructed with the following blocks:
    %       1. AC nodal voltage squared (vn2_ac)
    %       2. AC active power injection (pn_ac)
    %       3. AC reactive power injection (qn_ac)
    %       4. Generator active power output (pgen_ac)
    %       5. Generator reactive power output (qgen_ac)
    %       6. AC branch active power flow (pij_ac)
    %       7. AC branch reactive power flow (qij_ac)
    %       8. AC SOC relaxed term no.1 (ss_ac)
    %       9. AC SOC relaxed term no.2 (cc_ac)
    %       10. RES active power output (pres_ac)
    %       11. RES reactive power output (qres_ac)
    
        % Initialize cell arrays for each grid   
        var_ac = cell(ngrids, 1);
        lb_ac = cell(ngrids, 1);
        ub_ac = cell(ngrids, 1);
        vn2_ac = cell(ngrids, 1);
        pn_ac = cell(ngrids, 1);
        qn_ac = cell(ngrids, 1);
        pgen_ac = cell(ngrids, 1);
        qgen_ac = cell(ngrids, 1);
        pij_ac = cell(ngrids, 1);
        qij_ac = cell(ngrids, 1);
        ss_ac = cell(ngrids, 1);
        cc_ac = cell(ngrids, 1);
        pres_ac = cell(ngrids, 1);
        qres_ac = cell(ngrids, 1);
    
        con_ac = [];
        lb_default = -inf;
        ub_default = inf;
    
        for ng = 1:ngrids
            
            % Initialization (a totoal of 9 kinds of variables)
            var_ac{ng} = cell(11, 1);
            lb_ac{ng} = cell(11, 1);
            ub_ac{ng} = cell(11, 1);
            nbuses = nbuses_ac{ng};
            ngens = ngens_ac{ng};
            nress = nress_ac{ng};
    
            % #1 AC nodal voltage squared (vn2_ac): nbuses x 1
            vn2_ac{ng} = sdpvar(nbuses, 1);
            lb_ac{ng}{1} = bus_ac{ng}(:,13).^2;
            ub_ac{ng}{1} = bus_ac{ng}(:,12).^2;
            con_ac = [con_ac; lb_ac{ng}{1} <= vn2_ac{ng} <= ub_ac{ng}{1}];
    
            % #2 AC active power injection (pn_ac): nbuses x 1
            pn_ac{ng} = sdpvar(nbuses, 1);
            lb_ac{ng}{2} = lb_default;
            ub_ac{ng}{2} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{2} <= pn_ac{ng} <= ub_ac{ng}{2}];
    
            % #3 AC reactive power injection (qn_ac): nbuses x 1
            qn_ac{ng} = sdpvar(nbuses, 1);
            lb_ac{ng}{3} = lb_default;
            ub_ac{ng}{3} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{3} <= qn_ac{ng} <= ub_ac{ng}{3}];
    
            % #4 Generator active power output (pgen_ac): ngens x 1
            pgen_ac{ng} = sdpvar(ngens, 1);
            lb_ac{ng}{4} = generator_ac{ng}(:,10) .* generator_ac{ng}(:,8) / baseMVA_ac;
            ub_ac{ng}{4} = generator_ac{ng}(:,9) .* generator_ac{ng}(:,8) / baseMVA_ac;
            con_ac = [con_ac; lb_ac{ng}{4} <= pgen_ac{ng} <= ub_ac{ng}{4}];
    
            % #5 Generator reactive power output (qgen_ac): ngens x 1
            qgen_ac{ng} = sdpvar(ngens, 1);
            lb_ac{ng}{5} = generator_ac{ng}(:,5) .* generator_ac{ng}(:,8) / baseMVA_ac;
            ub_ac{ng}{5} = generator_ac{ng}(:,4) .* generator_ac{ng}(:,8) / baseMVA_ac;
            con_ac = [con_ac; lb_ac{ng}{5} <= qgen_ac{ng} <= ub_ac{ng}{5}];
    
            % #6 AC branch active power flow (pij_ac): nbuses x nbuses
            pij_ac{ng} = sdpvar(nbuses, nbuses, 'full');
            lb_ac{ng}{6} = lb_default;
            ub_ac{ng}{6} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{6} <= pij_ac{ng} <= ub_ac{ng}{6}];
    
            % #7 AC branch reactive power flow (qij_ac): nbuses x nbuses
            qij_ac{ng} = sdpvar(nbuses, nbuses, 'full');
            lb_ac{ng}{7} = lb_default;
            ub_ac{ng}{7} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{7} <= qij_ac{ng} <= ub_ac{ng}{7}];
    
            % #8 AC SOC relaxed term no.1 (ss_ac): nbuses x nbuses
            ss_ac{ng} = sdpvar(nbuses, nbuses, 'full');
            lb_ac{ng}{8} = lb_default;
            ub_ac{ng}{8} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{8} <= ss_ac{ng} <= ub_ac{ng}{8}];
    
            % #9 AC SOC relaxed term no.2 (cc_ac): nbuses x nbuses
            cc_ac{ng} = sdpvar(nbuses, nbuses, 'full');
            lb_ac{ng}{9} = lb_default;
            ub_ac{ng}{9} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{9} <= cc_ac{ng} <= ub_ac{ng}{9}];

            % #10 RES active power output (pres_ac): nress x 1
            pres_ac{ng} = sdpvar(nress, 1);
            lb_ac{ng}{10} = 0;
            ub_ac{ng}{10} = res_ac{ng}(:, 2) / baseMVA_ac;
            con_ac = [con_ac; lb_ac{ng}{10} <= pres_ac{ng} <= ub_ac{ng}{10}];

            % #11 RES reactive power output (qres_ac): nress x 1
            qres_ac{ng} = sdpvar(nress, 1);
            lb_ac{ng}{11} = lb_default;
            ub_ac{ng}{11} = ub_default;
            con_ac = [con_ac; lb_ac{ng}{11} <= qres_ac{ng} <= ub_ac{ng}{11}];

            % Bundle AC variables into a cell array
            var_ac{ng} = {vn2_ac{ng}, pn_ac{ng}, qn_ac{ng}, pgen_ac{ng}, qgen_ac{ng}, ...
                pij_ac{ng}, qij_ac{ng}, ss_ac{ng}, cc_ac{ng}, pres_ac{ng}, qres_ac{ng} };
    
            % --- AC Power Flow Constraints (Second-Order Cone Relaxation) ---
                diag_ss_ac = diag(ss_ac{ng});     
                diag_cc_ac = diag(cc_ac{ng});        
                diag_BB_ac = diag(BB_ac{ng});       
                diag_GG_ac = diag(GG_ac{ng});   
    
                diag_cc_ac_rep = repmat(diag_cc_ac, 1, nbuses);
    
                % Nodal Power Injection Calculations 
                pn_matrix_ac = diag_ss_ac .* diag_BB_ac + sum(cc_ac{ng} .* GG_ac{ng} - ss_ac{ng} .* BB_ac{ng}, 2);
                qn_matrix_ac = diag_ss_ac .* diag_GG_ac - sum(cc_ac{ng} .* BB_ac{ng} + ss_ac{ng} .* GG_ac{ng}, 2);
                con_ac = [con_ac; 
                     pn_ac{ng} == pn_matrix_ac;
                     qn_ac{ng} == qn_matrix_ac];
    
                %  Branch Power Flow Calculations 
                con_ac = [con_ac; 
                    pij_ac{ng}(:) == (-GG_ac{ng}(:)) .* (diag_cc_ac_rep(:) - cc_ac{ng}(:)) + (-BB_ac{ng}(:)) .* ss_ac{ng}(:);
                    qij_ac{ng}(:) == -(-BB_ac{ng}(:)) .* (diag_cc_ac_rep(:) - cc_ac{ng}(:)) + (-GG_ac{ng}(:)) .* ss_ac{ng}(:)];
    
                % Symmetry 
                %[i_idx, j_idx] = find(~eye(nbuses));  
                U           = triu(true(nbuses),1);          
                [i_idx,j_idx] = find(U);  % i  <j
                con_ac = [con_ac; 
                    cc_ac{ng}(sub2ind([nbuses, nbuses], i_idx, j_idx)) == cc_ac{ng}(sub2ind([nbuses, nbuses], j_idx, i_idx));
                    ss_ac{ng}(sub2ind([nbuses, nbuses], i_idx, j_idx)) + ss_ac{ng}(sub2ind([nbuses, nbuses], j_idx, i_idx)) == 0];
    
                % Relaxation
                con_ac = [con_ac; 
                    cc_ac{ng}(sub2ind([nbuses, nbuses], i_idx, j_idx)).^2 + ...
                    ss_ac{ng}(sub2ind([nbuses, nbuses], i_idx, j_idx)).^2 <= ...
                    cc_ac{ng}(sub2ind([nbuses, nbuses], i_idx, i_idx)) .* ...
                    cc_ac{ng}(sub2ind([nbuses, nbuses], j_idx, j_idx))];
                      
                con_ac = [con_ac; 
                    diag_cc_ac >= 0 
                    diag_cc_ac == vn2_ac{ng}]; 

                % --- AC RES Capacity Constraints (Polygon approximation) ---
                theta = (1:8)' * pi/8;            
                C     = cos(theta);             
                S     = sin(theta);               
                
                Pres = pres_ac{ng};               
                Qres = qres_ac{ng};           
                Sres = sres_ac{ng};       
                
                L =  C * Pres.' + S * Qres.';       
                R =  repmat(Sres.', 8, 1);       
                
                con_ac = [ con_ac;  L(:) <= R(:);    -L(:) <= R(:) ];

        end

    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [con_cp] = setup_cp(ngrids, nbuses_ac, ngens_ac, nress_ac, pn_ac, qn_ac, pgen_ac, qgen_ac, pd_ac, qd_ac, ...
            pres_ac, qres_ac, vn2_ac, generator_ac, res_ac, nconvs_dc, ps_dc, qs_dc, v2s_dc, conv_dc)
    % SETUPCP -Set up AC and VSC coupling constraints for power injections and voltage.
    %
    %   INPUTS:
    %       ngrids       - Number of AC grids.
    %       nbuses_ac    - Cell array. Number of AC buses of AC grids.
    %       pn_ac        - Cell array. Active power injection of AC grids.
    %       qn_ac        - Cell array. Reactive power injection of AC grids.
    %       pgen_ac      - Cell array. Active generator power output of AC grids.
    %       qgen_ac      - Cell array. Reactive generator power output of AC grids.
    %       pd_ac        - Cell array. Active power load of AC grids.
    %       qd_ac        - Cell array. Reactive power load of AC grids.
    %       vn2_ac       - Cell array. Squared node voltage of AC grids. 
    %       generator_ac - Cell array. Generator data matrices for AC grids.
    %       ps_dc        - Vector. Active power injections (PCC) from converters.
    %       qs_dc        - Vector. Reactor power injections (PCC) from converters.
    %       v2s_dc       - Vector. Squared voltage (PCC) from converters.
    %       conv_dc      - Converter data matrices for converters.
    %
    %   OUTPUTS:
    %       con_cp       - Vector. Contain all coupling constraints.
    
    
        % Initialization 
        con_cp = [];
    
        % --- Power Coupling Constraints ---
        for ng = 1:ngrids
            
            nbuses = nbuses_ac{ng};
            ngens = ngens_ac{ng};
            nress = nress_ac{ng};
            a = sdpvar(nbuses, 1);
            % Dummy constraint: ensures con_cp is not empty to avoid errors in later processing.
            con_cp = [con_cp; a==0]; 
    
            %  Every AC node have load 
            pm_ac = -pd_ac{ng} + a;
            qm_ac = -qd_ac{ng} + a;
    
            %  If the AC node connected with generator
            for i = 1:ngens
                index = generator_ac{ng}(i, 1);
                pm_ac(index) = pm_ac(index) + pgen_ac{ng}(i);
                qm_ac(index) = qm_ac(index) + qgen_ac{ng}(i);
            end

            % If the AC node connected with RES
            for i = 1:nress
                index = res_ac{ng}(i, 1);
                pm_ac(index) = pm_ac(index)+pres_ac{ng}(i);
                qm_ac(index) = qm_ac(index)+qres_ac{ng}(i);
            end
    
            %  If the AC node connected with VSC
            for i = 1:nconvs_dc
                if conv_dc(i, 3) == ng
                    index = conv_dc(i, 2);
                    pm_ac(index) = pm_ac(index) - ps_dc(i);
                    qm_ac(index) = qm_ac(index) - qs_dc(i);
                end
            end
    
            con_cp = [con_cp; 
                pn_ac{ng} == pm_ac; 
                qn_ac{ng} == qm_ac;
            ];
        end
            
        % --- Voltage Coupling Constraints ---
        for i = 1:nconvs_dc
            j = conv_dc(i, 2);
            k = conv_dc(i, 3);
            con_cp = [con_cp; vn2_ac{k}(j) == v2s_dc(i)];
        end
    
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [Obj] = setup_obj(ngrids, generator_ac, gencost_ac, pgen_ac, res_ac, pres_ac, baseMVA_ac)
    % SETUPOBJ -Define the optimization objective of AC/DC OPF
    %
    % INPUTS:
    %   ngrids       - Scalar. Number of AC grids.
    %   generator_ac - Cell array. Containing generator data for each AC grid.
    %   gencost_ac   - Cell array. Containing generator cost data for each AC grid.
    %   pgen_ac      - Cell array. Generator active power outputs for each AC grid.
    %   res_ac       - Cell array. Containing RES data for each AC grid.
    %   pres_ac      - Cell array. RES active power outputs for each AC grid
    %   baseMVA_ac   - Scalar. AC base MVA.
    %
    % OUTPUTS:
    %   Obj          - Scalar. The total generation cost across all AC grids.
    
        % Initialization
        Obj = 0;
        
        for ng = 1:ngrids     
            Pgen    = pgen_ac{ng};            
            actgen  = generator_ac{ng}(:, 8);   
            typegen = gencost_ac{ng}(:, 4);      
            agen    = gencost_ac{ng}(:, 5);
            bgen    = gencost_ac{ng}(:, 6);
            cgen    = gencost_ac{ng}(:, 7);

            Pres    = pres_ac{ng};            
            actres  = res_ac{ng}(:, 11);   
            typeres = res_ac{ng}(:, 7);      
            ares    = res_ac{ng}(:, 8);
            bres    = res_ac{ng}(:, 9);
            cres    = res_ac{ng}(:, 10);
        
            % ---------- Quadratic cost (type = 3) ----------
            idxgen3 = (typegen == 3);
            if any(idxgen3)
                Pgen3 = Pgen(idxgen3);             
                costgen3 = baseMVA_ac^2 * agen(idxgen3) .* (Pgen3.^2) + ...
                        baseMVA_ac   * bgen(idxgen3) .*  Pgen3     + ...
                        cgen(idxgen3);
                Obj = Obj + sum( actgen(idxgen3) .* costgen3 );
            end

            idxres3 = (typeres == 3);
            if any(idxres3)
                Pres3 = Pres(idxres3);             
                costres3 = baseMVA_ac^2 * ares(idxres3) .* (Pres3.^2) + ...
                        baseMVA_ac   * bres(idxres3) .*  Pres3     + ...
                        cres(idxres3);
                Obj = Obj + sum( actres(idxres3) .* costres3 );
            end
        
            % ---------- Linear cost (type = 2) ----------
            idxgen2 = (typegen == 2);
            if any(idxgen2)
                Pgen2 = Pgen(idxgen2);
                costgen2 = baseMVA_ac * bgen(idxgen2) .* Pgen2 + c(idxgen2);
                Obj = Obj + sum( actgen(idxgen2) .* costgen2 );
            end

            idxres2 = (typeres == 2);
            if any(idxres2)
                Pres2 = Pres(idxres2);             
                costres2 = baseMVA_ac * bres(idxres2) .*  Pres2 + cres(idxres2);
                Obj = Obj + sum( actres(idxres2) .* costres2 );
            end
        
        end

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function theta = recover_angle(cc, ss, ref)
    % RECOVER_ANGLE -Reconstruct voltage phase angles from SOC variables.
    %
    % INPUTS:
    %   cc   - Array.  SOC variable |V_i||V_j|cos(θ_i - θ_j).
    %   ss   - Array.  SOC variable |V_i||V_j|sin(θ_i - θ_j).
    %   ref  - Scalar. Reference bus index (θ_ref = 0).
    %
    % OUTPUT:
    %   theta - nb×1 vector.  Reconstructed nodal voltage phase angles [rad].
    %
    % NOTES:
    %   The function restores node angles by integrating phase differences
    %   Δθ_ij = atan2(ss_ij, cc_ij) starting from the reference bus.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        nb = size(cc, 1);
        theta = nan(nb, 1);
        theta(ref) = 0;                     % Reference bus angle = 0
        visited = false(nb, 1);
        visited(ref) = true;
    
        G = abs(cc) > 1e-6; 
        G(1:nb+1:end) = 0;                  % Remove self-loops
        stack = [ref];
    
        while ~isempty(stack)
            i = stack(end); 
            stack(end) = [];
    
            for j = find(G(i,:))
                if ~visited(j)
                    dtheta = atan2(ss(i,j), cc(i,j));
                    theta(j) = theta(i) - dtheta;
                    visited(j) = true;
                    stack(end+1) = j;
                end
            end
        end
    end

end
