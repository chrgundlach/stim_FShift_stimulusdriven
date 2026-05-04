function [] = pres_feedback(responses,p,ps, key,RDK)
%PRES_FEEDBACK calculate and display feedback for previous block
%   Returns Percentage hit, false alarms, and reaction time

WaitSecs(0.5);
%% calculate feedback
% get number of all events
t.num_presses=sum(cellfun(@(x) sum(sum(~isnan(x))),{responses.button_presses_t}));    % number of total button presse

% target number
summ.targnum = sum(cellfun(@(x) sum(x==1),{responses.eventtype}));
summ.distrnum = sum(cellfun(@(x) sum(x==1),{responses.eventtype}));

summ.hits = sum(cell2mat(cellfun(@(x) strcmpi(x,'hit'),{responses.event_response_type},'UniformOutput',false)));
summ.misses = sum(cell2mat(cellfun(@(x) strcmpi(x,'miss'),{responses.event_response_type},'UniformOutput',false)));
summ.CR = sum(cell2mat(cellfun(@(x) strcmpi(x,'CR'),{responses.event_response_type},'UniformOutput',false)));
summ.FA_proper = sum(cell2mat(cellfun(@(x) strcmpi(x,'FA_proper'),{responses.event_response_type},'UniformOutput',false)));
summ.FA = sum(cell2mat(cellfun(@(x) strcmpi(x,'FA'),{responses.event_response_type},'UniformOutput',false)));
summ.RT_mean = nanmean(cell2mat(arrayfun(@(x,y) x(y), cell2mat({responses.event_response_RT}),...
    cell2mat(cellfun(@(x) strcmpi(x,'hit'),{responses.event_response_type},'UniformOutput',false)),'UniformOutput',false)));
summ.RT_std = nanstd(cell2mat(arrayfun(@(x,y) x(y), cell2mat({responses.event_response_RT}),...
    cell2mat(cellfun(@(x) strcmpi(x,'hit'),{responses.event_response_type},'UniformOutput',false)),'UniformOutput',false)));



% behavioral effects separately for experimental conditions
for i_con = 1:2
    summ.targnum(1+i_con) = sum(cellfun(@(x,y) sum(x==1 & repmat((y==i_con),size(x))),...
        {responses.eventtype},{responses.cue}));
    summ.distrnum(1+i_con) = sum(cellfun(@(x,y) sum(x==2 & repmat((y==i_con),size(x))),...
        {responses.eventtype},{responses.cue}));
    summ.hits(1+i_con) = sum(cell2mat(cellfun(@(x,y) strcmpi(x,'hit') & repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)));
    summ.misses(1+i_con) = sum(cell2mat(cellfun(@(x,y) strcmpi(x,'miss') & repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)));
    summ.CR(1+i_con) = sum(cell2mat(cellfun(@(x,y) strcmpi(x,'CR') & repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)));
    summ.FA_proper(1+i_con) = sum(cell2mat(cellfun(@(x,y) strcmpi(x,'FA_proper') & repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)));
    summ.FA(1+i_con) = sum(cell2mat(cellfun(@(x,y) strcmpi(x,'FA') & repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)));
    summ.RT_mean(1+i_con) = nanmean(cell2mat(arrayfun(@(x,y) x(y),...
        cell2mat({responses.event_response_RT}), ... % reaction times for
        cell2mat(cellfun(@(x,y) strcmpi(x,'hit')& repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)),'UniformOutput',false))); % hits only
    summ.RT_std(1+i_con) = nanstd(cell2mat(arrayfun(@(x,y) x(y),...
        cell2mat({responses.event_response_RT}), ... % reaction times for
        cell2mat(cellfun(@(x,y) strcmpi(x,'hit')& repmat((y==i_con),size(x)),...
        {responses.event_response_type},{responses.cue},'UniformOutput',false)),'UniformOutput',false))); % hits only
end

% pixels for shift into 4 quadrants
quadshift = [p.scr_res(1)*(1/4) p.scr_res(2)*(1/4); p.scr_res(1)*(3/4) p.scr_res(2)*(1/4); ...
    p.scr_res(1)*(1/4) p.scr_res(2)*(3/4); p.scr_res(1)*(3/4) p.scr_res(2)*(3/4)];

%% presentation of results
% KbQueueCreate(ps.RespDev, keysOfInterest) %
% KbQueueStart(ps.RespDev);

% output to screen
t.textin = {...
    'All:                  ';...
    sprintf('RDK1 [%1.02f %1.02f %1.02f]:',RDK.RDK(1).col(1,1:3));
    sprintf('RDK2 [%1.02f %1.02f %1.02f]:',RDK.RDK(2).col(1,1:3))};
for i_con = 1:numel(summ.hits)
    fprintf(1,...
        ['\n%s Hitrate: %06.2f; Hits: %02.0f; Misses: %02.0f; CR: %02.0f; FA: [%02.0f %02.0f]; RT: M: %3.0f, Std: %3.0f ms'],...
        t.textin{i_con}, summ.hits(i_con)/summ.targnum(i_con)*100, summ.hits(i_con), summ.misses(i_con), ...
        summ.CR(i_con), summ.FA_proper(i_con),  summ.FA(i_con), summ.RT_mean(i_con), summ.RT_std(i_con))
end
fprintf('\nMit "q" geht es weiter.\n')


% draw text and stimuli (before shifting to the quadrants)
% offscreen window
[ps.offwin,ps.offrect]=Screen('OpenOffscreenWindow',p.scr_num, [0 0 0 0], [0 0 p.scr_res(1)/2 p.scr_res(2)/2], [], [], []);
% get center of offscreen window
[ps.xCenter_off, ps.yCenter_off] = RectCenter(ps.offrect);

text2present=                   [...                % text for feedback
    'P A U S E'...
    sprintf('\n\nHits = %1.0f; Hitrate = %1.2f%%',summ.hits(1), summ.hits(1)/summ.targnum(1)*100)...
    sprintf('\n\nReaktionszeit: M = %1.0fms, Std = %1.0fms',summ.RT_mean(1), summ.RT_std(1))...
    sprintf('\n\n\nMisses = %1.0f; Correct Rejections = %1.0f',summ.misses(1), summ.CR(1))...
    sprintf('\n\nFA_proper = %1.0f; FA = %1.0f',summ.FA_proper(1), summ.FA(1)	)...
    ];

% draw text
Screen('TextSize', ps.offwin, 18);
% DrawFormattedText(tx.instruct, INST.text{1}, tx.xCenter_off, p.scr_res(1)/2 * 0.1, p.stim_color);
DrawFormattedText(ps.offwin, text2present, 'center', p.scr_res(1)/2 * 0.2, p.crs.color);

for i_quad = 1:4 % shifst to quadrants
    newpos_stim(:,i_quad) = ...
        CenterRectOnPointd(ps.offrect,quadshift(i_quad,1),quadshift(i_quad,2))';
end
 
% [key.pressed, key.firstPress]=KbQueueCheck;
key.rkey=key.SECRET;
[key.keyisdown,key.secs,key.keycode] = KbCheck; 
while ~(key.keycode(key.rkey)==1)                       % continuously present feedback (wait for q)
    [key.keyisdown,key.secs,key.keycode] = KbCheck;
    Screen('DrawTextures', ps.window, repmat(ps.offwin,1,4),[], newpos_stim, [], [], [], []);
    Screen('Flip', ps.window, 0);                   % flip screen
end
try Screen('Close', ps.offwin); end


end

