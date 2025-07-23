function viz_opf(bus_entire_ac, branch_entire_ac, gen_entire_ac, res_entire_ac, ...
    pgen_ac_k, qgen_ac_k, pij_ac_k, qij_ac_k, pres_ac_k, qres_ac_k, vn2_ac_k, baseMVA_ac, ...
    bus_dc, branch_dc, conv_dc, pij_dc_k, ps_dc_k, qs_dc_k, vn2_dc_k, pol_dc, baseMW_dc)
% VIZ_OPF Visualizes the AC/DC OPF Results
%
% INPUTS:
%   bus_entire_ac       - Complete bus data from the AC network.
%   branch_entire_ac    - Complete branch data from the AC network.
%   gen_entire_ac       - Complete generator data from the AC network.
%   res_entire_ac       - Complete RES data from the DC network.
%   pgen_ac_k           - Optimized resutls of generator active power.
%   qgen_ac_k           - Optimized results of generator reactive power.
%   pij_ac_k            - Optimized results of the AC branch active power.
%   qij_ac_k            - Optimized results of the AC branch reactive power.
%   pres_ac_k           - Optimized results of the AC RES active power.
%   qres_ac_k           - Optimized results of the AC RES reactive power.
%   vn2_ac_k            - Optimized results of the squared AC voltage.
%   baseMVA_ac          - AC system base MVA value.
%
%   bus_dc              - Bus data from the DC network.
%   branch_dc           - Branch data from the DC network.
%   conv_dc             - Converter data.
%   pij_dc_k            - Optimized resutls of the DC branch active power.
%   ps_dc_k             - Optimized results of the VSC PCC active power.
%   qs_dc_k             - Optimized results of the VSC PCC reactive power.
%   vn2_dc_k            - Optimized results of the squared DC voltage.
%   pol_dc              - Polarity of the DC network
%   baseMW_dc           - DC system base MW value.

% OUTPUTS: Figure
%% Reorder AC Data---------------------------------------------------------
numBuses_ac = size(bus_entire_ac, 1);
oldBusNums_ac = bus_entire_ac(:, 1);
busAreas_ac   = bus_entire_ac(:, end);

newBusNums_ac = (1:numBuses_ac)';
bus_entire_ac_new = bus_entire_ac;
bus_entire_ac_new(:,1) = newBusNums_ac;

mappingMatrix_ac = [oldBusNums_ac, busAreas_ac];
branchAreas_ac = branch_entire_ac(:, end);

[~, idxFrom] = ismember([branch_entire_ac(:,1), branchAreas_ac], mappingMatrix_ac, 'rows');
newFrom = newBusNums_ac(idxFrom);

[~, idxTo] = ismember([branch_entire_ac(:,2), branchAreas_ac], mappingMatrix_ac, 'rows');
newTo = newBusNums_ac(idxTo);

branch_entire_ac_new = branch_entire_ac;
branch_entire_ac_new(:,1) = newFrom;
branch_entire_ac_new(:,2) = newTo;

%% Reorder DC Data---------------------------------------------------------
numBuses_dc = size(bus_dc, 1);
bus_dc_new = bus_dc;
newBusNums_dc = bus_dc(:,1) + numBuses_ac;
bus_dc_new(:,1) = newBusNums_dc;

branch_dc_new = branch_dc;
branch_dc_new(:,1) = branch_dc(:,1) + numBuses_ac;
branch_dc_new(:,2) = branch_dc(:,2) + numBuses_ac;

%% Reorder VSC Data--------------------------------------------------------
conv_dc_new = conv_dc;
conv_dc_new(:,1) = conv_dc(:,1) + numBuses_ac;
mappingMatrix = [bus_entire_ac(:,1), bus_entire_ac_new(:,1), bus_entire_ac(:, end)];
[~, idx] = ismember(conv_dc(:, [2,3]), mappingMatrix(:, [1,3]), 'rows');
conv_dc_new(:,2) = mappingMatrix(idx, 2);

%% Reorder Gen Data--------------------------------------------------------
mappingMatrix = [bus_entire_ac(:,1), bus_entire_ac_new(:,1), bus_entire_ac(:, end)];
[~, idx] = ismember(gen_entire_ac(:, [1, end]), mappingMatrix(:, [1,3]), 'rows');
gen_entire_ac_new = gen_entire_ac;
gen_entire_ac_new(:, 1) = mappingMatrix(idx, 2);
gen_entire_ac_new(:, 2) = vertcat(pgen_ac_k{:}) * baseMVA_ac;
gen_entire_ac_new(:, 3) = vertcat(qgen_ac_k{:}) * baseMVA_ac;

%% Reorder RES Data--------------------------------------------------------
mappingMatrix = [bus_entire_ac(:,1), bus_entire_ac_new(:,1), bus_entire_ac(:, end)];
[~, idx] = ismember(res_entire_ac(:, [1, end]), mappingMatrix(:, [1,3]), 'rows');
res_entire_ac_new = res_entire_ac;
res_entire_ac_new(:, 1) = mappingMatrix(idx, 2);
res_entire_ac_new(:, 2) = vertcat(pres_ac_k{:}) * baseMVA_ac;
res_entire_ac_new(:, 3) = vertcat(qres_ac_k{:}) * baseMVA_ac;

%% Construct Network Graph-------------------------------------------------
fromNode = [branch_entire_ac_new(:, 1); branch_dc_new(:, 1); conv_dc_new(:, 1)];
toNode   = [branch_entire_ac_new(:, 2); branch_dc_new(:, 2); conv_dc_new(:, 2)];
allNodes = unique([fromNode; toNode]);
Graph = graph(fromNode, toNode);

if ~ismember('Name', Graph.Nodes.Properties.VariableNames) || isempty(Graph.Nodes.Name)
    nodeNames = cellstr(num2str(allNodes));
    Graph = reordernodes(Graph, allNodes);
    Graph.Nodes.Name = nodeNames;
end

figure;
axis off;
p = plot(Graph, 'Layout', 'force'); 
p.MarkerSize = ones(1, numnodes(Graph)) * 1e-6;
p.LineWidth = 2;
title('AC/DC OPF Results', 'FontSize', 12, 'FontWeight', 'bold');
hold on;


%% Editing AC node---------------------------------------------------------
nodeNums = [bus_entire_ac_new(:, 1); bus_dc_new(:, 1)];
numNodes = numBuses_ac + numBuses_dc;

acBusNums = bus_entire_ac_new(:, 1);
dcBusNums = bus_dc_new(:, 1);
genBusNums = gen_entire_ac_new(:, 1);
resBusNums = res_entire_ac_new(:, 1);

xAll   = [];   % X 
yAll   = [];   % Y 
sAll   = [];   % Size
cAll   = [];   % Color

for i = 1:length(acBusNums)
    idx = acBusNums(i);

    % -------- Compute power size --------
    loadPower = sqrt( bus_entire_ac_new(bus_entire_ac_new(:,1)==idx, 3).^2 + ...
                      bus_entire_ac_new(bus_entire_ac_new(:,1)==idx, 4).^2 );

    genPower  = 0;
    if ismember(idx, genBusNums)
        genPower = sqrt( gen_entire_ac_new(gen_entire_ac_new(:,1)==idx, 2).^2 + ...
                         gen_entire_ac_new(gen_entire_ac_new(:,1)==idx, 3).^2 );
    end

    resPower  = 0;
    if ismember(idx, resBusNums)
        resPower = sqrt( res_entire_ac_new(res_entire_ac_new(:,1)==idx, 2).^2 + ...
                         res_entire_ac_new(res_entire_ac_new(:,1)==idx, 3).^2 );
    end

    % -------- Collect scatter --------
    % Load（red）
    xAll(end+1) = p.XData(idx);
    yAll(end+1) = p.YData(idx);
    sAll(end+1) = 1e-3 + loadPower;
    cAll(end+1,:) = [1 0 0];          

    % Generator（skyblue）
    if genPower > 0
        xAll(end+1) = p.XData(idx);
        yAll(end+1) = p.YData(idx);
        sAll(end+1) = genPower;
        cAll(end+1,:) = [0.53 0.81 0.98];      
    end

    % RES (green)
    if resPower > 0
        xAll(end+1) = p.XData(idx);
        yAll(end+1) = p.YData(idx);
        sAll(end+1) = resPower;
        cAll(end+1,:) = [0 0.6 0];   
    end
end

[~, order] = sort(sAll,'descend');   
for k = order
    scatter(xAll(k), yAll(k), sAll(k), cAll(k,:), 'o', 'filled');
end
drawnow;   

%% Editing DC node---------------------------------------------------------
dcIndices = find(ismember(nodeNums, dcBusNums));
hold on;
scatter(p.XData(dcIndices), p.YData(dcIndices), 80, [0 0 1], '^', 'filled');
axis off;

%% Editing Edge and Add Colormap of Branch Power---------------------------
numEdges = numedges(Graph);
edgeColors = zeros(numEdges, 3);
numACedges   = size(branch_entire_ac_new, 1);
numDCedges   = size(branch_dc_new, 1);
numConvEdges = size(conv_dc_new, 1);

edgeType = cell(numEdges, 1);
edgePower = cell(numEdges, 1);
for k = 1:numEdges
    endNodes = Graph.Edges.EndNodes(k,:);
    fromN = str2double(endNodes{1});
    toN   = str2double(endNodes{2});
    if ismember(fromN, acBusNums) && ismember(toN, acBusNums)
        edgeType{k} = 'AC';
        Newi = fromN;
        Newj = toN;
        row = find( (branch_entire_ac_new(:,1) == Newi & branch_entire_ac_new(:,2) == Newj) | ...
                    (branch_entire_ac_new(:,1) == Newj & branch_entire_ac_new(:,2) == Newi) );
        if isempty(row)
            error('No matching branch found for Newi=%d, Newj=%d', Newi, Newj);
        elseif numel(row) > 1
            warning('Multiple matches found; using the first one.');
            row = row(1);
        end
        i = branch_entire_ac(row, 1);
        j = branch_entire_ac(row, 2);
        ng = branch_entire_ac(row, end);
        branchPowerAC = sqrt( pij_ac_k{ng}(i, j)^2 + qij_ac_k{ng}(i, j)^2 ) * baseMVA_ac;
        edgePower{k} = branchPowerAC;
    elseif ismember(fromN, dcBusNums) && ismember(toN, dcBusNums)
        edgeType{k} = 'DC';
        Newi = fromN;
        Newj = toN;
        row = find( (branch_dc_new(:,1) == Newi & branch_dc_new(:,2) == Newj) | ...
                    (branch_dc_new(:,1) == Newj & branch_dc_new(:,2) == Newi) );
        i = branch_dc(row, 1);
        j = branch_dc(row, 2);
        branchPowerDC = abs( pij_dc_k(i, j) ) * baseMW_dc * pol_dc;
        edgePower{k} = branchPowerDC;
    else
        edgeType{k} = 'Conv';
        Newi = fromN;
        Newj = toN;
        row = find( (conv_dc_new(:,1) == Newi & conv_dc_new(:,2) == Newj) | ...
                    (conv_dc_new(:,1) == Newj & conv_dc_new(:,2) == Newi) );
        branchPowerConv =  sqrt(ps_dc_k(row)^2+qs_dc_k(row)^2) * baseMVA_ac;
        edgePower{k} = branchPowerConv;
    end
end

Graph.Edges.Type = edgeType;
edgePowerValues = cell2mat(edgePower);

minEdgePower = min(edgePowerValues);
maxEdgePower = max(edgePowerValues);

orangesMap = [
    1.00  0.96  0.92 ;   
    1.00  0.90  0.81 ;
    0.99  0.82  0.64 ;
    0.99  0.68  0.42 ;
    0.99  0.55  0.23 ;
    0.95  0.41  0.07 ;
    0.85  0.28  0.00 ;
    0.65  0.21  0.01 ;
    0.50  0.15  0.02 ];  

nSteps = 512;
x = linspace(1, size(orangesMap,1), nSteps);
orangesFine = interp1(1:size(orangesMap,1), orangesMap, x);

normVals = (edgePowerValues - minEdgePower) / (maxEdgePower - minEdgePower);
edgeColors = interp1(linspace(0,1,nSteps), orangesFine, normVals);

p.EdgeColor = edgeColors;

colormap(orangesFine);
caxis([minEdgePower, maxEdgePower]);
c = colorbar;
c.Label.String = 'Branch Power/MVA(MW)';
c.Label.FontSize = 12;
c.Label.FontWeight = 'bold';
drawnow;

%% Add Text to Node, like Node Number, Node Voltage------------------------
for i = 1:numNodes
    currentBus = nodeNums(i);
    if ismember(currentBus, acBusNums)
        idx_ac = find(bus_entire_ac_new(:,1) == currentBus, 1);
        voltMag_ac = sqrt(vertcat(vn2_ac_k{:}));
        voltageVal = voltMag_ac(idx_ac);
    elseif ismember(currentBus, dcBusNums)
        idx_dc = find(bus_dc_new(:,1) == currentBus, 1);
        voltMag_dc = sqrt(vn2_dc_k(idx_dc));
        voltageVal = voltMag_dc;
    else
        voltageVal = NaN;
    end
    voltageStr = num2str(voltageVal, '%.3f');
    text(p.XData(i), p.YData(i)-0.025, [voltageStr 'p.u.'], 'Color', [0.5, 0.5, 0.5], ...
         'FontSize', 10, 'FontWeight', 'normal', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
end

nodeLabels = cell(numNodes,1);
for i = 1:numNodes
    n = nodeNums(i);
    if n <= numBuses_ac
        nodeLabels{i} = ['#' num2str(bus_entire_ac(n,1))];
    else
        nodeLabels{i} = ['#' num2str(n - numBuses_ac)];
    end
end

p.NodeLabel = {};
for i = 1:numNodes
    text(p.XData(i), p.YData(i), nodeLabels{i}, 'Color', 'k', 'FontSize', 10, 'FontWeight', 'normal', ...
         'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end
drawnow;

%% Legend--------------------------------------------------------------------
markACLoad = scatter(NaN, NaN, 80, [1, 0, 0], 'o', 'filled');   
markACGen  = scatter(NaN, NaN, 80, [0.53, 0.81, 0.98], 'o', 'filled');   
markACRES  = scatter(NaN, NaN, 80, [0, 0.6, 0], 'o', 'filled');   
markDCConv = scatter(NaN, NaN, 80, [0, 0, 1], '^', 'filled');   
markLine = plot(NaN, NaN, 'color', [0.85, 0.5, 0.1], 'LineWidth', 1); 

legend([markACLoad, markACGen, markACRES, markDCConv, markLine], ...
    {'AC Loads', 'AC Generators', 'AC RESs', 'VSC Converters', 'Branch Lines'}, ...
    'Location', 'southeast', 'FontSize', 10);

end

