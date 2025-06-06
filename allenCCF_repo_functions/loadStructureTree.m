function structureTreeTable = loadStructureTree(fn)
% Function to load structure trees, supporting both old and DevCCF formats
% Automatically detects if the file is a DevCCF version based on the file name

if nargin < 1
    p = mfilename('fullpath');
    fn = fullfile(fileparts(fileparts(p)), 'structure_tree_safe_2017.csv');
end

[~, fnBase] = fileparts(fn);
if contains(fnBase, 'DevCCF', 'IgnoreCase', true)
    mode = 'DevCCF'; % New DevCCF version
elseif ~isempty(strfind(fnBase, '2017'))
    mode = '2017'; % Old structure tree
else
    mode = 'old'; % Fallback to old
end

fid = fopen(fn, 'r');
if fid == -1
    error('Unable to open the file: %s', fn);
end

if strcmp(mode, 'old')
    % Old format structure tree (pre-2017)
    titles = textscan(fid, '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s', 1, 'delimiter', ',');
    titles = cellfun(@(x) x{1}, titles, 'uni', false);
    titles{1} = 'index'; % Blank first column in the file

    data = textscan(fid, '%d%s%d%s%d%s%d%d%d%d%d%s%s%d%d%s%d%s%s%d%d', 'delimiter', ',');

elseif strcmp(mode, '2017')
    % 2017 CCF version
    titles = textscan(fid, repmat('%s', 1, 21), 1, 'delimiter', ',');
    titles = cellfun(@(x) x{1}, titles, 'uni', false);

    data = textscan(fid, ['%d%d%s%s'... % 'id'    'atlas_id'    'name'    'acronym'
        '%s%d%d%d'... % 'st_level'    'ontology_id'    'hemisphere_id'    'weight'
        '%d%d%d%d'... % 'parent_structure_id'    'depth'    'graph_id'     'graph_order'
        '%s%s%d%s'... % 'structure_id_path'    'color_hex_triplet' neuro_name_structure_id neuro_name_structure_id_path
        '%s%d%d%d'... % 'failed'    'sphinx_id' structure_name_facet failed_facet
        '%s'], 'delimiter', ','); % safe_name

    titles = ['index' titles];
    data = [[0:numel(data{1})-1]' data];

elseif strcmp(mode, 'DevCCF')
    % DevCCF version

    titles = textscan(fid, repmat('%s', 1, 18), 1, 'delimiter', ',');
    titles = cellfun(@(x) x{1}, titles, 'uni', false);

    % Define format string for all columns
    data = textscan(fid, ['%s%s%d%s%s%d'...   % acronym, color_hex_id, id, name, structure_id_path, parent_structure_id
        '%s%s%s%s%s%s%s'... % E11_5, E13_5, E15_5, E18_5, P04, P14, P56 (initially as strings)
        '%d%d%d%d%d'],...   % R, G, B, graph_order, depth
        'Delimiter', ',', 'HeaderLines', 1);

    % 2. Convert boolean columns ('E11_5' to 'P56') from strings to numeric
    boolCols = 7:13; % Columns corresponding to E11_5 to P56
    for col = boolCols
        data{col} = cellfun(@(x) strcmpi(x, 'TRUE'), data{col}); % Convert TRUE to 1, FALSE to 0
    end

    % 4. Add an index column
    titles = ['index' titles];
    data = [[0:numel(data{1})-1]' data];

end

% Create the structure tree table
structureTreeTable = table(data{:}, 'VariableNames', titles);

% Close the file
fclose(fid);
end
