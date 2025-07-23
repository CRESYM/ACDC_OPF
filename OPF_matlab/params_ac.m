function [network_ac, baseMVA_ac, bus_entire_ac, branch_entire_ac, ...
    gen_entire_ac, gencost_entire_ac, res_entire_ac, ...
    ngrids, bus_ac, branch_ac, generator_ac, gencost_ac, res_ac,...
    recRef_ac, pd_ac, qd_ac, sres_ac, nbuses_ac, nbranches_ac, ngens_ac, nress_ac, ...
    GG_ac, BB_ac, GG_ft_ac, BB_ft_ac, GG_tf_ac, BB_tf_ac, fbus_ac, tbus_ac] = params_ac(caseName_ac)
% PARAMS_AC Constructs AC network parameters.
%
%   The function processes the entire AC network data grid-by-grid, 
%   compute and return AC grid parameters.
%
%   INPUTS:
%       caseName_ac - A string for for the AC network case.
%
%   OUTPUTS:
%       network_ac         - Structure. Containing all AC network data.
%       baseMVA_ac         - Scalar. AC base MVA.
%       bus_entire_ac      - Matrix. Complete bus data from the AC network.
%       branch_entire_ac   - Matrix. Complete branch data from the AC network.
%       gen_entire_ac      - Matrix. Complete generator data from the AC network.
%       gencost_entire_ac  - Matrix. Complete generator cost data.
%       res_entire_ac      - Matrix. Complete RES data.
%       ngrids             - Scalar. Number of AC grids.
%
%       bus_ac             - Cell array. Bus data for each AC grid.
%       branch_ac          - Cell array. Branch data for each AC grid.
%       generator_ac       - cell array. Generator data for each AC grid.
%       gencost_ac         - cell array. Generator cost for each AC grid.
%       res_ac             - cell array. RES data for each AC grid.
%       
%       recRef_ac          - cell array. Recording the reference bus for each AC grid.
%
%       pd_ac, qd_ac       - cell array. Active/reactive loads (per unit).
%       sres_ac            - cell array. RES capacity (per unit). 
%
%       nbuses_ac          - cell array. Number of buses for each AC grid.
%       nbranches_ac       - cell array. Number of branches for each AC grid.
%       ngens_ac           - cell array. Number of generators for each AC grid.
%       nress_ac           - cell array. Number of RES for each AC grid.
%
%       GG_ac, BB_ac       - cell array. Real and Imaginary parts of the AC admittance matrix (per unit).
%
%       GG_ft_ac, BB_ft_ac - cell array. Branch off-diagonal entries (from-to) (per unit).
%       GG_tf_ac, BB_tf_ac - cell array. Branch off-diagonal entries (to-from) (per unit).
%       fbus_ac, tbus_ac   - cell array. "From" and "to” bus indices per grid.
%
%   See also: create_ac.m, makeYbus.m

    %% Load AC grid data 
    network_ac          = create_ac(caseName_ac);
    bus_entire_ac       = network_ac.bus;
    branch_entire_ac    = network_ac.branch(network_ac.branch(:, 11) == 1, :);
    gen_entire_ac       = network_ac.gen;
    gencost_entire_ac   = network_ac.gencost;
    res_entire_ac       = network_ac.res;
    baseMVA_ac          = network_ac.baseMVA;
    ngrids              = size(unique(bus_entire_ac(:, 14)), 1);

    %% Initialize cells to store grid data
    bus_ac       = cell(ngrids, 1);
    branch_ac    = cell(ngrids, 1);
    generator_ac = cell(ngrids, 1);
    gencost_ac   = cell(ngrids, 1);
    res_ac       = cell(ngrids, 1);

    pd_ac        = cell(ngrids, 1);
    qd_ac        = cell(ngrids, 1);
    sres_ac      = cell(ngrids, 1);

    nbuses_ac    = cell(ngrids, 1);
    nbranches_ac = cell(ngrids, 1);
    ngens_ac     = cell(ngrids, 1);
    nress_ac     = cell(ngrids, 1);

    % AC network admittance components for each grid
    YY_ac        = cell(ngrids, 1);
    GG_ac        = cell(ngrids, 1);
    BB_ac        = cell(ngrids, 1);

    fbus_ac      = cell(ngrids, 1);
    tbus_ac      = cell(ngrids, 1);
    GG_ft_ac     = cell(ngrids, 1);
    BB_ft_ac     = cell(ngrids, 1);
    GG_tf_ac     = cell(ngrids, 1);
    BB_tf_ac     = cell(ngrids, 1);

    % AC network admittance components for each grid
    IDtoCountmap_ac = cell(ngrids, 1);
    recRef_ac       = cell(ngrids, 1);

    %% Process each AC grid
    for ng = 1:ngrids
        % Partition bus, branch, generator, gencost, and RES data for grid #ng
        bus_ac{ng}       = bus_entire_ac(bus_entire_ac(:, 14)==ng, :);
        branch_ac{ng}    = branch_entire_ac(branch_entire_ac(:, 14)==ng, :);
        generator_ac{ng} = gen_entire_ac(gen_entire_ac(:, 22)==ng, :);
        gencost_ac{ng}   = gencost_entire_ac(gencost_entire_ac(:, 8)==ng, :);
        res_ac{ng}       = res_entire_ac(res_entire_ac(:, 12)==ng, :);
    
        % Record the number of buses and branches in grid #ng
        nbuses_ac{ng}    = size(bus_ac{ng}, 1);
        nbranches_ac{ng} = size(branch_ac{ng}, 1);
        ngens_ac{ng}     = size(generator_ac{ng}, 1);
        nress_ac{ng}     = size(res_ac{ng}, 1); 
      
        % Record the reference bus index for this grid 
        IDtoCountmap_ac{ng} = zeros(max(bus_ac{ng}(:,1)), 1);
        refFound = false;
        for i = 1:nbuses_ac{ng}
            busID = bus_ac{ng}(i, 1);
            IDtoCountmap_ac{ng}(busID) = i;
            if bus_ac{ng}(i,2) == 3
                recRef_ac{ng} = i;
                refFound = true;
            end
        end
        if ~refFound
            warning('Reference bus not found in grid %d.', ng);
        end
        
        % Compute AC network admittance matrix
        fbus_ac{ng} = branch_ac{ng}(:,1);
        tbus_ac{ng} = branch_ac{ng}(:,2);
        [YY_ac{ng}, ~, ~] = makeYbus(baseMVA_ac, bus_ac{ng}, branch_ac{ng});
        GG_ac{ng} = real(full(YY_ac{ng}));
        BB_ac{ng} = imag(full(YY_ac{ng}));
    
        % Extract branch "from" and "to" indices for grid #ng
        linIdx_ft = sub2ind(size(GG_ac{ng}), fbus_ac{ng}, tbus_ac{ng});
        linIdx_tf = sub2ind(size(GG_ac{ng}), tbus_ac{ng}, fbus_ac{ng});
        GG_ft_ac{ng} = GG_ac{ng}(linIdx_ft);
        BB_ft_ac{ng} = BB_ac{ng}(linIdx_ft);
        GG_tf_ac{ng} = GG_ac{ng}(linIdx_tf);
        BB_tf_ac{ng} = BB_ac{ng}(linIdx_tf);
    
        % Normalize load values
        pd_ac{ng} = bus_ac{ng}(:,3) / baseMVA_ac;
        qd_ac{ng} = bus_ac{ng}(:,4) / baseMVA_ac;

        % Nomorlize RES capacity
        sres_ac{ng} = res_ac{ng}(:, 3) / baseMVA_ac;
    end

end


