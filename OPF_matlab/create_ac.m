function acNet = create_ac(case_name)
% CREATE_AC Reads AC grid data from CSV files.
%
%   acNet = CREATE_AC(case_name) reads the AC grid data from CSV files
%   with the given case_name prefix. The following CSV files are required:
%       case_name_baseMVA_ac.csv
%       case_name_bus_ac.csv
%       case_name_branch_ac.csv
%       case_name_gen_ac.csv
%       case_name_gencost_ac.csv
%       case_name_res_ac.csv
%
%   The function returns a structure dcNet with the fields:
%       acNet.baseMVA    - Scalar base MVA value 
%       acNet.bus        - AC network bus data
%       acNet.branch     - AC network branch data
%       acNet.gen        - AC generator data
%       acNet.gencost    - AC generation cost data
%       acNet.res        - AC integrated renewable energy source data

    base_path = pwd;

    %---------------------------List .csv files----------------------------
    required_files = {...
    [case_name, '_baseMVA_ac.csv'],...
    [case_name, '_bus_ac.csv'],...
    [case_name, '_branch_ac.csv'],...
    [case_name, '_gen_ac.csv'],...
    [case_name, '_gencost_ac.csv'],...
    [case_name, '_res_ac.csv'],...
    };

    %-------------------------Check missing files--------------------------
    missing_files = {};
    for i = 1:length(required_files)
        file_path = fullfile(base_path, required_files{i});
        if ~isfile(file_path)
            missing_files{end+1} = required_files{i}; 
        end
    end

    if ~isempty(missing_files)
        error('Missing required AC files: %s', strjoin(missing_files, ', '));
    end

    %------------------------Read .csv file data---------------------------
    acNet.baseMVA = readmatrix(fullfile(base_path, ...
        [case_name '_baseMVA_ac.csv']));

    acNet.bus = readmatrix(fullfile(base_path, ...
        [case_name '_bus_ac.csv']));

    acNet.branch = readmatrix(fullfile(base_path, ...
        [case_name '_branch_ac.csv']));

    acNet.gen = readmatrix(fullfile(base_path, ...
        [case_name '_gen_ac.csv']));

    acNet.gencost = readmatrix(fullfile(base_path, ...
        [case_name '_gencost_ac.csv']));

    acNet.res = readmatrix(fullfile(base_path, ...
        [case_name '_res_ac.csv']));

end



