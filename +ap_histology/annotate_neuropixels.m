function annotate_neuropixels(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Annotate Neuropixels tracts on slices and get CCF positions/regions

% Initialize guidata
gui_data = struct;

% Store toolbar handle
gui_data.histology_toolbar_gui = histology_toolbar_gui;

% Load atlas
allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('No CCF atlas found (add CCF atlas to path)')
end
disp('Loading Allen CCF atlas...')
gui_data.tv = readNPY(fullfile(allen_atlas_path,'template_volume_10um.npy'));
gui_data.av = readNPY(fullfile(allen_atlas_path,'annotation_volume_10um_by_index.npy'));
gui_data.st = ap_histology.loadStructureTree(fullfile(allen_atlas_path,'structure_tree_safe_2017.csv'));
disp('Done.')

% Get images (from path in toolbar GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);
gui_data.save_path = histology_toolbar_guidata.save_path;

slice_dir = dir(fullfile(gui_data.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

gui_data.slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
    gui_data.slice_im{curr_slice} = imread(slice_fn{curr_slice});
end

% Load corresponding CCF slices
ccf_slice_fn = fullfile(gui_data.save_path,'histology_ccf.mat');
load(ccf_slice_fn);
gui_data.histology_ccf = histology_ccf;

% Load histology/CCF alignment
ccf_alignment_fn = fullfile(gui_data.save_path,'atlas2histology_tform.mat');
load(ccf_alignment_fn);
gui_data.histology_ccf_alignment = atlas2histology_tform;

% Warp area labels by histology alignment
gui_data.histology_aligned_av_slices = cell(length(gui_data.slice_im),1);
for curr_slice = 1:length(gui_data.slice_im)
    curr_av_slice = gui_data.histology_ccf(curr_slice).av_slices;
    curr_av_slice(isnan(curr_av_slice)) = 1;
    curr_slice_im = gui_data.slice_im{curr_slice};

    tform = affine2d;
    tform.T = gui_data.histology_ccf_alignment{curr_slice};
    tform_size = imref2d([size(curr_slice_im,1),size(curr_slice_im,2)]);
    gui_data.histology_aligned_av_slices{curr_slice} = ...
        imwarp(curr_av_slice,tform,'nearest','OutputView',tform_size);
end

% Create figure, set button functions
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

gui_fig = figure('KeyPressFcn',@keypress, ...
    'Toolbar','none','Menubar','none','color','w', ...
    'Units','pixels','Position',gui_position, ...
    'CloseRequestFcn',@close_gui);
gui_data.curr_slice = 1;

% Set up axis for histology image
gui_data.histology_ax = axes('YDir','reverse');
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.slice_im{1}, ...
    'Parent',gui_data.histology_ax);

% Create title to write area in
gui_data.histology_ax_title = title(gui_data.histology_ax,'','FontSize',14);

% Initialize probe points
lines_colormap = lines(7);
probe_colormap = [lines_colormap;lines_colormap(:,[2,3,1]);lines_colormap(:,[3,1,2])];

gui_data.probe_color = probe_colormap;
gui_data.probe_points_histology = cell(length(gui_data.slice_im),1);
gui_data.probe_lines = gobjects(1);

% Upload gui data
guidata(gui_fig,gui_data);

% Update the slice
update_slice(gui_fig);

end

function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

switch eventdata.Key

    % left/right: move slice
    case 'leftarrow'
        gui_data.curr_slice = max(gui_data.curr_slice - 1,1);
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);

    case 'rightarrow'
        gui_data.curr_slice = ...
            min(gui_data.curr_slice + 1,length(gui_data.slice_im));
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);

        % Number: add coordinates for the numbered probe
    case [cellfun(@num2str,num2cell(0:9),'uni',false),cellfun(@(x) ['numpad' num2str(x)],num2cell(1:9),'uni',false)]

        curr_probe = str2num(eventdata.Key(end));

        % 0 key: probe 10
        if curr_probe == 0
            curr_probe = 10;
        end

        % Shift key: +10
        if any(strcmp(eventdata.Modifier,'shift'))
            curr_probe = curr_probe + 10;
        end

        set(gui_data.histology_ax_title,'String',['Draw probe ' num2str(curr_probe)]);
        curr_line = imline;
        % If the line is just a click, don't include
        curr_line_length = sqrt(sum(abs(diff(curr_line.getPosition,[],1)).^2));
        if curr_line_length == 0
            return
        end
        gui_data.probe_points_histology{gui_data.curr_slice,curr_probe} = ...
            curr_line.getPosition;
        set(gui_data.histology_ax_title,'String', ...
            {'Arrows: change slice','Number (shift, +10): draw probe X '});

        % Delete movable line, draw line object
        curr_line.delete;
        gui_data.probe_lines(curr_probe) = ...
            line(gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,1), ...
            gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,2), ...
            'linewidth',3,'color',gui_data.probe_color(curr_probe,:));

        % Upload gui data
        guidata(gui_fig,gui_data);

end

end


function update_slice(gui_fig)
% Draw histology and CCF slice

% Get guidata
gui_data = guidata(gui_fig);

% Set next histology slice
set(gui_data.histology_im_h,'CData',gui_data.slice_im{gui_data.curr_slice})

% Clear any current lines, draw probe lines
gui_data.probe_lines.delete;
for curr_probe = find(~cellfun(@isempty,gui_data.probe_points_histology(gui_data.curr_slice,:)))
    gui_data.probe_lines(curr_probe) = ...
        line(gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,1), ...
        gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,2), ...
        'linewidth',3,'color',gui_data.probe_color(curr_probe,:));
end

set(gui_data.histology_ax_title,'String', ...
            {'Arrows: change slice','Number (shift, +10): draw probe X '});

% Upload gui data
guidata(gui_fig, gui_data);

end

function plot_probe(gui_data,probe_ccf)

% Plot probe trajectories
figure('Name','Probe trajectories');
axes_atlas = axes;
[~, brain_outline] = plotBrainGrid([],axes_atlas);
set(axes_atlas,'ZDir','reverse');
hold(axes_atlas,'on');
axis vis3d equal off manual
view([-30,25]);
caxis([0 300]);
[ap_max,dv_max,ml_max] = size(gui_data.tv);
xlim([-10,ap_max+10])
ylim([-10,ml_max+10])
zlim([-10,dv_max+10])
h = rotate3d(gca);
h.Enable = 'on';

for curr_probe = 1:length(probe_ccf)
    % Plot points and line of best fit
    r0 = mean(probe_ccf(curr_probe).points,1);
    xyz = bsxfun(@minus,probe_ccf(curr_probe).points,r0);
    [~,~,V] = svd(xyz,0);
    histology_probe_direction = V(:,1);
    % (make sure the direction goes down in DV - flip if it's going up)
    if histology_probe_direction(2) < 0
        histology_probe_direction = -histology_probe_direction;
    end

    line_eval = [-1000,1000];
    probe_fit_line = bsxfun(@plus,bsxfun(@times,line_eval',histology_probe_direction'),r0);
    plot3(probe_ccf(curr_probe).points(:,1), ...
        probe_ccf(curr_probe).points(:,3), ...
        probe_ccf(curr_probe).points(:,2), ...
        '.','color',gui_data.probe_color(curr_probe,:),'MarkerSize',20);
    line(probe_fit_line(:,1),probe_fit_line(:,3),probe_fit_line(:,2), ...
        'color',gui_data.probe_color(curr_probe,:),'linewidth',2)
end

% Plot probe areas
figure('Name','Trajectory areas');
for curr_probe = 1:length(probe_ccf)

    curr_axes = subplot(1,length(probe_ccf),curr_probe);

    trajectory_areas_rgb = permute(cell2mat(cellfun(@(x) hex2dec({x(1:2),x(3:4),x(5:6)})'./255, ...
        probe_ccf(curr_probe).trajectory_areas.color_hex_triplet,'uni',false)),[1,3,2]);

    trajectory_areas_boundaries = probe_ccf(curr_probe).trajectory_areas.trajectory_depth;
    trajectory_areas_centers = mean(trajectory_areas_boundaries,2);

    trajectory_areas_image_depth = 0:0.01:max(trajectory_areas_boundaries,[],'all');
    trajectory_areas_image_idx = interp1(trajectory_areas_boundaries(:,1), ...
        1:height(probe_ccf(curr_probe).trajectory_areas),trajectory_areas_image_depth, ...
        'previous','extrap');
    trajectory_areas_image = trajectory_areas_rgb(trajectory_areas_image_idx,:,:);

    image([],trajectory_areas_image_depth,trajectory_areas_image);
    yline(unique(trajectory_areas_boundaries(:)),'color','k','linewidth',1);
    set(curr_axes,'XTick',[],'YTick',trajectory_areas_centers, ...
        'YTickLabels',probe_ccf(curr_probe).trajectory_areas.acronym);
    set(curr_axes,'XTick',[]);
    title(['Probe ' num2str(curr_probe)]);

end

end


function close_gui(gui_fig,~)

% Get guidata
gui_data = guidata(gui_fig);

opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?','Confirm exit',opts);
switch user_confirm
    case 'Yes'
        % Save and close

        % Get number of probes
        n_probes = size(gui_data.probe_points_histology,2);

        % Initialize structure to save
        probe_ccf = struct( ...
            'points',cell(n_probes,1), ...
            'trajectory_areas',cell(n_probes,1));

        % Convert probe points to CCF points by alignment and save
        for curr_probe = 1:n_probes
            for curr_slice = find(~cellfun(@isempty,gui_data.probe_points_histology(:,curr_probe)'))

                % Transform histology to atlas slice
                tform = affine2d;
                tform.T = gui_data.histology_ccf_alignment{curr_slice};
                % (transform is CCF -> histology, invert for other direction)
                tform = invert(tform);

                % Transform and round to nearest index
                [probe_points_atlas_x,probe_points_atlas_y] = ...
                    transformPointsForward(tform, ...
                    gui_data.probe_points_histology{curr_slice,curr_probe}(:,1), ...
                    gui_data.probe_points_histology{curr_slice,curr_probe}(:,2));

                probe_points_atlas_x = round(probe_points_atlas_x);
                probe_points_atlas_y = round(probe_points_atlas_y);

                % Get CCF coordinates corresponding to atlas slice points
                % (CCF coordinates are in [AP,DV,ML])
                use_points = find(~isnan(probe_points_atlas_x) & ~isnan(probe_points_atlas_y));
                for curr_point = 1:length(use_points)
                    ccf_ap = gui_data.histology_ccf(curr_slice). ...
                        plane_ap(probe_points_atlas_y(curr_point), ...
                        probe_points_atlas_x(curr_point));
                    ccf_ml = gui_data.histology_ccf(curr_slice). ...
                        plane_ml(probe_points_atlas_y(curr_point), ...
                        probe_points_atlas_x(curr_point));
                    ccf_dv = gui_data.histology_ccf(curr_slice). ...
                        plane_dv(probe_points_atlas_y(curr_point), ...
                        probe_points_atlas_x(curr_point));
                    probe_ccf(curr_probe).points = ...
                        vertcat(probe_ccf(curr_probe).points,[ccf_ap,ccf_dv,ccf_ml]);
                end
            end

            % Sort probe points by DV (probe always top->bottom)
            [~,dv_sort_idx] = sort(probe_ccf(curr_probe).points(:,2));
            probe_ccf(curr_probe).points = probe_ccf(curr_probe).points(dv_sort_idx,:);

        end

        % Get areas along probe trajectory
        for curr_probe = 1:n_probes

            % Get best fit line through points as probe trajectory
            r0 = mean(probe_ccf(curr_probe).points,1);
            xyz = bsxfun(@minus,probe_ccf(curr_probe).points,r0);
            [~,~,V] = svd(xyz,0);
            histology_probe_direction = V(:,1);
            % (make sure the direction goes down in DV - flip if it's going up)
            if histology_probe_direction(2) < 0
                histology_probe_direction = -histology_probe_direction;
            end

            line_eval = [-1000,1000];
            probe_fit_line = bsxfun(@plus,bsxfun(@times,line_eval',histology_probe_direction'),r0)';

            % Sample the CCF every micron along the trajectory
            trajectory_n_coords = norm(diff(probe_fit_line,[],2))*10; % (convert 10um to 1um)
            [trajectory_ap_ccf,trajectory_dv_ccf,trajectory_ml_ccf] = deal( ...
                round(linspace(probe_fit_line(1,1),probe_fit_line(1,2),trajectory_n_coords)), ...
                round(linspace(probe_fit_line(2,1),probe_fit_line(2,2),trajectory_n_coords)), ...
                round(linspace(probe_fit_line(3,1),probe_fit_line(3,2),trajectory_n_coords)));

            trajectory_coords_outofbounds = ...
                any([trajectory_ap_ccf;trajectory_dv_ccf;trajectory_ml_ccf] < 1,1) | ...
                any([trajectory_ap_ccf;trajectory_dv_ccf;trajectory_ml_ccf] > size(gui_data.av)',1);

            trajectory_coords_sample = ...
                [trajectory_ap_ccf(~trajectory_coords_outofbounds)' ...
                trajectory_dv_ccf(~trajectory_coords_outofbounds)', ...
                trajectory_ml_ccf(~trajectory_coords_outofbounds)'];

            trajectory_idx_sample = sub2ind(size(gui_data.av), ...
                trajectory_coords_sample(:,1), ...
                trajectory_coords_sample(:,2), ...
                trajectory_coords_sample(:,3));

            trajectory_area_idx_sampled = gui_data.av(trajectory_idx_sample);
            trajectory_area_bins = [1;(find(diff(double(trajectory_area_idx_sampled))~= 0)+1);length(trajectory_idx_sample)];
            trajectory_area_boundaries = [trajectory_area_bins(1:end-1),trajectory_area_bins(2:end)];

            trajectory_area_idx = trajectory_area_idx_sampled(trajectory_area_boundaries(:,1));
            store_areas_idx = trajectory_area_idx > 1; % only use areas in brain (idx > 1)

            % Store row from structure tree and depths for each area
            % (normalize depth to first brain boundary)
            trajectory_areas = gui_data.st(trajectory_area_idx(store_areas_idx),:);
            trajectory_areas.trajectory_depth = (trajectory_area_boundaries(store_areas_idx,:) - ...
                trajectory_area_boundaries(find(store_areas_idx,1),1));

            % Store CCF coordinates for trajectory beginning/end
            trajectory_coords = trajectory_coords_sample( ...
                [trajectory_area_boundaries(find(store_areas_idx,1,'first'),1)
                trajectory_area_boundaries(find(store_areas_idx,1,'last'),end)],:);

            % Package
            probe_ccf(curr_probe).trajectory_areas = trajectory_areas;
            probe_ccf(curr_probe).trajectory_coords = trajectory_coords;

        end

        % Save probe CCF points
        save_fn = fullfile(gui_data.save_path,'probe_ccf.mat');
        save(save_fn,'probe_ccf');
        disp(['Saved probe locations in ' save_fn])

        % Close GUI
        delete(gui_fig)

        % Plot probe trajectories
        plot_probe(gui_data,probe_ccf);

    case 'No'
        % Close without saving
        delete(gui_fig);

    case 'Cancel'
        % Do nothing

end

% Update toolbar GUI
ap_histology.update_toolbar_gui(gui_data.histology_toolbar_gui);

end












