function [] = run_FShift_StimDriven(sub,flag_training, flag_isolum, flag_block)
% run_FShift_StimDriven(sub,flag_training, flag_isolum, flag_block)
%   runs experiment SSVEP_FShift_StimDriven
%       sub:            participant number
%       flag_training:  1 = do training
%       flag_isolum:    1 = do isoluminance adjustment
%       flag_block:     1 = start with block 1
%           e.g. run_FShift_StimDriven(1,1, 0, 1)
% 
% current version includes two irrelevant colors in periphery
% swapped back to one irrelevant color in periphery
%
% to do:
% - isntruction for both task
% - switch for training specifying the task to do
% - behavioral readout



% Christopher Gundlach, Maria Dotzer, Jonas Jänig  Leipzig, 2026,2023,2021, 2020

if nargin < 4
    help run_FShift_PerIrr
    return
end

%% parameters
% sub = 1; flag_training = 1; flag_block = 1; flag_isolum = 1;
% design
p.sub                   = sub;                  % subject number
p.flag_block            = flag_block;           % block number to start
p.flag_training         = flag_training;        % do training

p.ITI                   = [1000 1000];          % inter trial interval in ms
p.targ_respwin          = [200 1000];           % time window for responses in ms

% screen
p.scr_num               = 1;                    % screen number
p.scr_res               = [1920 1080];          % resolution
p.scr_refrate           = 480;                  % refresh rate in Hz (e.g. 85)
p.scr_color             = [0.05 0.05 0.05 1];      % default: [0.05 0.05 0.05 1]; ; color of screen [R G B Alpha]
p.scr_imgmultipl        = 4;

% some isoluminace parameters
p.isol.TrlAdj           = 5;                    % number of trials used for isoluminance adjustment
p.isol.MaxStd           = 10;                   % standard deviation tolerated
p.isol.run              = false;                % isoluminance run?
% p.isol.override         = [];                   % manually set colors for RDK1 to RDKXs e.g. []
p.isol.override         = [0.0980 0.0392 0 1; 0 0.0745 0 1;  0 0.0596 0.1490 1]; % these are the ones used for p.isol.bckgr = p.scr_color(1:3);

% p.isol.bckgr            = p.scr_color(1:3)+0.2;          % isoluminant to background or different color?
p.isol.bckgr            = p.scr_color;          % isoluminant to background or different color?
p.isol.init_cols        = p.isol.override;


% stimplan
p.stim.center_col       = [1 2; 1 3; 2 1; 2 3; 3 1; 3 2]; % defines which colors are shown in center [for first half and second half]
                            % red -> green; red -> blue; green -> red; green -> blue; blue -> red; blue -> green
                            % RDK color is randomized later on
p.stim.RDKperi_col      =  [1 2 ... % defines which RDKcolors are shown in the periphery [red green blue by left right];
                            ];
p.stim.task             = [1 2]; % 1 = RDK task; 2 = rectangle task
p.stim.condition        = [1:size(p.stim.center_col,1)*size(p.stim.RDKperi_col,1)*numel(p.stim.task )];    
                        % main experimental conditions: 
                        %   TASK/ATTENTION [RDK task; rectangle task]
                        %   COLORCHANGE [c1 -> c2; c1 -> c3; c2 -> c1; c2 -> c3; c3 -> c1; c3 -> c2]
p.stim.eventnum_e       = [0 0 0 0 1 2 3 4];        % ratio of eventnumbers for experiment
p.stim.eventnum_t       = [0 0 1 2 3 4];        % ratio of eventnumbers for training
p.stim.con_repeats      = [8];  % trial number/repeats for each eventnum and condition
p.stim.con_repeats_t    = [2];              % trial number/repeats for each eventnum and condition
p.stim.triallength      = [4.8];
p.stim.time_prechange   = [1.8 3];          % precue time in s; [upper lower] for randomization
p.stim.event.type       = 1;                % types of events (1 = targets only, 2 = targets + distrators)
p.stim.event.length     = 0.3;              % lengt of events in s
p.stim.event.min_onset  = 0.4;              % min post-cue time before event onset in s
p.stim.event.min_offset = 0;                % min offset from target end to end of trial in s
p.stim.event.min_dist   = 0.8;              % min time between events in s
p.stim.blocknum         = 24;               % number of blocks
p.stim.ITI              = [1 1];            % ITI range in seconds

% event parameter for rectangle modulations
p.stim.event.rect_mod       = {[1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1];
                                [1 0 1 0; 0 1 0 1]};   % which synchronous changes [top right bottom left] are to be discriminated {class 1; class 2}
p.stim.event.rect_modsize   = [50];                  % size of rectangle modulations in pixels
p.stim.event.rect_moddur    = p.stim.event.length;   % duration of event length

% event parameter for RDK modulations
p.stim.event.RDK_movdir     = {[1 0 0 0; 0 1 0 0];
                                [0 0 1 0; 0 0 0 1]};   % which directions are to be discriminated; according to RDK.RDK(1).mov_dir below [up down vs left right]{class 1; class 2}

% introduce RDK structure
RDK.RDK(1).size         = [154 308];                    % width and height of RDK in pixel; only even values [38 = 9.6°]
RDK.RDK(1).centershift  = [0 0];                        % position of RDK center; x and y deviation from center in pixel
RDK.RDK(1).col          = [0.3 0.3 0.3 1; p.scr_color(1:3) 0];% "on" and "off" color
RDK.RDK(1).freq         = 0;                            % flicker frequency, frequency of a full "on"-"off"-cycle
RDK.RDK(1).mov_freq     = 120;                          % Defines how frequently the dot position is updated; 0 will adjust the update-frequency to your flicker frequency (i.e. dot position will be updated with every "on"-and every "off"-frame); 120 will update the position for every frame for 120Hz or for every 1. quadrant for 480Hz 
RDK.RDK(1).num          = 85;                           % number of dots % 85
RDK.RDK(1).mov_speed    = 1;                            % movement speed in pixel
RDK.RDK(1).mov_dir      = [0 1; 0 -1; -1 0; 1 0];       % movement direction  [0 1; 0 -1; -1 0; 1 0] = up, down, left, right
RDK.RDK(1).dot_size     = 10;                           % size of dots
RDK.RDK(1).shape        = 1;                            % 1 = square RDK; 0 = ellipse/circle RDK;

p.stim.pos_shift        = [-310 0; 310 0];              % position shift in pixel for stimuli in periphery [255 = 7.8°; 310 = 9.8°] either left or right
p.stim.freqs            = {[23];[17 20]};               % frequencies of {[center1];[peri1 peri2]}
% p.stim.colors           = ...                           % "on" and "off" color
%     {[1 0.4 0 1; p.scr_color(1:3) 1];...
%     [0 0.4 1 1; p.scr_color(1:3) 1];...
%     [0 1 0 1; p.scr_color(1:3) 1]; ...
%     [1 0 1 1; p.scr_color(1:3) 1]};

p.stim.colors           = ...                           % "on" and "off" color
    {[1 0.4 0 1; p.scr_color(1:3) 0];...
    [0 1 0 1; p.scr_color(1:3) 0];...
    [0 0.4 1 1; p.scr_color(1:3) 0]};
    % plot_colorwheel([1 0.4 0; 0 0.4 1; 0 1 0; 1 0 1],'ColorSpace','propixxrgb','LAB_L',50,'NumSegments',60,'AlphaColWheel',1,'LumBackground',100)
p.stim.color_names      = {'red';'green';'blue'};
 
RDK.event.type          = 'globalmotion';       % event type global motion
RDK.event.duration      = p.stim.event.length;  % time of coherent motion
RDK.event.coherence     = .4;                   % percentage of coherently moving dots 0.4 [changed from 0.4 to 0.3 to 0.4]
RDK.event.direction     = RDK.RDK(1).mov_dir;   % movement directions for events

% fixation cross
p.crs.color             = [0.4 0.4 0.4 1];      % color of fixation cross
p.crs.size              = 12;                   % size of fixation
p.crs.width             = 2;                    % width of fixation cross
p.crs.cutout            = 0;                    % 1 = no dots close to fixation cross

% trigger
p.trig.rec_start        = 253;                  % trigger to start recording
p.trig.rec_stop         = 254;                  % trigger to stop recording
p.trig.tr_start         = 77;                   % trial start; main experiment
p.trig.tr_stop          = 88;                   % trial end; main experiment
p.trig.tr_con_center    = [1 2 3 4 5 6 ]*10;    % color change tracked in periphery? COLORCHANGE [c1 -> c2; c1 -> c3; c2 -> c1; c2 -> c3; c3 -> c1; c3 -> c2]
p.trig.tr_con_task      = [0 1];                % indices for task
p.trig.button           = 233;                  % button press
p.trig.event_type       = [211 212 213 214; 221 222 223 224];  % target [RDKcl1 RDKcl2 RECTcl1 RECTcl2]; distractor [RDKcl1 RDKcl2 RECTcl1 RECTcl2]

% possible condition triggers:
% RDK task [0]
% {010 020 030 040 050 060} [l_tr1 r_tr2,  l_tr1 r_tr0; l_tr2 r_tr1, l_tr2 r_tr0; l_tr0 r_tr1, l_tr0 r_tr2]; no event
% {011 021 031 041 051 061} [l_tr1 r_tr2,  l_tr1 r_tr0; l_tr2 r_tr1, l_tr2 r_tr0; l_tr0 r_tr1, l_tr0 r_tr2]; with event(s)
% rectangle task
% {110 120 130 140 150 160} [l_tr1 r_tr2,  l_tr1 r_tr0; l_tr2 r_tr1, l_tr2 r_tr0; l_tr0 r_tr1, l_tr0 r_tr2]; no event
% {111 121 131 141 151 161} [l_tr1 r_tr2,  l_tr1 r_tr0; l_tr2 r_tr1, l_tr2 r_tr0; l_tr0 r_tr1, l_tr0 r_tr2]; with event(s)

% logfiles
p.log.path              = '/home/stimulationspc/matlab/User/christopher/stim_ssvep_fshift_stimdriven/logfiles/';
p.log.exp_name          = 'SSVEP_FShift_StimDriven';
p.log.add               = '_a';


%% check for logfile being present
filecheck=dir(sprintf('%sVP%02.0f_timing*',p.log.path,p.sub));
if ~isempty(filecheck)
    reply = input(sprintf('\nVP%02.0f existiert bereits. Datei überschreiben? [j/n]... ',p.sub),'s');
    if strcmp(reply,'j')
        p.filename = sprintf('VP%02.0f_timing',p.sub);
    else
        [temp name_ind]=max(cellfun(@(x) numel(x), {filecheck.name}));
        p.filename = sprintf('%s%s',filecheck(name_ind).name(1:end-4),p.log.add);
    end
else
    p.filename = sprintf('VP%02.0f_timing',p.sub);
end

t.isol = {};
% routine to check for older isoluminance adjustments
for i_file = 1:numel(filecheck)
    t.in = load(fullfile(filecheck(i_file).folder,filecheck(i_file).name));
    t.datenum{i_file} = filecheck(i_file).datenum;
    t.isol{i_file} = t.in.p.isol;
    
end



%% Screen init
ps.input = struct('ScrNum',p.scr_num,'RefRate',p.scr_refrate,'PRPXres',p.scr_res,'BckGrCol',p.scr_color,'PRPXmode',2);
[~, ps.screensize, ps.xCenter, ps.yCenter, ps.window, ps.framerate, ps.RespDev, ps.keymap] = PTExpInit_GLSL(ps.input,1);

% some initial calculations
% fixation cross
ps.center = [ps.xCenter ps.yCenter];
p.crs.half = p.crs.size/2;
p.crs.bars = [-p.crs.half p.crs.half 0 0; 0 0 -p.crs.half p.crs.half];

% shift into 4 quadrants (running with 480 Hz)
ps.shift = [-ps.xCenter/2, -ps.yCenter/2; ps.xCenter/2, -ps.yCenter/2;... % shifts to four quadrants: upper left, upper right, lower left, lower right
    -ps.xCenter/2, ps.yCenter/2; ps.xCenter/2, ps.yCenter/2];

p.crs.lines = [];
for i_quad=1:p.scr_imgmultipl
    p.crs.lines = cat(2, p.crs.lines, [p.crs.bars(1,:)+ps.shift(i_quad,1); p.crs.bars(2,:)+ps.shift(i_quad,2)]); %array with start and end points for the fixation cross lines, for all four quadrants
end

%% keyboard and ports setup ???
KbName('UnifyKeyNames')
Buttons = [KbName('ESCAPE') KbName('Q') KbName('SPACE') KbName('j') KbName('n') KbName('s') KbName('l') KbName('1!') KbName('2@')];
RestrictKeysForKbCheck(Buttons);
key.keymap=false(1,256);
key.keymap(Buttons) = true;
key.keymap_ind = find(key.keymap);
[key.ESC, key.SECRET, key.SPACE, key.YES, key.NO key.class1 key.class2] = deal(...
    Buttons(1),Buttons(2),Buttons(3),Buttons(4),Buttons(5),Buttons(6),Buttons(7));

%% start experiment
% initialize randomization of stimulation frequencies and RDK colors
% inititalize RDKs [RDK1 and RDK2 task relevant at center;  RDK3 RDK4 RDK5 not and in periphery]
% rand('state',p.sub)
rng(p.sub,'v4')

RDK.RDK(1).col_init = RDK.RDK(1).col;
RDK.RDK(1).col_name = "grey";
RDK.RDK(2:3) = deal(RDK.RDK(1));

% randomize colors
t.idx = randperm(numel(p.stim.colors));

% change colors for this participant
p.stim.colors = p.stim.colors(t.idx);
p.stim.colors_max = p.stim.colors;
p.stim.color_names = p.stim.color_names(t.idx);
p.isol.init_cols = p.isol.init_cols(t.idx,:);

% override with isol colors?
for i_col = 1:numel(p.stim.colors)
    p.stim.colors{i_col}(1,:) = p.isol.init_cols(i_col,:);
end

% alter RDKs
for i_rdk = 1:2
    % color
    RDK.RDK(1+i_rdk).col = p.stim.colors{i_rdk};
    RDK.RDK(1+i_rdk).col_init = p.stim.colors{i_rdk};
    RDK.RDK(1+i_rdk).col_name = p.stim.color_names{i_rdk};
    % position
    RDK.RDK(1+i_rdk).centershift = p.stim.pos_shift(i_rdk,:);
end

% randomize frequencies
% not for center
RDK.RDK(1).freq = p.stim.freqs{1};
t.val = num2cell(p.stim.freqs{2}(randperm(2)));
[RDK.RDK(2:3).freq] = t.val{:};

% initialize blank variables
timing = []; button_presses = []; resp = []; randmat = [];

%% initial training
if p.flag_training
    fprintf(1,'\nRDK Training starten mit 1; Rectangle Training starten mit 2')
    inp.prompt_check = 0;
    while inp.prompt_check == 0             % loop to check for correct input
        [key.keyisdown,key.secs,key.keycode] = KbCheck;
        if key.keycode(Buttons(8))==1
            flag_trainend = 0; inp.prompt_check = 1; flag_traintype = 1;
        elseif key.keycode(Buttons(9))==1
            flag_trainend = 0; inp.prompt_check = 1; flag_traintype = 2;
        end
        Screen('Flip', ps.window, 0);
    end
    
    
    i_bl = 1;
    flag_trainend = 0;
    while flag_trainend == 0 % do training until ended
        %rand('state',p.sub*i_bl) % determine randstate
        rng(p.sub*i_bl,'v4')
        randmat.training{i_bl} = rand_FShift_StimDriven(p, RDK,  flag_traintype);
        % which task?
        pres_instruction(p,ps,RDK,i_bl,randmat.training{i_bl},1,key, randmat.training{i_bl}.trials(1).task); % Instruktion fürs Training
        [timing.training{i_bl},button_presses.training{i_bl},resp.training{i_bl}] = ...
            pres_FShift_StimDriven(p, ps, key, RDK, randmat.training{i_bl}, i_bl,1);
        save(sprintf('%s%s',p.log.path,p.filename),'timing','button_presses','resp','randmat','p', 'RDK')
        pres_feedback(resp.training{i_bl},p,ps, key,RDK)
               
        % loop for training to be repeated
        fprintf(1,'\nTraing wiederholen? (j/n)')
        inp.prompt_check = 0;
        while inp.prompt_check == 0             % loop to check for correct input
            [key.keyisdown,key.secs,key.keycode] = KbCheck; 
            if key.keycode(key.YES)==1
                i_bl = i_bl + 1; flag_trainend = 0; inp.prompt_check = 1;
            elseif key.keycode(key.NO)==1
                flag_trainend = 1; inp.prompt_check = 1;
            end
            Screen('Flip', ps.window, 0);
        end  
        
    end
end

%% then isoluminance adjustment
% do the heterochromatic flicker photometry
ttt=WaitSecs(0.7);
if flag_isolum == 1
%     
%     PsychDefaultSetup(2);
%     Datapixx('Open');
%     Datapixx('SetPropixxDlpSequenceProgram', 0);
%     Datapixx('RegWrRd');
     
    
    
    % start isoluminance script only RGB output (no alpha)
    [Col2Use] = PRPX_IsolCol_480_adj(...
        [p.isol.bckgr(1:3); p.isol.init_cols(:,1:3)],...
        p.isol.TrlAdj,...
        p.isol.MaxStd,...
        cellfun(@(x) x(1), {RDK.RDK.centershift})',...
        RDK.RDK(1).size);
    
    for i_RDK = 1:numel(RDK.RDK)
        RDK.RDK(i_RDK).col(1,:) = [Col2Use(1+i_RDK,:) 1];
    end
    % index function execution
    p.isol.run = sprintf('originally run: %s',datestr(now));
    p.isol.coladj = [Col2Use(2:end,:) ones(size(Col2Use,1)-1,1)];
    save(sprintf('%s%s',p.log.path,p.filename),'timing','button_presses','resp','randmat','p', 'RDK')
    
    fprintf('\nadjusted colors:\n')
    for i_col = 1:size(p.isol.coladj,1)
        fprintf('RDK%1.0f [%1.4f %1.4f %1.4f %1.4f]\n', i_col,p.isol.coladj(i_col,:))
    end
    
    Screen('CloseAll')
    Datapixx('SetPropixxDlpSequenceProgram', 0);
    Datapixx('RegWrRd');
    Datapixx('close');
else
    % select colors differently
    fprintf(1,'\nKeine Isoluminanzeinstellung. Wie soll verfahren werden?')
    % specify options
    % option1: use default values
    isol.opt(1).available = true;
    t.cols = cell2mat({RDK.RDK(:).col}');
    isol.opt(1).colors = t.cols(1:2:end,:);
    isol.opt(1).text = sprintf('default: %s',sprintf('[%1.2f %1.2f %1.2f] ',isol.opt(1).colors(:,1:3)'));
    % option2: use isoluminance values of previously saved dataset
    if ~isempty(t.isol) % file loaded 
        [t.t t.idx] = max(cell2mat(t.datenum));
        if any(strcmp(fieldnames(t.isol{t.idx}),'coladj')) % and adjusted colors exist?s
            isol.opt(2).available = true;
            isol.opt(2).colors = t.isol{t.idx}.coladj(1:end,:);
            isol.opt(2).text = sprintf('aus gespeicherter Datei: %s',sprintf('[%1.2f %1.2f %1.2f] ',isol.opt(2).colors(:,1:3)'));
        else
            isol.opt(2).available = false;
            isol.opt(2).colors = [];
            isol.opt(2).text = [];
        end
    else
        isol.opt(2).available = false;
        isol.opt(2).colors = [];
        isol.opt(2).text = [];
    end
    % option3: use manual override
    if ~isempty(p.isol.override)
        isol.opt(3).available = true;
        isol.opt(3).colors = p.isol.override;
        isol.opt(3).text = sprintf('manuell definiert in p.isol override: %s',sprintf('[%1.2f %1.2f %1.2f] ',isol.opt(3).colors(:,1:3)'));
    else
        isol.opt(3).available = false;
        isol.opt(3).colors = [];
        isol.opt(3).text = [];
    end
    % check for buttons
    IsoButtons = Buttons(6:8);
    isol.prompt.idx = find([isol.opt(:).available]);
    t.prompt = [];
    for i_prompt = 1:numel(isol.prompt.idx)
        t.prompt = [t.prompt sprintf('\n(%1.0f) %s',i_prompt,isol.opt(isol.prompt.idx(i_prompt)).text)];
    end
    
    % display options
    fprintf('%s',t.prompt)
    inp.prompt_check = 0;
    while inp.prompt_check == 0             % loop to check for correct input
        [key.keyisdown,key.secs,key.keycode] = KbCheck;
        if any(key.keycode)
            inp.prompt_check = 1;
        end
        Screen('Flip', ps.window, 0);
    end
    Col2Use = isol.opt(isol.prompt.idx(key.keycode(IsoButtons(1:numel(isol.prompt.idx)))==1)).colors;
    % use selected colors
    for i_RDK = 1:numel(RDK.RDK)
        RDK.RDK(i_RDK).col(1,:) = Col2Use(i_RDK,:);
    end
    % index function execution
    switch isol.prompt.idx(key.keycode(IsoButtons(1:numel(isol.prompt.idx)))==1)
        case 1
            p.isol.run = sprintf('default at %s',datestr(now));
        case 2
            p.isol.run = sprintf('reloaded at %s from %s',datestr(now),datestr(t.datenum{t.idx}));
        case 3
            p.isol.run = sprintf('override at %s',datestr(now));
    end
    p.isol.coladj = Col2Use;
%     save(sprintf('%s%s',p.log.path,p.filename),'timing','button_presses','resp','randmat','p', 'RDK')
    
    fprintf('\nselected colors:\n')
    for i_col = 1:size(p.isol.coladj,1)
        fprintf('RDK%1.0f [%1.4f %1.4f %1.4f %1.4f]\n', i_col,p.isol.coladj(i_col,:))
    end
end

%% redo initialization
ps.input = struct('ScrNum',p.scr_num,'RefRate',p.scr_refrate,'PRPXres',p.scr_res,'BckGrCol',p.scr_color,'PRPXmode',2);
[~, ps.screensize, ps.xCenter, ps.yCenter, ps.window, ps.framerate, ps.RespDev, ps.keymap] = PTExpInit_GLSL(ps.input,1);

% some initial calculations
% fixation cross
ps.center = [ps.xCenter ps.yCenter];
p.crs.half = p.crs.size/2;
p.crs.bars = [-p.crs.half p.crs.half 0 0; 0 0 -p.crs.half p.crs.half];

% shift into 4 quadrants (running with 480 Hz)
ps.shift = [-ps.xCenter/2, -ps.yCenter/2; ps.xCenter/2, -ps.yCenter/2;... % shifts to four quadrants: upper left, upper right, lower left, lower right
    -ps.xCenter/2, ps.yCenter/2; ps.xCenter/2, ps.yCenter/2];

p.crs.lines = [];
for i_quad=1:p.scr_imgmultipl
    p.crs.lines = cat(2, p.crs.lines, [p.crs.bars(1,:)+ps.shift(i_quad,1); p.crs.bars(2,:)+ps.shift(i_quad,2)]); %array with start and end points for the fixation cross lines, for all four quadrants
end

% keyboard setup
KbName('UnifyKeyNames')
Buttons = [KbName('ESCAPE') KbName('Q') KbName('SPACE') KbName('j') KbName('n') KbName('s') KbName('l') KbName('1!') KbName('2@')];
RestrictKeysForKbCheck(Buttons);
key.keymap=false(1,256);
key.keymap(Buttons) = true;
key.keymap_ind = find(key.keymap);
[key.ESC, key.SECRET, key.SPACE, key.YES, key.NO key.class1 key.class2] = deal(...
    Buttons(1),Buttons(2),Buttons(3),Buttons(4),Buttons(5),Buttons(6),Buttons(7));

%% do training again?
% loop for training to be repeated
fprintf(1,'\nTraing starten (j/n)')
inp.prompt_check = 0;
while inp.prompt_check == 0             % loop to check for correct input
    [key.keyisdown,key.secs,key.keycode] = KbCheck;
    if key.keycode(key.YES)==1
        flag_trainend = 0; inp.prompt_check = 1;
    elseif key.keycode(key.NO)==1
        flag_trainend = 1; inp.prompt_check = 1;
    end
    Screen('Flip', ps.window, 0);
end

if ~exist('i_bl'); i_bl = 1; end
while flag_trainend == 0 % do training until ended
    %rand('state',p.sub*i_bl) % determine randstate
    rng(p.sub*i_bl,'v4')
    randmat.training{i_bl} = rand_FShift_PerIrr(p, RDK,  1);
    pres_instruction(p,ps,RDK,i_bl,randmat.training{i_bl},1,key,randmat.training{i_bl}.trials(1).task); % Instruktion fürs Training
    [timing.training{i_bl},button_presses.training{i_bl},resp.training{i_bl}] = ...
        pres_FShift_PerIrr(p, ps, key, RDK, randmat.training{i_bl}, i_bl,1);
    save(sprintf('%s%s',p.log.path,p.filename),'timing','button_presses','resp','randmat','p', 'RDK')
    pres_feedback(resp.training{i_bl},p,ps, key,RDK)
    
    % loop for training to be repeated
    fprintf(1,'\nTraing wiederholen? (j/n)')
    inp.prompt_check = 0;
    while inp.prompt_check == 0             % loop to check for correct input
        [key.keyisdown,key.secs,key.keycode] = KbCheck;
        if key.keycode(key.YES)==1
            i_bl = i_bl + 1; flag_trainend = 0; inp.prompt_check = 1;
        elseif key.keycode(key.NO)==1
            flag_trainend = 1; inp.prompt_check = 1;
        end
        Screen('Flip', ps.window, 0);
    end
    
end


%% present each block
% randomization
% rand('state',p.sub);                         % determine randstate
rng(p.sub,'v4')
randmat.experiment = rand_FShift_StimDriven(p, RDK,  0);    % randomization
for i_bl = p.flag_block:p.stim.blocknum
    % start experiment
    t.whichtask = randmat.experiment.trials(find([randmat.experiment.trials.blocknum]==i_bl,1,'first')).task;
    pres_instruction(p,ps,RDK,i_bl,randmat.experiment,2,key,  t.whichtask); % Instruktion fürs Training
       [timing.experiment{i_bl},button_presses.experiment{i_bl},resp.experiment{i_bl}] = ...
        pres_FShift_StimDriven(p, ps, key, RDK, randmat.experiment, i_bl,0);
    % save logfiles
    save(sprintf('%s%s',p.log.path,p.filename),'timing','button_presses','resp','randmat','p', 'RDK')
          
    pres_feedback(resp.experiment{i_bl},p,ps, key, RDK)    
end

fprintf(1,'\n\nENDE\n')

%Close everything
Datapixx('SetPropixxDlpSequenceProgram', 0);
Datapixx('RegWrRd');
Datapixx('close');
ppdev_mex('Close', 1);
ListenChar(0);
sca;


end