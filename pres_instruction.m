function [] = pres_instruction(p,ps,RDK,blocknum,randmat,con_flag, key, flag_traintype)
%PRES_INSTRUCTION present instructions
%   p           = parameters
%   ps          = screen parameters

%% initial parameters
INST.flag =                 {'TRAINING';'EXPERIMENT'};

% with pre-cue task
% INST.text{1} =              [...                % text for training
%     sprintf('TRAINING - block %1.0f',blocknum)...
%     '\n\n\nBitte fixieren Sie kontinuierlich das Fixationskreuz!'...
%     '\n\nReagieren Sie sobald einer der Balken des Kreuzes kürzer wird'...
%     '\nmit einem Druck auf die Leertaste.'...
%     '\n\nSobald das Fixationskreuz die Farbe ändert, achten Sie auf die'...
%     '\nangezeigten Punktewolken. Wenn sich ein Teil der beachteten'...
%     '\nPunkte kurz kohärent in eine Richtung bewegt, drücken Sie'...
%     '\ndie Leertaste. Seien Sie dabei so schnell wie möglich.'...
%     sprintf('\n\nNutzen Sie für die Antworten die %s Hand.', randmat.mats.responsehand{find(randmat.mats.block==1,1,'first')})
%     ];
% INST.text{2} =              [...                % text for experiment
%     sprintf('EXPERIMENT - Block %1.0f von %1.0f',blocknum,p.stim.blocknum)...
%     '\n\n\nBitte fixieren Sie kontinuierlich das Fixationskreuz!'...
%     '\n\nReagieren Sie sobald einer der Balken des Kreuzes kürzer wird'...
%     '\nmit einem Druck auf die Leertaste.'...
%     '\n\nSobald das Fixationskreuz die Farbe ändert, achten Sie auf die'...
%     '\nangezeigten Punktewolken. Wenn sich ein Teil der beachteten'...
%     '\nPunkte kurz kohärent in eine Richtung bewegt, drücken Sie'...
%     '\ndie Leertaste. Seien Sie dabei so schnell wie möglich.'...
%     sprintf('\n\nNutzen Sie für die Antworten die %s Hand.', randmat.mats.responsehand{find(randmat.mats.block==blocknum,1,'first')})
%     ];

% without pre-cue task
% training or experiment
if con_flag == 1 % training
    INST.FirstLine = sprintf('%s - block %1.0f', INST.flag{1}, blocknum);
    INST.idx = 1;
elseif con_flag == 0 % experiment
    INST.FirstLine = sprintf('%s - Block %1.0f von %1.0f', INST.flag{2},blocknum,p.stim.blocknum);
    INST.idx = 2;
end

% RDK task
INST.text{1} =              [...                % text for RDK task
    sprintf('%s', INST.FirstLine)...
    '\n\n\nPUNKTEWOLKENAUFGABE' ...
    '\n\n\nBitte fixieren Sie kontinuierlich das Fixationskreuz!'...
    '\n\nAchten Sie auf die weiße Punktewolke in der Mitte des Bildschirms.'...
    '\nWährend eines Durchgangs kann sich ein Teil der Punkte kurz kohärent'...
    '\nin eine Richtung bewegen. Drücken sie so schnell wie möglich <L> wenn'...
    '\ndie Bewegungsrichtung links oder rechts ist und <S> wenn die Bewegung' ...
    '\nnach oben oder unten erfolgt.'...
    ];
% rectangle task
INST.text{2} =              [...                % text for rectangle task
    sprintf('%s', INST.FirstLine)...
    '\n\n\nRECHTECKAUFGABE' ...
    '\n\n\nBitte fixieren Sie kontinuierlich das Fixationskreuz!'...
    '\n\nAchten Sie auf das farbige Rechteck in der Mitte des Bildschirms.'...
    '\nWährend eines Durchgangs kann das Rechteck kurz kleiner werden.'...
    '\nDrücken sie so schnell wie möglich <S>, wenn die Verkleinerung nur eine'...
    '\nSeite betrifft: oben, unten, links oder rechts. Drücken Sie <L>,' ...
    '\nwenn die Veränderung gleichzeitig an gegenüberliegenden Seiten stattfindet:' ...
    '\noben UND unten oder links UND rechts.'...
    ];

INST.TASK = {'PUNKTEWOLKENAUFGABE';'RECHTECKAUFGABE'};

% position of fixation cross
% INST.crs.xCoords =          [-p.crs_dims(1) p.crs_dims(1) 0 0];
% INST.crs.yCoords =          [0 0 -p.crs_dims(2) p.crs_dims(2)];
% INST.crs.allCoords =        [INST.crs.xCoords; INST.crs.yCoords];
% INST.crs.offset =           [0 180; 0 280]; % [x y] offset of cue cross

% pixels for shift into 4 quadrants
quadshift = [p.scr_res(1)*(1/4) p.scr_res(2)*(1/4); p.scr_res(1)*(3/4) p.scr_res(2)*(1/4); ...
    p.scr_res(1)*(1/4) p.scr_res(2)*(3/4); p.scr_res(1)*(3/4) p.scr_res(2)*(3/4)];

%% create fixation cross
ps.center = [ps.xCenter ps.yCenter];
% p.crs.half = p.crs.dims/2;
% p.crs.bars = [-p.crs.half p.crs.half 0 0; 0 0 -p.crs.half p.crs.half];
% 
% posshift1 = [repmat(-610,1,4); repmat(-200,1,4)];
% posshift2 = [repmat(-610,1,4); repmat(-180,1,4)];
% posshift3 = [repmat(-610,1,4); repmat(-160,1,4)];
% 
% p.crs.lines = {};
% t.lines = [];
% t.bars1 = p.crs.bars + posshift1 ;
% t.bars2 = p.crs.bars + posshift2 ;
% t.bars3 = p.crs.bars + posshift3 ;


%% present text in quadrants
% draw text and stimuli (before shifting to the quadrants)
% offscreen window
[ps.offwin,ps.offrect]=Screen('OpenOffscreenWindow',p.scr_num, [0 0 0 0], [0 0 p.scr_res(1)/2 p.scr_res(2)/2], [], [], []);
% get center of offscreen window
[ps.xCenter_off, ps.yCenter_off] = RectCenter(ps.offrect);

% draw instruction text
Screen('TextSize', ps.offwin, 14);
% DrawFormattedText(tx.instruct, INST.text{1}, tx.xCenter_off, p.scr_res(1)/2 * 0.1, p.stim_color);
DrawFormattedText(ps.offwin, INST.text{flag_traintype}, 'center', p.scr_res(1)/2 * 0.1, p.crs.color);

% draw text, how to start trial
DrawFormattedText(ps.offwin, 'Mit LEERTASTE geht es los!', 'center', p.scr_res(2)/2 * 0.85, p.crs.color);


for i_quad = 1:4 % shifst to quadrants
    newpos_stim(:,i_quad) = ...
        CenterRectOnPointd(ps.offrect,quadshift(i_quad,1),quadshift(i_quad,2))';
end

% show info outside
fprintf('\nVersuchsperson startet %s %s Block %1.0f mit Leertaste...', INST.TASK{flag_traintype}, INST.flag{INST.idx},blocknum)

% [key.pressed, key.firstPress]=KbQjueueCheck;
key.rkey=key.SPACE;
[key.keyisdown,key.secs,key.keycode] = KbCheck; 
while ~(key.keycode(key.rkey)==1)                       % continuously present feedback (wait for q)
    [key.keyisdown,key.secs,key.keycode] = KbCheck;
    % draw text
    Screen('DrawTextures', ps.window, repmat(ps.offwin,1,4),[], newpos_stim, [], [], [], []);
    Screen('Flip', ps.window, 0);                   % flip screen
end
try Screen('Close', ps.offwin); end



%% alert before experiment starts
[ps.offwin,ps.offrect]=Screen('OpenOffscreenWindow',p.scr_num, [0 0 0 0], [0 0 p.scr_res(1)/2 p.scr_res(2)/2], [], [], []);
% get center of offscreen window
[ps.xCenter_off, ps.yCenter_off] = RectCenter(ps.offrect);

% draw instruction text
Screen('TextSize', ps.offwin, 14);
DrawFormattedText(ps.offwin, 'Gleich geht es los.','center','center', p.crs.color);
for i_quad = 1:4 % shifst to quadrants
    newpos_stim(:,i_quad) = ...
        CenterRectOnPointd(ps.offrect,quadshift(i_quad,1),quadshift(i_quad,2))';
end
Screen('DrawTextures', ps.window, repmat(ps.offwin,1,4),[], newpos_stim, [], [], [], []);
Screen('Flip', ps.window, 0);
fprintf('Block beginnt!\n')
t=WaitSecs(2);
try Screen('Close', ps.offwin); end

end

