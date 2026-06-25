function [timing,key,resp] = pres_FShift_StimDriven(p, ps, key, RDK, conmat, blocknum, flag_training)
% presents experiment SSVEP_FShiftBase
%   p               = parameters
%   ps              = screen parameters
%   RDK             = RDK parameters
%   blocknum        = number of block
%   flag_training   = flag for trainig (1) or experiment (0)

%% adaptations for training
if flag_training == 1
    blocknum_present = blocknum;
    blocknum = 1;
end

%% prepare datapixx output
bufferAddress = 8e6;
% % samplesPerTrigger = 1;
triggersPerRefresh = 1; % send one per refresh (i.e. p.scr_refrate at 480 Hz)


%% initialize some RDK settings
% define input for RDK init function
RDKin.scr = ps; RDKin.scr.refrate = p.scr_refrate;
RDKin.Propixx = p.scr_imgmultipl;
RDKin.RDK = RDK;
RDKin.crs = p.crs;

%% loop for each trial
% trialindex = find(conmat.mats.block==blocknum);
trialindex = find([conmat.trials.blocknum]==blocknum);

% send start trigger
if flag_training~=1
    PRPX_sendRecTrigger('start')
end

% Wait for release of all keys on keyboard, then sync us to retrace:
KbWait(ps.RespDev,1); % wait for releasing keys on indicated response device

% create keayboard queue
KbQueueCreate(ps.RespDev)

if flag_training~=1
    fprintf(1,'\nexperiment block %1.0f - Praesentation - Trial:', blocknum)
else
    fprintf(1,'\ntraining block %1.0f - Praesentation - Trial:', blocknum_present)
end
ttt=WaitSecs(0.3);

% loop across trials
for i_tr = 1:numel(trialindex)
    fprintf('%1.0f',mod(i_tr,10))
    inittime=GetSecs;
    %% initialize trial structure, RDK, cross, logs
    RDKin.trial = struct('duration',conmat.trials(trialindex(i_tr)).post_change_times+conmat.trials(trialindex(i_tr)).pre_change_times,...
        'frames',conmat.trials(trialindex(i_tr)).post_change_frames+conmat.trials(trialindex(i_tr)).pre_change_frames,...
        'cue',conmat.trials(trialindex(i_tr)).pre_change_frames+1);
    % check for RDK events?
    t.rdkevidx = conmat.trials(trialindex(i_tr)).eventstim == 1;
    t.eventframes = conmat.trials(trialindex(i_tr)).event_onset_frames;
    t.eventframes(~t.rdkevidx)=nan;
    RDKin.trial.event = struct('onset',t.eventframes,...
        'direction',conmat.trials(trialindex(i_tr)).RDKeventdirection,'RDK',t.rdkevidx);
    RDKin.RDK.RDK = RDK.RDK(1:3);
    [colmat,dotmat,dotsize,rdkidx,frames, lummat] = RDK_init_FShift_StimDriven(RDKin.scr,RDKin.Propixx,RDKin.RDK,RDKin.trial,RDKin.crs);
    
    % initialize fixation cross
    colmat_cr = repmat(p.crs.color' ,[1 1 size(colmat,3)]);
    
    % preallocate timing
    timing(i_tr) = struct('VBLTimestamp',NaN(1,frames.flips),'StimulusOnsetTime',NaN(1,frames.flips),...
        'FlipTimestamp',NaN(1,frames.flips),'Missed',NaN(1,frames.flips));
    
    %% preallocate rectange information for standard rectangles with color and potential events
    rect.baseRect = [0 0 RDK.RDK(1).size] + [0 0 2*p.stim.event.rect_modsize 2*p.stim.event.rect_modsize];
    rect.baseRect_ct = CenterRectOnPointd(rect.baseRect,ps.center(1),ps.center(2));
    rect.posmat = repmat(rect.baseRect_ct,RDKin.trial.frames,1);
    % now adjust positions for events
    t.evidx = find(conmat.trials(trialindex(i_tr)).eventstim==2); % find rectangle events
    for i_ev = 1:numel(t.evidx)
        t.modidx = conmat.trials(trialindex(i_tr)).RECTeventpos(t.evidx(i_ev),:); % changes in dimensions [top right bottom left]
        
        % testing
        % t.modidx = [1 0 0 0]; % top
        % t.modidx = [0 1 0 0]; % right
        % t.modidx = [0 0 1 0]; % bottom
        % t.modidx = [0 0 0 1]; % left
        % t.modidx = [1 0 1 0]; % top  + bottom
        % t.modidx = [0 1 0 0]; % left + right
        
        % amount of change
        t.modchange = [0 0 0 0] + ...
            [t.modidx([4 1 2 3]) .* ... translate changes in dimensions [top right bottom left] to rect.baseRect_ct dimensions
            [1 1 -1 -1] .* ... % are values to be added or subtracted?
            1./([sum(t.modidx([4 2])) sum(t.modidx([1 3])) sum(t.modidx([4 2])) sum(t.modidx([1 3]))]) .*...  % are values to be distributed across one or two dimensions?
            p.stim.event.rect_modsize];
        t.modchange(isnan(t.modchange)) = 0;

        % start and duration
        t.moddur = [1 1].* conmat.trials(trialindex(i_tr)).event_onset_frames(t.evidx(i_ev)) + ...
            [0 p.scr_refrate*p.stim.event.rect_moddur-1];

        % write changes into rect.posmat
        rect.posmat(t.moddur(1):t.moddur(2),:) = rect.posmat(t.moddur(1):t.moddur(2),:) + repmat(t.modchange,diff(t.moddur)+1,1);
    end

    % now shift them into the quadrants
    % add QUAD4X shift to positions
    rect.posmat_sh = rect.posmat;
    for i_pos=1:p.scr_imgmultipl
        shift_idx = i_pos:p.scr_imgmultipl:frames.pertrial;
        rect.posmat_sh(shift_idx,:) = ...
            [rect.posmat_sh(shift_idx,1)+ps.shift(i_pos,1), ...
            rect.posmat_sh(shift_idx,2)+ps.shift(i_pos,2), ...
            rect.posmat_sh(shift_idx,3)+ps.shift(i_pos,1),...
            rect.posmat_sh(shift_idx,4)+ps.shift(i_pos,2)];
    end
    rect.posmat_sh = reshape(rect.posmat_sh',[4,p.scr_imgmultipl, frames.flips]);
    
    % create color for rect
    rect.colmat = repmat(p.stim.colors{conmat.trials(trialindex(i_tr)).central_color(1)}(1,:), size(rect.posmat,1),1);
    rect.colmat(conmat.trials(trialindex(i_tr)).pre_change_frames+1:end,:) = ...
        repmat(p.stim.colors{conmat.trials(trialindex(i_tr)).central_color(2)}(1,:), conmat.trials(trialindex(i_tr)).post_change_frames,1);
    % add background color to every second frame
    rect.colmat(1:2:end,:) = repmat(RDKin.scr.input.BckGrCol,size(rect.colmat(1:2:end,:),1),1);
    rect.colmat_sh = reshape(rect.colmat',[4,p.scr_imgmultipl, frames.flips]);

    % testing drawing
    % Screen('FillRect', ps.window, [1 0 0], rect.baseRect_ct);
    % Screen('FillRect', ps.window, [0 1 0], rect.baseRect_ct+t.modchange);
    % Screen('FillRect', ps.window, rect.colmat_sh(:,:,1), rect.posmat_sh(:,:,1));
    % Screen('Flip', ps.window, 0);

    %% set up responses
    %setup key presses
    key.presses{i_tr}=nan(size(colmat,3),sum(key.keymap));
    key.presses_t{i_tr}=nan(size(colmat,3),sum(key.keymap));
    
    resp(i_tr).trialnumber              = trialindex(i_tr);
    resp(i_tr).blocknumber              = conmat.trials(trialindex(i_tr)).blocknum;
    resp(i_tr).condition                = conmat.trials(trialindex(i_tr)).condition;
    resp(i_tr).task                     = conmat.trials(trialindex(i_tr)).task;
    resp(i_tr).central_color            = conmat.trials(trialindex(i_tr)).central_color;
    resp(i_tr).central_color_label      = conmat.trials(trialindex(i_tr)).central_color_label; % t1 t2
    resp(i_tr).peri_color               = conmat.trials(trialindex(i_tr)).peri_color;
    resp(i_tr).peri_color_label         = conmat.trials(trialindex(i_tr)).peri_color_label; % left right
    resp(i_tr).peri_attention_collapsed = conmat.trials(trialindex(i_tr)).peri_attention_collapsed;
    resp(i_tr).peri_attention           = conmat.trials(trialindex(i_tr)).peri_attention; % [left right; left right] [t1 t1; t2 t2]
    resp(i_tr).pre_change_frames        = conmat.trials(trialindex(i_tr)).pre_change_frames;
    resp(i_tr).pre_change_times         = conmat.trials(trialindex(i_tr)).pre_change_times;
    resp(i_tr).post_change_frames       = conmat.trials(trialindex(i_tr)).post_change_frames;
    resp(i_tr).post_change_times        = conmat.trials(trialindex(i_tr)).post_change_times;
    resp(i_tr).eventnum                 = conmat.trials(trialindex(i_tr)).eventnum;
    resp(i_tr).eventtype                = conmat.trials(trialindex(i_tr)).eventtype; % 1 = target; 2 = distractor
    resp(i_tr).eventstim                = conmat.trials(trialindex(i_tr)).eventstim; % 1 = RDK; 2 = rectangle
    resp(i_tr).eventdiscrtype           = conmat.trials(trialindex(i_tr)).eventdiscrtype; % 1 = class1; 2 = class2
    resp(i_tr).RDKeventdirection        = conmat.trials(trialindex(i_tr)).RDKeventdirection; 
    resp(i_tr).RDKeventdirection_lab    = conmat.trials(trialindex(i_tr)).RDKeventdirection_lab; 
    resp(i_tr).RECTeventpos             = conmat.trials(trialindex(i_tr)).RECTeventpos; 
    resp(i_tr).RECTeventpos_lab         = conmat.trials(trialindex(i_tr)).RECTeventpos_lab; 
    resp(i_tr).event_onset_frames       = conmat.trials(trialindex(i_tr)).event_onset_frames;
    resp(i_tr).event_onset_times        = conmat.trials(trialindex(i_tr)).event_onset_times;
    
    %% set up datapixx trigger vector
    % prepare datapixx scheduler
    % trigger signal needs to encompass first frame after stimulation has ended to send trial stop trigger
    if size(colmat_cr,3)*p.scr_imgmultipl>...
            conmat.trials(trialindex(i_tr)).pre_change_frames+conmat.trials(trialindex(i_tr)).post_change_frames+1
        doutWave = zeros(1,size(colmat_cr,3)*p.scr_imgmultipl); % each entry corresponds to a trigger
    else
        doutWave = zeros(1,size(colmat_cr,3)*p.scr_imgmultipl+p.scr_imgmultipl); % each entry corresponds to a trigger
    end
    
    % write trigger numbers into doutwave
    % trial start trigger
    doutWave(1) = p.trig.tr_start;
    % trial end trigger (presented at first frame after stimulation)
    doutWave(size(colmat_cr,3)*p.scr_imgmultipl+1) = p.trig.tr_stop;
    
    % condition trigger
    resp(i_tr).triggernum = ...
        p.trig.tr_con_task(resp(i_tr).task)*100; % condition for task [000 100];
    resp(i_tr).triggernum = resp(i_tr).triggernum + ...
        ... % condition for tracking of color change [l_tr1 r_tr2,  l_tr1 r_tr0; l_tr2 r_tr1, l_tr2 r_tr0; l_tr0 r_tr1, l_tr0 r_tr2]
        p.trig.tr_con_center(resp(i_tr).condition - p.trig.tr_con_task(resp(i_tr).task)*numel(p.trig.tr_con_center));
    resp(i_tr).triggernum = resp(i_tr).triggernum + ...
        resp(i_tr).eventnum; % number of events
    doutWave(resp(i_tr).pre_change_frames +1) = resp(i_tr).triggernum;
    
    % event trigger
    for i_ev = 1:resp(i_tr).eventnum
        t.trigger = 200 + ...
            resp(i_tr).eventtype(i_ev)*10 + ... % [10 20] target or distractor?
            (resp(i_tr).eventstim(i_ev)-1)*2 +...% RDK or rectangle event
        resp(i_tr).eventdiscrtype(i_ev); % class 1 or class 2
        doutWave(resp(i_tr).event_onset_frames(i_ev)) = t.trigger;
    end

    doutWave = [doutWave;zeros(triggersPerRefresh-1,numel(doutWave))]; doutWave=doutWave(:);
    samplesPerFlip = triggersPerRefresh * p.scr_imgmultipl;
    % figure; plot(doutWave)        
    
    % draw fixation cross
    Screen('DrawLines', ps.window, p.crs.lines, p.crs.width, p.crs.color, ps.center, 0);
    
    % send 0 before again to reset everything
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    
    % write outsignal
    Datapixx('WriteDoutBuffer', doutWave, bufferAddress);
    % disp(Datapixx('GetDoutStatus'));
    Datapixx('SetDoutSchedule', 0, [samplesPerFlip, 2], numel(doutWave), bufferAddress); % 0 - scheduleOnset delay, [samplesPerFlip, 2] - sheduleRate in samples/video frame, framesPerTrial - maxSheduleFrames
    Datapixx('StartDoutSchedule');
    
    %% keyboard
    % start listening to keyboard
    KbQueueStart(ps.RespDev);
    KbQueueFlush(ps.RespDev);
    
    % flip to get everything synced
    Screen('Flip', ps.window, 0);
    
    %% loop across frames
    for i_fl = 1:frames.flips
        %% Drawing
        % Rectangle
        Screen('FillRect', ps.window, rect.colmat_sh(:,:,i_fl), rect.posmat_sh(:,:,i_fl));
        % RDK
        Screen('DrawDots', ps.window, dotmat(:,:,i_fl), dotsize(:,i_fl), colmat(:,:,i_fl), ps.center, 0, 0);
        % fixation cross
        Screen('DrawLines', ps.window, p.crs.lines, p.crs.width, colmat_cr(:,1,i_fl)', ps.center, 0);
        
        %% start trigger schedule and start listening to response device
        if i_fl == 1 % send the trigger with the start of the 1st flip
            Datapixx('RegWrVideoSync');
        end
        
        % Flip
        [timing(i_tr).VBLTimestamp(i_fl), timing(i_tr).StimulusOnsetTime(i_fl), timing(i_tr).FlipTimestamp(i_fl), timing(i_tr).Missed(i_fl)] = Screen('Flip', ps.window, 0);

        % get image
        %current_display = Screen('GetImage',ps.window);
        %imwrite(current_display,'./stims/all_nocue_centralredblue_periredgreen.png')
        
        % send trigger/save timing/ reset timing
        if i_fl == 1
            % start trigger
            starttime=GetSecs;
            KbEventFlush(ps.RespDev); % flush keyboard
        end
        
        %% check for button presses
        [key.pressed, key.firstPress]=KbQueueCheck(ps.RespDev);
        key.presses{i_tr}(i_fl,:)=key.firstPress(key.keymap)>1;
        key.presses_t{i_tr}(i_fl,:)=(key.firstPress(key.keymap)-starttime).*key.presses{i_tr}(i_fl,:);
        if any(key.firstPress(key.keymap)>1)
            lptwrite(1,find(key.firstPress(key.keymap),1,'first'),500);
        end
    end
    %% ITI
    % draw fixation cross again
    Screen('DrawLines', ps.window, p.crs.lines, p.crs.width, p.crs.color, ps.center, 0);
    
    % flip
    Screen('Flip', ps.window, 0);
    
    % get time
    crttime = GetSecs;
    
    % add waiting period to check for late button presses
    ttt=WaitSecs(p.targ_respwin(2)/1000-p.stim.event.min_offset-p.stim.event.length);
    
    % check for button presses
    [key.pressed, key.firstPress]=KbQueueCheck(ps.RespDev);
    key.presses{i_tr}(i_fl+1,:)=key.firstPress(key.keymap)>1;
    key.presses_t{i_tr}(i_fl+1,:)=(key.firstPress(key.keymap)-starttime).*key.presses{i_tr}(i_fl+1,:);
    
    
    
    
    %%%%%%%%
    % do behavioral calculation
    key.presses{i_tr}(1,:)=[];
    key.presses_t{i_tr}(1,:)=[];
    
    % get frame and timing of button press onsets
    resp(i_tr).button_presses_fr=nan(max(sum(key.presses{i_tr})),size(key.presses{i_tr},2));
    resp(i_tr).button_presses_t=resp(i_tr).button_presses_fr;
    for i_bt = 1:size(key.presses{i_tr},2)
        try
            resp(i_tr).button_presses_fr(1:sum(key.presses{i_tr}(:,i_bt)),i_bt)=...
                find(key.presses{i_tr}(:,i_bt));
            resp(i_tr).button_presses_t(1:sum(key.presses{i_tr}(:,i_bt)),i_bt)=...
                key.presses_t{i_tr}(find(key.presses{i_tr}(:,i_bt)),i_bt)*1000; % in ms
        catch
            resp(i_tr).button_presses_fr(:,i_bt)=nan;
        end
    end
    
    % check for hits {'hit','miss','CR','FA_proper','FA'}
    resp(i_tr).button_presses_type = {}; %{'hit','miss','CR','FA_proper','FA'}
    resp(i_tr).button_presses_RT = []; % reaction time in ms (after event or closest to other event)
    resp(i_tr).event_response_type = {}; %{'hit','miss','CR','FA_proper'}
    resp(i_tr).event_response_RT = []; %reaction time or nan
    % all relevant presses
    
    t.presses = cat(1, resp(i_tr).button_presses_t(:,key.keymap_ind==key.class1), ...
        resp(i_tr).button_presses_t(:,key.keymap_ind==key.class2));
    t.presses_type = cat(1,ones(numel(resp(i_tr).button_presses_t(:,key.keymap_ind==key.class1)),1), ...
        ones(numel(resp(i_tr).button_presses_t(:,key.keymap_ind==key.class2)),1)+1);

    % get rid of nans
    t.presses_type(isnan(t.presses)) = [];
    t.presses(isnan(t.presses)) = [];
    
    % #######
    
    % first define response windows and class of event
    if any(~isnan(resp(i_tr).eventtype))
        t.respwin = (resp(i_tr).event_onset_times(~isnan(resp(i_tr).eventtype))+(p.targ_respwin/1000))*1000;
        t.respclass = resp(i_tr).eventdiscrtype(~isnan(resp(i_tr).eventtype));
    end
    % loop across button presses
    for i_press = 1:numel(t.presses)
        if any(~isnan(resp(i_tr).eventtype)) % is there an event?
            t.idx = t.presses(i_press)>=t.respwin(:,1) & t.presses(i_press)<=t.respwin(:,2);
            % not in any response window? --> FA; no reaction time
            if sum(t.idx)== 0
                resp(i_tr).button_presses_type{i_press} = 'FA';
                % no reaction time
                resp(i_tr).button_presses_RT(i_press) = nan;
            else
                if resp(i_tr).eventtype(t.idx)== 1 & resp(i_tr).eventdiscrtype(t.idx) == t.presses_type(i_press)
                    resp(i_tr).button_presses_type{i_press} = 'hit';
                elseif resp(i_tr).eventtype(t.idx)== 1 & resp(i_tr).eventdiscrtype(t.idx) ~= t.presses_type(i_press)
                    resp(i_tr).button_presses_type{i_press} = 'error';
                else
                    resp(i_tr).button_presses_type{i_press} = 'FA_proper';
                end
                resp(i_tr).event_response_type{t.idx} = resp(i_tr).button_presses_type{i_press};
                % reaction time?
                resp(i_tr).button_presses_RT(i_press) = t.presses(i_press)-(resp(i_tr).event_onset_times(t.idx)*1000);
                resp(i_tr).event_response_RT(t.idx) = resp(i_tr).button_presses_RT(i_press) ;
            end
            
        else
            % no events --> all presses are false alarms; no reaction time
            resp(i_tr).button_presses_type{i_press} = 'FA';
            resp(i_tr).button_presses_RT(i_press) = nan;
        end
    end
    % check for correct responses or misses
    for i_ev = 1:resp(i_tr).eventnum
        if isempty(resp(i_tr).event_response_type)| numel(resp(i_tr).event_response_type)<i_ev
            if resp(i_tr).eventtype(i_ev)==1
                resp(i_tr).event_response_type{i_ev}='miss';
            else
                resp(i_tr).event_response_type{i_ev}='CR';
            end
            resp(i_tr).event_response_RT(i_ev) = nan;
        else
            if isempty(resp(i_tr).event_response_type{i_ev})
                if resp(i_tr).eventtype(i_ev)==1
                    resp(i_tr).event_response_type{i_ev}='miss';
                else
                    resp(i_tr).event_response_type{i_ev}='CR';
                end
                resp(i_tr).event_response_RT(i_ev) = nan;
            end
        end
    end
    
    % wait
    crttime2 = GetSecs;
    t.timetowait = ((p.ITI(1)/1000)+RDKin.trial.duration)-(crttime2 - inittime);
    ttt=WaitSecs(t.timetowait);
    crttime3 = GetSecs; % for troubleshooting
    
    
end

% stop response recording
KbQueueRelease(ps.RespDev);

% send start trigger
if flag_training~=1
    PRPX_sendRecTrigger('stop')
end



end