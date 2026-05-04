function [ conmat ] = rand_FShift_StimDriven(p,RDK,flag_training)
%rand_FShiftBase randomizes experimental conditions
% move onset only works for constant frequency for all RDKs (i.e. 120)




% set trial number etc
if flag_training~=0
    conmat.totaltrials = numel(p.stim.condition)*numel(p.stim.eventnum_t)*p.stim.con_repeats_t;
    conmat.totalblocks = 1;
    p.stim.eventnum = p.stim.eventnum_t;
else
    conmat.totaltrials = sum(numel(p.stim.eventnum_e)*p.stim.con_repeats*numel(p.stim.condition));
    conmat.totalblocks = p.stim.blocknum;
    p.stim.eventnum = p.stim.eventnum_e;
end
conmat.trialsperblock = conmat.totaltrials/conmat.totalblocks;


%% start randomization
% randomize condition
t.mat = repmat(p.stim.condition,conmat.totaltrials/numel(p.stim.condition),1);
conmat.mats.condition = t.mat(:)';

% central color first and second time window
t.cols = ["red", "green"; "red","blue"; "green","red"; "green", "blue"; "blue","red"; "blue", "green"];
t.concols = t.cols(p.stim.RDKcenter_peri_i(:,1),:);
conmat.mats.central_color = t.concols(conmat.mats.condition,:);

% colors in periphery left and right
t.cols = ["red", "green", "blue"];
t.idx = p.stim.RDKperi(p.stim.RDKcenter_peri_i(:,2),:);
t.concols = reshape(t.cols(t.idx(:)),[size(p.stim.RDKcenter_peri_i)]);
conmat.mats.peri_color = t.concols(conmat.mats.condition,:);

% attentin in periphery [left right]COLUMNS x [time1 time2]ROWS
conmat.mats.peri_attention = {};
t.labels = ["attended","unattended"];
for i_tr = 1:conmat.totaltrials
    t.idx = cell2mat(arrayfun(@(x) strcmp(conmat.mats.central_color(i_tr,:),x),conmat.mats.peri_color(i_tr,:),'UniformOutput',false)')';
    conmat.mats.peri_attention{i_tr}=repmat(t.labels(2),size(t.idx));
    conmat.mats.peri_attention{i_tr}(t.idx)=t.labels(1);
end

% randomize event numbers per trial
% check if event numbers add up
if mod(conmat.totaltrials,numel(p.stim.eventnum))~=0 || mod(conmat.totaltrials/numel(p.stim.eventnum),2)~=0
    error('rando:eventdistribute', 'Can not distribute event numbers (ratio: [%s]) equally across %1.0f trials',...
        num2str(p.stim.eventnum), conmat.totaltrials);
end
conmat.mats.eventnum = repmat(p.stim.eventnum,1,conmat.totaltrials/numel(p.stim.eventnum));

% randomize eventtype (1 = target; 2 = distractor)
conmat.mats.eventtype = nan(max(p.stim.eventnum),conmat.totaltrials);
t.evtype = [1 2];

% not possible to randomize all possible sequences for all conditions
% randomize it for the most important conditions which will be used to collapse the data later on
% p.stim.con_ATTENTION
t.uniquecon = unique(p.stim.con_ATTENTION,'rows');

for i_con = 1:size(t.uniquecon,1)
    % index the condition number that fullfills the attention tracking condition t.uniquecon
    t.idx = ismember(conmat.mats.condition, ... % all physical conditions
        find(ismember(p.stim.con_ATTENTION,t.uniquecon(i_con,:),'rows')) ... % the relevant attentional tracking condition
        );
    for i_eventnum = 1:max(conmat.mats.eventnum)
        t.idx2 = conmat.mats.eventnum == i_eventnum;
        
        % Prepare the input list dynamically
        t.inputs = repmat({t.evtype}, 1, i_eventnum);

        % Call combinations with the expanded list
        t.combarray = table2array(combinations(t.inputs{:}))';
                         
        % randomly select the relevant number
        if size(t.combarray,2)>sum(t.idx&t.idx2)
            t.evtypemat = t.combarray(:,randperm(size(t.combarray,2),sum(t.idx&t.idx2)));
        else
            % fill up with random sequences?
            t.evtypemat = [repmat(t.combarray,1,floor(sum(t.idx&t.idx2)/size(t.combarray,2))) ...
                t.combarray(:,randperm(size(t.combarray,2), mod(sum(t.idx&t.idx2),size(t.combarray,2))))];
            % maybe fill up with random sequences but control for number of targets and distractors
            % predefine sequence
            t.num = mod(sum(t.idx&t.idx2),size(t.combarray,2))*size(t.combarray,1); % total number of events needed
            t.mat = [repmat(t.evtype,1,floor(t.num/size(t.evtype,2))) % repeated target type vector
                t.evtype(randperm(size(t.evtype,2), mod(t.num,size(t.evtype,2)))) % fill up with randomly drawn event
                ];
            t.mat_r = reshape(t.mat(randperm(numel(t.mat))),size(t.combarray,1),[]); % reshape vector -> creates random sequence
            t.evtypemat = [repmat(t.combarray,1,floor(sum(t.idx&t.idx2)/size(t.combarray,2))) ...
                t.mat_r];
        end
        conmat.mats.eventtype(1:i_eventnum,t.idx&t.idx2) = t.evtypemat(:,randperm(size(t.evtypemat,2)));
    end
end


% determine event RDK
conmat.mats.eventRDK = nan(max(p.stim.eventnum),conmat.totaltrials);
conmat.mats.eventRDK(~isnan(conmat.mats.eventtype)) = 1;


% randomize event directions (according to RDK.event.direction)
conmat.mats.eventdirection = nan(max(p.stim.eventnum),conmat.totaltrials);
t.mat = [repmat(1:4,1,floor(sum(~isnan(conmat.mats.eventtype(:)))/4)) randperm(4,mod(sum(~isnan(conmat.mats.eventtype(:))),4))];
conmat.mats.eventdirection(~isnan(conmat.mats.eventtype)) = t.mat(randperm(numel(t.mat)));


% randomize pre-color change times (and get respective post-color frames)
% all possible pre_cue_frames
t.allframes = p.stim.time_prechange(1)*p.scr_refrate:p.stim.time_prechange(2)*p.scr_refrate;
t.allframes = t.allframes(mod(t.allframes,p.scr_imgmultipl)==0); % only frames that are integers of frames per flip (i.e. 4)
t.allframes_post = t.allframes(end:-1:1);
if conmat.totaltrials<numel(t.allframes)
    t.ridx = randsample(1:numel(t.allframes),conmat.totaltrials);
    conmat.mats.pre_change_frames = t.allframes(t.ridx);
    conmat.mats.post_change_frames = t.allframes_post(t.ridx);
else
    conmat.mats.pre_change_frames = [repmat(t.allframes,1,floor(conmat.totaltrials/numel(t.allframes))) ...
        t.allframes(round(linspace(1,numel(t.allframes),mod(conmat.totaltrials,numel(t.allframes)))))];
    conmat.mats.post_change_frames = [repmat(t.allframes_post,1,floor(conmat.totaltrials/numel(t.allframes_post))) ...
        t.allframes_post(round(linspace(1,numel(t.allframes_post),mod(conmat.totaltrials,numel(t.allframes_post)))))];
end
t.ridx = randperm(numel(conmat.mats.pre_change_frames));
conmat.mats.pre_change_frames = conmat.mats.pre_change_frames(t.ridx);
conmat.mats.post_change_frames = conmat.mats.post_change_frames(t.ridx);
conmat.mats.pre_change_times = conmat.mats.pre_change_frames./p.scr_refrate;
conmat.mats.post_change_times = conmat.mats.post_change_frames./p.scr_refrate;

%% pre-allocate possible presentation times
% this one is difficult! Do it all sequentially: last possible window, first possible, second last, second etc.
% this is for the whole trial...bit needs to be adjusted for the respective trial with shifting times considered

% pre-allocate possible presentation times
conmat.mats.event_onset_frames = nan(max(p.stim.eventnum),conmat.totaltrials);
conmat.mats.event_onset_times = conmat.mats.event_onset_frames;
conmat.mats.event_onset_frames_centered = conmat.mats.event_onset_frames;
conmat.mats.event_onset_times_centered = conmat.mats.event_onset_frames;
% window sequence [4 1 3 2 or 3 1 2 or 2 1 or 1]

for i_evnum = 1:max(p.stim.eventnum)
    % first define the sampling of the relevant timewindows
    t.relwins = [flip(1:i_evnum); 1:i_evnum]; t.relwins = t.relwins(1:i_evnum);
    t.relwins2 = [flip(2:2:i_evnum+1); ones(1,round(i_evnum/2))]; t.relwins2 = t.relwins2(1:i_evnum);
    % do this separately for all the relevant conditions
    for i_con = 1:size(t.uniquecon,1)
        % index the condition number that fullfills the attention tracking condition t.uniquecon
        t.idx1 = ismember(conmat.mats.condition, ... % all physical conditions
            find(ismember(p.stim.con_ATTENTION,t.uniquecon(i_con,:),'rows')) ... % the relevant attentional tracking condition
            );
        t.idx2 = conmat.mats.eventnum == i_evnum;
        t.idx = t.idx1 & t.idx2;
        t.idx_i = find(t.idx);
        % loop across trials
        for i_tr = 1:numel(t.idx_i)

            % here the flips need to be adjusted
            % first define onsets centered at color change
            t.onframesonset = nan(numel(RDK.RDK(1)),p.scr_refrate*p.stim.triallength);
            t.onframesonset_times = t.onframesonset; % onset times in s
            for i_rdk = 1:numel(RDK.RDK(1))
                % pre-change mat
                t.mat1 = flip(ceil(1:-p.scr_refrate/RDK.RDK(i_rdk).freq:(-conmat.mats.pre_change_frames(t.idx_i(i_tr)))));
                % t.mat1 = flip(floor(1:-p.scr_refrate/RDK.RDK(i_rdk).freq:(-conmat.mats.pre_change_frames(t.idx_i(i_tr))))-1);
                % post-change mat
                t.mat2 = ceil(1:p.scr_refrate/RDK.RDK(i_rdk).freq:conmat.mats.post_change_frames(t.idx_i(i_tr)));
                t.mat = [t.mat1(1:end-1) t.mat2(1:end)]+conmat.mats.pre_change_frames(t.idx_i(i_tr));
                t.onframesonset(i_rdk,t.mat)=1;
                t.onframesonset_times(i_rdk,t.mat)=(t.mat)./p.scr_refrate;
            end

            % move
            t.movonset_frames=nan(size(t.onframesonset));
            t.movonset_times=t.movonset_frames;
            t.mat1 = flip(ceil(1:-p.scr_refrate/RDK.RDK(1).mov_freq:(-conmat.mats.pre_change_frames(t.idx_i(i_tr))-1)));
            t.mat2 = ceil(1:p.scr_refrate/RDK.RDK(1).mov_freq:conmat.mats.post_change_frames(t.idx_i(i_tr)));
            t.mat = [t.mat1(1:end-1) t.mat2]+conmat.mats.pre_change_frames(t.idx_i(i_tr));
            t.movonset_frames(t.mat)=1;
            t.movonset_times(t.mat)=(t.mat)./p.scr_refrate;

            % center the times
            t.onframesonset_times_centered = t.onframesonset_times-((conmat.mats.pre_change_frames(t.idx_i(i_tr))+1)/p.scr_refrate);
            t.movonset_times_centered = t.movonset_times-((conmat.mats.pre_change_frames(t.idx_i(i_tr))+1)/p.scr_refrate);
            
            % loop through events
            for i_ev = 1:numel(t.relwins)
                % define possible windows
                % first: find upper and lower boundaries for events, this depends on possibly placed events already
                
                % are there already events we need to consider?
                % define upper and lower boundary accordingly
                if i_ev>1
                    % if there are already events consider them for upper boundary
                    t.tevtimes = sort(conmat.mats.event_onset_times(~isnan(conmat.mats.event_onset_times(:,t.idx_i(i_tr))),t.idx_i(i_tr)));
                    t.boundup =  max(t.onframesonset_times(t.onframesonset_times< ...
                        (t.tevtimes(end-floor(i_ev/2)+1)-p.stim.event.length-p.stim.event.min_dist) ...
                        ));
                    if i_ev>2
                        t.boundlow = min(t.onframesonset_times(t.onframesonset_times>t.tevtimes(ceil(i_ev/2)-1)+p.stim.event.length+p.stim.event.min_dist));
                    else
                        t.boundlow = min(t.onframesonset_times(t.onframesonset_times>p.stim.event.min_onset));
                    end
                else
                    t.boundup = max(t.onframesonset_times(t.onframesonset_times<(max(t.onframesonset_times)-p.stim.event.length-p.stim.event.min_offset)));
                    t.boundlow = min(t.onframesonset_times(t.onframesonset_times>p.stim.event.min_onset));
                end
                % now divide the possible time range into different equally spaced time window bins that suffice the constraints
                
                % need to save minimum time for lower bound or upper bound respectively depending on number of events still
                % to be distributed
                if mod(i_ev,2) ~= 0 % all trials starting from the top -> lower bound should be high enough to account for more events
                    t.possframes = t.onframesonset_times<=t.boundup & ...
                        t.onframesonset_times>=(t.boundlow + ...
                        ((numel(t.relwins)-i_ev) * (p.stim.event.length + p.stim.event.min_dist + 1/RDK.RDK(1).freq)));
                else
                    t.possframes = t.onframesonset_times>=t.boundlow & ...
                        t.onframesonset_times<=(t.boundup - ...
                        ((numel(t.relwins)-i_ev) * (p.stim.event.length + p.stim.event.min_dist + 1/RDK.RDK(1).freq)));

                end

                % now randomly sample one onset from these time points
                t.possframes_idx = find(t.possframes);
                t.randidx = t.possframes_idx(randsample([1:numel(t.possframes_idx)],1));
                conmat.mats.event_onset_frames(t.relwins(i_ev),t.idx_i(i_tr)) = t.randidx;
                conmat.mats.event_onset_times(t.relwins(i_ev),t.idx_i(i_tr)) = t.onframesonset_times( t.randidx);
                conmat.mats.event_onset_frames_centered(t.relwins(i_ev),t.idx_i(i_tr)) = t.randidx-conmat.mats.pre_change_frames(t.idx_i(i_tr));
                conmat.mats.event_onset_times_centered(t.relwins(i_ev),t.idx_i(i_tr)) = t.onframesonset_times_centered( t.randidx);
                % conmat.mats.event_onset_times(:,t.idx_i(i_tr))
                % t.onframesonset_times(t.possframes)

            end

        end
    end
end

% graphical check
% figure; histogram(conmat.mats.event_onset_times(:),50)
% t.data = conmat.mats.event_onset_times-repmat(conmat.mats.pre_change_times,size(conmat.mats.event_onset_times,1),1);
% figure; histogram(t.data(:),50)

% figure; histogram(conmat.mats.event_onset_times_centered(:),50)



%% randomize all information across experiment
t.tidx = randperm(conmat.totaltrials);
conmat.mats.condition = conmat.mats.condition(:,t.tidx);
conmat.mats.central_color = conmat.mats.central_color(t.tidx,:);
conmat.mats.peri_color = conmat.mats.peri_color(t.tidx,:);
conmat.mats.peri_attention = conmat.mats.peri_attention(t.tidx);

conmat.mats.eventnum = conmat.mats.eventnum(:,t.tidx);
conmat.mats.eventtype = conmat.mats.eventtype(:,t.tidx);
conmat.mats.eventRDK = conmat.mats.eventRDK(:,t.tidx);
conmat.mats.eventdirection = conmat.mats.eventdirection(:,t.tidx);
conmat.mats.event_onset_frames = conmat.mats.event_onset_frames(:,t.tidx);
conmat.mats.event_onset_times = conmat.mats.event_onset_times(:,t.tidx);
conmat.mats.event_onset_frames_centered = conmat.mats.event_onset_frames_centered(:,t.tidx);
conmat.mats.event_onset_times_centered = conmat.mats.event_onset_times_centered(:,t.tidx);
conmat.mats.pre_change_frames = conmat.mats.pre_change_frames(:,t.tidx);
conmat.mats.post_change_frames = conmat.mats.post_change_frames(:,t.tidx);
conmat.mats.pre_change_times = conmat.mats.pre_change_times(:,t.tidx);
conmat.mats.post_change_times = conmat.mats.post_change_times(:,t.tidx);

conmat.mats.block = repmat(1:conmat.totalblocks,conmat.trialsperblock,1);
conmat.mats.block = conmat.mats.block(:);

%% write all information into trial structure
% create frame mat, onset time for events

for i_tr = 1:conmat.totaltrials
    % trialnumber
    conmat.trials(i_tr).trialnum = i_tr;
    
    % block number
    conmat.trials(i_tr).blocknum = conmat.mats.block(i_tr);
    
    % condition 
    conmat.trials(i_tr).condition = conmat.mats.condition(i_tr);

    % central color [time1 time2]
    conmat.trials(i_tr).central_color = conmat.mats.central_color(i_tr,:);

    % peri color [left right]
    conmat.trials(i_tr).peri_color = conmat.mats.peri_color(i_tr,:);

    % peri attention [left right] columns; [time1 time2] rows
    conmat.trials(i_tr).peri_attention = conmat.mats.peri_attention{i_tr};
    
    % pre change frames
    conmat.trials(i_tr).pre_change_frames = conmat.mats.pre_change_frames(i_tr);
    
    % post change frames
    conmat.trials(i_tr).post_change_frames = conmat.mats.post_change_frames(i_tr);

    % pre change frames
    conmat.trials(i_tr).pre_change_times = conmat.mats.pre_change_times(i_tr);
    
    % post change frames
    conmat.trials(i_tr).post_change_times = conmat.mats.post_change_times(i_tr);    
    
    % number of events
    conmat.trials(i_tr).eventnum = conmat.mats.eventnum(i_tr);
    
    % type of events ((target, distractor) [1, 2])
    conmat.trials(i_tr).eventtype = conmat.mats.eventtype(:,i_tr);
    
    % which RDK shows event?
    conmat.trials(i_tr).eventRDK = conmat.mats.eventRDK(:,i_tr);
    
    % eventdirection ((according to RDK.event.direction) [1 2 3 4])
    conmat.trials(i_tr).eventdirection = conmat.mats.eventdirection(:,i_tr);
    
    % event onset frames
    conmat.trials(i_tr).event_onset_frames = conmat.mats.event_onset_frames(:,i_tr);
    
    % event onset times
    conmat.trials(i_tr).event_onset_times = conmat.mats.event_onset_times(:,i_tr);
end



    

end

