function align_auto_histology_atlas(~, ~, histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Auto aligns histology slices and matched CCF slices by outline registration

% Retrieve data from toolbar GUI
histology_toolbar_guidata = guidata(histology_toolbar_gui);
save_path = histology_toolbar_guidata.save_path;

% Ensure atlasType is properly retrieved
if isfield(histology_toolbar_guidata, 'atlasType')
    atlasType = histology_toolbar_guidata.atlasType;
else
    warning('atlasType not found! Defaulting to adult.');
    atlasType = 'adult'; % Fallback if missing
end

% Get list of TIFF files
slice_dir = dir(fullfile(save_path, '*.tif'));
slice_fn = natsortfiles(cellfun(@(path, fn) fullfile(path, fn), ...
    {slice_dir.folder}, {slice_dir.name}, 'uni', false));

slice_im = cell(length(slice_fn), 1);
for curr_slice = 1:length(slice_fn)
    slice_im{curr_slice} = imread(slice_fn{curr_slice});
end

% Determine the correct filename for the CCF file based on atlasType
if strcmp(atlasType, 'adult')
    histology_ccf_filename = 'histology_ccf.mat';
else
    histology_ccf_filename = ['histology_', atlasType, 'ccf.mat'];
end
histology_ccf_path = fullfile(save_path, histology_ccf_filename);

% Load the corresponding histology CCF file
if exist(histology_ccf_path, 'file')
    load(histology_ccf_path, 'histology_ccf');
    disp(['✅ Loaded atlas: ', histology_ccf_path]);
else
    error('❌ Atlas file not found: %s', histology_ccf_path);
end

% Binarize slices (only necessary if aligning outlines)
slice_im_flat = cellfun(@(x) max(x, [], 3), slice_im, 'uni', false);
slice_thresh = graythresh(cell2mat(cellfun(@(x) reshape(x(x ~= 0), [], 1), slice_im_flat, 'UniformOutput', false)));
slice_thresh_adjust = slice_thresh + (1 - slice_thresh) * 0.8;
slice_im_binary = cellfun(@(x) imbinarize(x, slice_thresh_adjust), slice_im_flat, 'uni', false);

% (flip sign if brightfield)
brightfield_flag = mode(round(cell2mat(cellfun(@(x) ...
    reshape(x, [], 1), slice_im_flat, 'uni', false)))) > 100;
if brightfield_flag
    slice_im_binary = cellfun(@not, slice_im_binary, 'uni', false);
end

% Align outlines of histology/atlas slices
atlas_align_borders = cell(size(slice_im));
atlas2histology_tform = cell(size(slice_im));

waitbar_h = waitbar(0, 'Aligning atlas/histology slices...');
for curr_slice = 1:length(slice_im)

    % To align anatomy:
    curr_histology_slice = slice_im_flat{curr_slice};
    curr_atlas_slice = histology_ccf(curr_slice).tv_slices;
    curr_atlas_slice(isnan(curr_atlas_slice)) = 0;
    [optimizer, metric] = imregconfig('multimodal');
    optimizer.MaximumIterations = 200;
    optimizer.GrowthFactor = 1 + 1e-3;
    optimizer.InitialRadius = 1e-3;

    % Resize atlas outline to approximately match histology, affine-align
    resize_factor = min(size(curr_histology_slice) ./ size(curr_atlas_slice));
    curr_atlas_slice_resize = imresize(curr_atlas_slice, resize_factor, 'nearest');

    % Do alignment on downsampled silhouettes (faster and more accurate)
    downsample_factor = 5;

    tformEstimate_affine_resized = ...
        imregtform( ...
        imresize(curr_atlas_slice_resize, 1 / downsample_factor, 'nearest'), ...
        imresize(curr_histology_slice, 1 / downsample_factor, 'nearest'), ...
        'affine', optimizer, metric, 'PyramidLevels', 3);

    % Set final transform (scale to histology, downscale, affine, upscale)
    scale_match = eye(3) .* [repmat(resize_factor, 2, 1); 1];
    scale_align_down = eye(3) .* [repmat(1 / downsample_factor, 2, 1); 1];
    scale_align_up = eye(3) .* [repmat(downsample_factor, 2, 1); 1];

    tformEstimate_affine = tformEstimate_affine_resized;
    tformEstimate_affine.T = scale_match * scale_align_down * ...
        tformEstimate_affine_resized.T * scale_align_up;

    % Store the affine matrix and plot the transform
    atlas2histology_tform{curr_slice} = tformEstimate_affine.T;

    % Get aligned atlas areas
    curr_av_aligned = imwarp(histology_ccf(curr_slice).av_slices, tformEstimate_affine, 'nearest', ...
        'OutputView', imref2d(size(curr_histology_slice)));
    atlas_align_borders{curr_slice} = ...
        round(conv2(curr_av_aligned, ones(3) ./ 9, 'same')) ~= curr_av_aligned;

    waitbar(curr_slice / length(slice_im), waitbar_h, ...
        sprintf('Aligning atlas/histology slices: %d/%d', ...
        curr_slice, length(slice_im)));

end

close(waitbar_h);

% Montage overlay
screen_size_px = get(0, 'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3) .* gui_width_fraction;
gui_position = [...
    (screen_size_px(3) - gui_width_px) / 2, ... % left x
    (screen_size_px(4) - gui_width_px / gui_aspect_ratio) / 2, ... % bottom y
    gui_width_px, gui_width_px / gui_aspect_ratio]; % width, height
align_fig = figure('color', 'w', 'Position', gui_position);

% (images)
montage(slice_im); hold on;
% (aligned atlas areas)
aligned_atlas_montage = montage(atlas_align_borders);
aligned_atlas_montage.AlphaData = aligned_atlas_montage.CData > 0;
aligned_atlas_montage.CData = aligned_atlas_montage.CData .* permute([1; 0; 0], [2, 3, 1]);

% Prompt for save
opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?', 'Confirm exit', 'Yes', 'No', opts);
switch user_confirm
    case 'Yes'
        % Generate filename based on atlasType
        if strcmp(atlasType, 'adult')
            save_filename = 'atlas2histology_tform.mat';
        else
            save_filename = ['atlas2histology_', atlasType, 'tform.mat'];
        end
        save_fn = fullfile(save_path, save_filename);

        % Save alignment data
        save(save_fn, 'atlas2histology_tform');
        disp(['Saved alignments: ', save_fn]);
        close(align_fig);

    case 'No'
        % Close without saving
        close(align_fig);
end

% Update toolbar GUI
ap_histology.update_toolbar_gui(histology_toolbar_gui);

end