function AP_histology(atlasType)
% Toolbar GUI for running histology pipeline
% Allows flexible loading of atlas templates (e.g., "adult" or "P4")

if nargin < 1
    atlasType = 'adult'; % Default to the adult atlas
end

% Get the directory where AP_histology.m is located
ap_histology_path = which('AP_histology'); % Find the function file
if isempty(ap_histology_path)
    error('AP_histology.m not found in the MATLAB path. Ensure it is accessible.');
end
ap_histology_dir = fileparts(ap_histology_path);

% Define the path for the atlas settings file
atlas_settings_path = fullfile(ap_histology_dir, 'atlas_paths.mat');

% Check if the atlas paths file exists
if exist(atlas_settings_path, 'file')
    load(atlas_settings_path, 'templates');
else
    error('Atlas settings file not found! Run `save_atlas_paths.m` to generate it.');
end

% Validate the atlas type
if ~isfield(templates, atlasType)
    error('Atlas type "%s" not found. Available options: %s', atlasType, strjoin(fieldnames(templates), ', '));
end

% Get the paths for the selected atlas
atlas_files = templates.(atlasType);

% Determine the correct base directory for atlas files
if strcmp(atlasType, 'adult')
    atlas_base_dir = fullfile(ap_histology_dir, 'allenAtlas');
else
    atlas_base_dir = fullfile(ap_histology_dir, 'devAtlas');
end

% Load the atlas files
tv = readNPY(fullfile(atlas_base_dir, atlas_files.template));
av = readNPY(fullfile(atlas_base_dir, atlas_files.annotation));
st = loadStructureTree(fullfile(atlas_base_dir, atlas_files.structure_tree));

disp(['✅ Using ', atlasType, ' atlas...']);


% Set up the GUI
screen_size_px = get(0, 'screensize');
gui_aspect_ratio = 1.5; % width/length
gui_width_fraction = 0.4; % fraction of screen width to occupy
gui_border = 50; % border from gui to screen edge
gui_width_px = screen_size_px(3) .* gui_width_fraction;
gui_height_px = gui_width_px / gui_aspect_ratio;
gui_position = [ ...
    gui_border, ... % left x
    screen_size_px(4) - (gui_height_px + gui_border + 50), ... % bottom y
    gui_width_px, gui_height_px]; % width, height

histology_toolbar_gui = figure('Toolbar', 'none', 'Menubar', 'none', 'color', 'w', ...
    'Name', ['AP Histology - ', atlasType], ...
    'Units', 'pixels', 'Position', gui_position);

% Set up the text to display coordinates
gui_data.atlasPaths = templates.(atlasType); % Store atlas paths in gui_data
gui_data.atlasType = atlasType; % Store the selected atlas type
gui_data.gui_text = annotation('textbox', 'String', '', 'interpreter', 'tex', ...
    'Units', 'normalized', 'Position', [0, 0, 1, 1], 'VerticalAlignment', 'top', ...
    'FontSize', 12, 'FontName', 'Consolas', 'PickableParts', 'none');

% File menu

gui_data.menu.file = uimenu(histology_toolbar_gui, 'Text', 'File selection');
uimenu(gui_data.menu.file, 'Text', 'Set raw image path', 'MenuSelectedFcn', {@set_image_path, histology_toolbar_gui});
uimenu(gui_data.menu.file, 'Text', 'Set processing save path', 'MenuSelectedFcn', {@set_save_path, histology_toolbar_gui});

% Preprocessing menu
gui_data.menu.preprocess = uimenu(histology_toolbar_gui, 'Text', 'Image preprocessing');
uimenu(gui_data.menu.preprocess, 'Text', 'Create slice images', 'MenuSelectedFcn', ...
    {@ap_histology.create_slice_images, histology_toolbar_gui});
%uimenu(gui_data.menu.preprocess, 'Text', 'Rotate & center slices', 'MenuSelectedFcn', ...
%    {@ap_histology.rotate_center_slices, histology_toolbar_gui});
%uimenu(gui_data.menu.preprocess, 'Text', 'Flip & re-order slices', 'MenuSelectedFcn', ...
%    {@ap_histology.flip_reorder_slices, histology_toolbar_gui});

% Atlas menu
gui_data.menu.atlas = uimenu(histology_toolbar_gui, 'Text', 'Atlas alignment');
uimenu(gui_data.menu.atlas, 'Text', 'Choose histology atlas slices', 'MenuSelectedFcn', ...
    {@ap_histology.match_histology_atlas, histology_toolbar_gui});
uimenu(gui_data.menu.atlas, 'Text', 'Auto-align histology/atlas slices', 'MenuSelectedFcn', ...
    {@ap_histology.align_auto_histology_atlas, histology_toolbar_gui});
uimenu(gui_data.menu.atlas, 'Text', 'Manual align histology/atlas slices', 'MenuSelectedFcn', ...
    {@ap_histology.align_manual_histology_atlas, histology_toolbar_gui});

% Annotation menu
gui_data.menu.annotation = uimenu(histology_toolbar_gui, 'Text', 'Annotation');
uimenu(gui_data.menu.annotation, 'Text', 'Neuropixels probes', 'MenuSelectedFcn', ...
    {@ap_histology.annotate_neuropixels, histology_toolbar_gui});

% View menu
gui_data.menu.view = uimenu(histology_toolbar_gui, 'Text', 'View');
uimenu(gui_data.menu.view, 'Text', 'View aligned histology', 'MenuSelectedFcn', ...
    {@ap_histology.view_aligned_histology, histology_toolbar_gui});

% Initialize GUI variables with default paths
gui_data.image_path = pwd; % Set default raw image path to current directory
gui_data.save_path = [pwd, filesep, 'OUT']; % Set default save path to current directory + 'OUT'

% Store guidata
guidata(histology_toolbar_gui, gui_data);

% Update GUI text to show current paths
ap_histology.update_toolbar_gui(histology_toolbar_gui);

end

function set_image_path(~, ~, histology_toolbar_gui)
% Function to manually set the image path

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Allow user to select a new image path
selected_path = uigetdir(gui_data.image_path, 'Select path with raw images');

% Update the path if the user made a selection
if selected_path ~= 0
    gui_data.image_path = selected_path;
end

% Store guidata
guidata(histology_toolbar_gui, gui_data);

% Update GUI text to show new path
ap_histology.update_toolbar_gui(histology_toolbar_gui);

end

function set_save_path(~, ~, histology_toolbar_gui)
% Function to manually set the save path

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Allow user to select a new save path
selected_path = uigetdir(gui_data.save_path, 'Select path to save processing');

% Update the path if the user made a selection
if selected_path ~= 0
    gui_data.save_path = selected_path;
end

% Store guidata
guidata(histology_toolbar_gui, gui_data);

% Update GUI text to show new path
ap_histology.update_toolbar_gui(histology_toolbar_gui);

end