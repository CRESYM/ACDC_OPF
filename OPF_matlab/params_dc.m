function [network_dc, baseMW_dc, bus_dc, branch_dc, conv_dc, pol_dc, nbuses_dc, nbranches_dc, nconvs_dc, fbus_dc, tbus_dc, ...
    ybus_dc, rtf_dc, xtf_dc, bf_dc, rc_dc, xc_dc, ztfc_dc, gtfc_dc, btfc_dc, ...
    aloss_dc, bloss_dc, closs_dc, convState_dc, baseKV_dc] = params_dc(caseName_dc)
% PARAMS_DC Define DC network parameters.
%
%   This function extracts and computes parameters for the DC network from the
%   specified case.
%
% INPUT:
%   caseName_dc - A string for the DC network case.
%
% OUTPUT:
%   network_dc   - Strcuture. Containing all DC network data.
%   baseMW_dc    - Scalar. DC network MW base.
%   baseKV_dc    - Scalar. AC voltage base for VSC converters.
%   pol_dc       - Scalar. DC network pole.
%   nbuses_dc    - Scalar. Number of DC buses.
%   nbranches_dc - Scalar. Number of DC branches.
%   nconvs_dc    - Scalar. Number of converters.
%   bus_dc       - Matrix. DC network bus data.
%   branch_dc    - Matrix. DC network branch data.
%   conv_dc      - Matrix. VSC converter data.
%   ybus_dc      - Matrix. DC network nodal admittance matrix (absolute values).
%   fbus_dc      - Vector. "From" bus indices for branches.
%   tbus_dc      - Vector. "To" bus indices for branches.
%   rtf_dc       - Vector. PCC side transformer resistances (p.u.).
%   xtf_dc       - Vector. PCC side transformer reactances (p.u.).
%   bf_dc        - Vector. Filter susceptances (p.u.).
%   rc_dc        - Vector. AC terminal side converter resistances (p.u.).
%   xc_dc        - Vector. AC terminal side converter reactances (p.u.).
%   ztfc_dc      - Vector. VSC impedances for PCC side to AC terminal side (p.u.).
%   gtfc_dc      - Vector. Real parts of 1./ztfc_dc (p.u.).
%   btfc_dc      - Vector. Imaginary parts of 1./ztfc_dc (p.u.).
%   aloss_dc     - Vector. Converter loss parameters A (p.u.).
%   bloss_dc     - Vector. Converter loss parameters B (p.u.).
%   closs_dc     - Vector. Converter loss parameters C (p.u.).
%   convState_dc    - Vector. Converter state indicators (1 for inverter, 0 for rectifier).
%
% See also: create_dc.m, mkaeYbus.m

    %% Load DC grid data
    network_dc  = create_dc(caseName_dc);
    baseMW_dc   = network_dc.baseMW;
    bus_dc      = network_dc.bus;
    branch_dc   = network_dc.branch(network_dc.branch(:, 11) == 1, :);
    pol_dc      = network_dc.pol;
    conv_dc     = network_dc.converter;
    baseKV_dc   = conv_dc(:, 14);

    % Calculate the absolute value of the nodal admittance matrix
    [ybus_dc, ~, ~] = makeYbus(baseMW_dc, bus_dc, branch_dc);
    ybus_dc = abs(full(ybus_dc));

    % Determine the number of buses, branches, and converters
    nbuses_dc    = size(bus_dc, 1);
    nbranches_dc = size(branch_dc, 1);
    nconvs_dc    = size(conv_dc, 1);

    % Extract branch "from" and "to" bus indices
    fbus_dc = branch_dc(:, 1);
    tbus_dc = branch_dc(:, 2);

    %% VSC Impedance Parameters
    % The equivalent circuit for the VSC converter is as follows:
    %
    % U_s  ● --[ r_tf + j*x_tf ]-- ● --[ r_c + j*x_c ]-- ● U_c --(VSC)--
    %     PCC                    Filter               AC terminal  
    % PCC side parameters (r_tf, x_tf) and AC terminal side parameters (r_c, x_c)
    % are combined to form the overall converter impedance.
    
    % PCC side transformer parameters
    rtf_dc = conv_dc(:, 9);   
    xtf_dc = conv_dc(:, 10); 
    
    % Filter paramters
    bf_dc  = conv_dc(:, 11);  

    % AC terminal side converter impedance parameters
    rc_dc = conv_dc(:, 12);  
    xc_dc = conv_dc(:, 13);   

    % Combined converter impedance and admittance
    ztfc_dc = complex(rtf_dc + rc_dc, xtf_dc + xc_dc);
    gtfc_dc = real(1 ./ ztfc_dc);  
    btfc_dc = imag(1 ./ ztfc_dc);  

    %% Converter Loss Parameters and State Determination
    % Initialize loss parameters and state indicator arrays.
    aloss_dc = zeros(nconvs_dc, 1);
    bloss_dc = zeros(nconvs_dc, 1);
    closs_dc = zeros(nconvs_dc, 1);
    convState_dc = zeros(nconvs_dc, 1);

    for i = 1:nconvs_dc
        if conv_dc(i, 6) >= 0   % Inverter state
            closs_dc(i) = conv_dc(i, 22);
            convState_dc(i) = 1;
        else                    % Rectifier state
            closs_dc(i) = conv_dc(i, 21);
            convState_dc(i) = 0;
        end
    end

    % Convert loss parameters to per unit values
    closs_dc = closs_dc ./ (baseKV_dc.^2 / baseMW_dc);
    aloss_dc = conv_dc(:, 19) / baseMW_dc;
    bloss_dc = conv_dc(:, 20) ./ baseKV_dc;

end
