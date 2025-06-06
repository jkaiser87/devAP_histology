function align_manual_histology_atlas(~, ~, histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Manually align histology slices and matched CCF slices

% Initialize guidata
gui_data = struct;

% Store toolbar handle
gui_data.histology_toolbar_gui = histology_toolbar_gui;

% Retrieve data from toolbar GUI
histology_toolbar_guidata = guidata(histology_toolbar_gui);
gui_data.save_path = histology_toolbar_guidata.save_path;

% Ensure atlasType is properly retrieved
if isfield(histology_toolbar_guidata, 'atlasType')
    atlasType = histology_toolbar_guidata.atlasType;
else
    warning('Defaulting to adult.');
    atlasType = 'adult'; % Fallback if missing
end
gui_data.atlasType = atlasType; % Store atlasType in gui_data

% Get list of TIFF files
slice_dir = dir(fullfile(gui_data.save_path, '*.tif'));
slice_fn = natsortfiles(cellfun(@(path, fn) fullfile(path, fn), ...
    {slice_dir.folder}, {slice_dir.name}, 'uni', false));

gui_data.slice_im = cell(length(slice_fn), 1);
for curr_slice = 1:length(slice_fn)
    gui_data.slice_im{curr_slice} = imread(slice_fn{curr_slice});
end

% Determine the correct filename for the CCF file based on atlasType
if strcmp(atlasType, 'adult')
    histology_ccf_filename = 'histology_ccf.mat';
else
    histology_ccf_filename = ['histology_', atlasType, 'ccf.mat'];
end
histology_ccf_path = fullfile(gui_data.save_path, histology_ccf_filename);

% Load the corresponding histology CCF file
if exist(histology_ccf_path, 'file')
    load(histology_ccf_path, 'histology_ccf');
    gui_data.histology_ccf = histology_ccf;
else
    error('Atlas file not found: %s', histology_ccf_path);
end

% Determine the correct filename for the automated alignment file based on atlasType
if strcmp(atlasType, 'adult')
    auto_alignment_filename = 'atlas2histology_tform.mat';
else
    auto_alignment_filename = ['atlas2histology_', atlasType, 'tform.mat'];
end

% Load automated alignment if available
auto_alignment_path = fullfile(gui_data.save_path, auto_alignment_filename);
if exist(auto_alignment_path, 'file')
    load(auto_alignment_path, 'atlas2histology_tform');
    gui_data.histology_ccf_auto_alignment = atlas2histology_tform;
end

% Create figure, set button functions
screen_size_px = get(0, 'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3) * gui_width_fraction;
gui_position = [(screen_size_px(3) - gui_width_px) / 2, ...
    (screen_size_px(4) - gui_width_px / gui_aspect_ratio) / 2, ...
    gui_width_px, gui_width_px / gui_aspect_ratio];

gui_fig = figure('KeyPressFcn', @keypress, ...
    'Toolbar', 'none', 'Menubar', 'none', 'color', 'w', ...
    'Units', 'pixels', 'Position', gui_position, ...
    'CloseRequestFcn', @close_gui);

gui_data.curr_slice = 1;

% Set up axis for histology image
gui_data.histology_ax = subplot(1, 2, 1, 'YDir', 'reverse');
set(gui_data.histology_ax, 'Position', [0, 0, 0.5, 0.9]);
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.slice_im{1}, ...
    'Parent', gui_data.histology_ax, 'ButtonDownFcn', @mouseclick_histology);

% Set up histology-aligned atlas overlay
histology_aligned_atlas_boundaries_init = ...
    zeros(size(gui_data.slice_im{1}, 1), size(gui_data.slice_im{1}, 2));
gui_data.histology_aligned_atlas_boundaries = ...
    imagesc(histology_aligned_atlas_boundaries_init, 'Parent', gui_data.histology_ax, ...
    'AlphaData', histology_aligned_atlas_boundaries_init, 'PickableParts', 'none');

% Set up axis for atlas slice
gui_data.atlas_ax = subplot(1, 2, 2, 'YDir', 'reverse');
set(gui_data.atlas_ax, 'Position', [0.5, 0, 0.5, 0.9]);
hold on; axis image off; colormap(gray); caxis([0, 400]);
gui_data.atlas_im_h = imagesc(gui_data.histology_ccf(1).tv_slices, ...
    'Parent', gui_data.atlas_ax, 'ButtonDownFcn', @mouseclick_atlas);

% Initialize alignment control points and tform matrices
gui_data.histology_control_points = repmat({zeros(0, 2)}, length(gui_data.slice_im), 1);
gui_data.atlas_control_points = repmat({zeros(0, 2)}, length(gui_data.slice_im), 1);

gui_data.histology_control_points_plot = plot(gui_data.histology_ax, nan, nan, '.w', 'MarkerSize', 20);
gui_data.atlas_control_points_plot = plot(gui_data.atlas_ax, nan, nan, '.r', 'MarkerSize', 20);

gui_data.histology_ccf_manual_alignment = gui_data.histology_ccf_auto_alignment;

% Upload gui data
guidata(gui_fig, gui_data);

% Initialize alignment
align_ccf_to_histology(gui_fig);

% Print controls
CreateStruct.Interpreter = 'tex';
CreateStruct.WindowStyle = 'non-modal';
msgbox( ...
    {'\fontsize{12}' ...
    '\bf Controls: \rm' ...
    'Left/right: switch slice' ...
    'click: set reference points for manual alignment (3 minimum)', ...
    'space: toggle alignment overlay visibility', ...
    'c: clear reference points', ...
    's: save'}, ...
    'Controls', CreateStruct);

end

function keypress(gui_fig, eventdata)
% Handle keypress events

% Get guidata
gui_data = guidata(gui_fig);

switch eventdata.Key
    case 'leftarrow'
        gui_data.curr_slice = max(gui_data.curr_slice - 1, 1);
        guidata(gui_fig, gui_data);
        update_slice(gui_fig);
        
    case 'rightarrow'
        gui_data.curr_slice = min(gui_data.curr_slice + 1, length(gui_data.slice_im));
        guidata(gui_fig, gui_data);
        update_slice(gui_fig);
        
    case 'space'
        curr_visibility = get(gui_data.histology_aligned_atlas_boundaries, 'Visible');
        set(gui_data.histology_aligned_atlas_boundaries, 'Visible', ...
            cell2mat(setdiff({'on', 'off'}, curr_visibility)));
        
    case 'c'
        gui_data.histology_control_points{gui_data.curr_slice} = zeros(0, 2);
        gui_data.atlas_control_points{gui_data.curr_slice} = zeros(0, 2);
        guidata(gui_fig, gui_data);
        update_slice(gui_fig);
        
    case 's'
        atlas2histology_tform = gui_data.histology_ccf_manual_alignment;
        % Generate filename based on atlasType
        if strcmp(gui_data.atlasType, 'adult')
            save_filename = 'atlas2histology_tform.mat';
        else
            save_filename = ['atlas2histology_', gui_data.atlasType, 'tform.mat'];
        end
        save_fn = fullfile(gui_data.save_path, save_filename);

        save(save_fn, 'atlas2histology_tform');
        disp(['Saved.']);
end

end

function mouseclick_histology(gui_fig, eventdata)
% Draw new point for alignment

% Get guidata
gui_data = guidata(gui_fig);

% Add clicked location to control points
gui_data.histology_control_points{gui_data.curr_slice} = ...
    vertcat(gui_data.histology_control_points{gui_data.curr_slice}, ...
    eventdata.IntersectionPoint(1:2));

set(gui_data.histology_control_points_plot, ...
    'XData', gui_data.histology_control_points{gui_data.curr_slice}(:, 1), ...
    'YData', gui_data.histology_control_points{gui_data.curr_slice}(:, 2));

% Upload gui data
guidata(gui_fig, gui_data);

% If equal number of histology/atlas control points > 3, draw boundaries
if size(gui_data.histology_control_points{gui_data.curr_slice}, 1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) || ...
        (size(gui_data.histology_control_points{gui_data.curr_slice}, 1) > 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) > 3)
    align_ccf_to_histology(gui_fig);
end

end

function mouseclick_atlas(gui_fig, eventdata)
% Draw new point for alignment

% Get guidata
gui_data = guidata(gui_fig);

% Add clicked location to control points
gui_data.atlas_control_points{gui_data.curr_slice} = ...
    vertcat(gui_data.atlas_control_points{gui_data.curr_slice}, ...
    eventdata.IntersectionPoint(1:2));

set(gui_data.atlas_control_points_plot, ...
    'XData', gui_data.atlas_control_points{gui_data.curr_slice}(:, 1), ...
    'YData', gui_data.atlas_control_points{gui_data.curr_slice}(:, 2));

% Upload gui data
guidata(gui_fig, gui_data);

% If equal number of histology/atlas control points > 3, draw boundaries
if size(gui_data.histology_control_points{gui_data.curr_slice}, 1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) || ...
        (size(gui_data.histology_control_points{gui_data.curr_slice}, 1) > 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) > 3)
    align_ccf_to_histology(gui_fig);
end

end

function align_ccf_to_histology(gui_fig)
% Align CCF atlas to histology slices based on control points

% Get guidata
gui_data = guidata(gui_fig);

if size(gui_data.histology_control_points{gui_data.curr_slice}, 1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) && ...
        (size(gui_data.histology_control_points{gui_data.curr_slice}, 1) >= 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) >= 3)
    % If same number of >= 3 control points, use control point alignment
    tform = fitgeotrans(gui_data.atlas_control_points{gui_data.curr_slice}, ...
        gui_data.histology_control_points{gui_data.curr_slice}, 'affine');
    title(gui_data.histology_ax, 'New alignment');
    
elseif size(gui_data.histology_control_points{gui_data.curr_slice}, 1) >= 1 || ...
        size(gui_data.atlas_control_points{gui_data.curr_slice}, 1) >= 1
    % If less than 3 or nonmatching points, use auto but don't draw
    title(gui_data.histology_ax, 'New alignment');
    
    % Upload gui data
    guidata(gui_fig, gui_data);
    return
    
else
    % If no points, use automated outline
    if isfield(gui_data, 'histology_ccf_auto_alignment')
        tform = affine2d;
        tform.T = gui_data.histology_ccf_auto_alignment{gui_data.curr_slice};
        title(gui_data.histology_ax, 'Previous alignment');
    end
end

curr_av_slice = gui_data.histology_ccf(gui_data.curr_slice).av_slices;
curr_av_slice(isnan(curr_av_slice)) = 1;
curr_slice_im = gui_data.slice_im{gui_data.curr_slice};

tform_size = imref2d([size(curr_slice_im, 1), size(curr_slice_im, 2)]);
curr_av_slice_warp = imwarp(curr_av_slice, tform, 'OutputView', tform_size);

av_warp_boundaries = round(conv2(curr_av_slice_warp, ones(3) ./ 9, 'same')) ~= curr_av_slice_warp;

% New code to dilate the boundaries
se = strel('disk', 2); % Structuring element for dilation
av_warp_boundaries_dilated = imdilate(av_warp_boundaries, se); % Dilated boundaries

set(gui_data.histology_aligned_atlas_boundaries, ...
    'CData', av_warp_boundaries_dilated, ... % Use dilated boundaries
    'AlphaData', av_warp_boundaries_dilated * 0.5);

% Update transform matrix
gui_data.histology_ccf_manual_alignment{gui_data.curr_slice} = tform.T;

% Upload gui data
guidata(gui_fig, gui_data);

end

function update_slice(gui_fig)
% Draw histology and CCF slice

% Get guidata
gui_data = guidata(gui_fig);

% Set next histology slice
set(gui_data.histology_im_h, 'CData', gui_data.slice_im{gui_data.curr_slice});
set(gui_data.atlas_im_h, 'CData', gui_data.histology_ccf(gui_data.curr_slice).tv_slices);

% Plot control points for slice
set(gui_data.histology_control_points_plot, ...
    'XData', gui_data.histology_control_points{gui_data.curr_slice}(:, 1), ...
    'YData', gui_data.histology_control_points{gui_data.curr_slice}(:, 2));
set(gui_data.atlas_control_points_plot, ...
    'XData', gui_data.atlas_control_points{gui_data.curr_slice}(:, 1), ...
    'YData', gui_data.atlas_control_points{gui_data.curr_slice}(:, 2));

% Reset histology-aligned atlas boundaries if not
histology_aligned_atlas_boundaries_init = ...
    zeros(size(gui_data.slice_im{1}, 1), size(gui_data.slice_im{1}, 2));
set(gui_data.histology_aligned_atlas_boundaries, ...
    'CData', histology_aligned_atlas_boundaries_init, ...
    'AlphaData', histology_aligned_atlas_boundaries_init);

% Upload gui data
guidata(gui_fig, gui_data);

% Update atlas boundaries
align_ccf_to_histology(gui_fig);

end

function close_gui(gui_fig, ~)
% Close GUI function

% Get guidata
gui_data = guidata(gui_fig);

% Generate filename based on atlasType
if strcmp(gui_data.atlasType, 'adult')
    save_filename = 'atlas2histology_tform.mat';
else
    save_filename = ['atlas2histology_', gui_data.atlasType, 'tform.mat'];
end
save_fn = fullfile(gui_data.save_path, save_filename);

% Ask user if they want to save before closing
opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?', 'Confirm exit', opts);

switch user_confirm
    case 'Yes'
        % Save alignment data
        atlas2histology_tform = gui_data.histology_ccf_manual_alignment;
        save(save_fn, 'atlas2histology_tform');
        disp(['Saved final alignment to: ', save_fn]);
        delete(gui_fig);

    case 'No'
        % Close without saving
        delete(gui_fig);

    case 'Cancel'
        % Do nothing
end

% Update toolbar GUI
ap_histology.update_toolbar_gui(gui_data.histology_toolbar_gui);

end