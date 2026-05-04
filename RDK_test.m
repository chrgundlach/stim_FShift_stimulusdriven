%RDK
% INFO
% The functions used here work for ELLIPSE RDKs with SQUARE & CIRCLE dots, for 120
% and 480Hz.
% Uses Screen('DrawDots') as drawing function: http://psychtoolbox.org/docs/Screen-DrawDots.
% Sizes are processed in pixel; Keep in mind that the resultion for 480Hz
% is 1/4 (half the width and half the height) of 120Hz, thus stimuli with
% the same pixel values, will appear different in size on the projector screen.
% Work with even pixel values, a lot of sizes will be devided in half for drawing purposes etc.

% ToDos: 
% make a run_RDK script, that calls the different functions; in RDK script, propixx setup and parameter definition
% put default and input values (nargin stuff)
% are dots allowed to overlap?
% function for square RDK, function with textures, function with drawlines for bars

%% Screen init
clear all;
addpath(genpath('/home/pc/matlab/user/maria/RDK'));
scr.screen = 1;
scr.res = [1920 1080];
scr.refrate = 480;                  % 120 or 480; 480Hz will automatically setup the ProPixx multimode
scr.background_col = [0 0 0];

[scr] = exp_setup_RDK(scr);

%% Parameters

%RDK definition: define n RDKs by adding elements to the RDK structure array with the same fields i.e RDK(1), RDK(2), ..., RDK(n)

RDK(1).size            = [360 360];                % width and height of RDK in pixel; only even values 
RDK(1).centershift     = [0 0];                  % position of RDK center; x and y deviation from center in pixel
RDK(1).col             = [0 1 0; 0 0 0];           % "on" and "off" color
RDK(1).freq            = 30;                       % flicker frequency, frequency of a full "on"-"off"-cycle
RDK(1).mov_freq         = 120;                        % Defines how frequently the dot position is updated; 0 will adjust the update-frequency to your flicker frequency (i.e. dot position will be updated with every "on"-and every "off"-frame); 120 will update the position for every frame for 120Hz or for every 1. quadrant for 480Hz 
 
RDK(2).size            = RDK(1).size;                
RDK(2).centershift     = RDK(1).centershift;                  
RDK(2).col             = [0 0.4 1; 0 0 0];          
RDK(2).freq            = 24;
RDK(2).mov_freq         = RDK(1).movfreq;     

RDK(3).size            = RDK(1).size;              
RDK(3).centershift     = RDK(1).centershift;                   
RDK(3).col             = [1 0.4 0; 0 0 0];          
RDK(3).freq            = 20;
RDK(3).mov_freq         = RDK(1).movfreq;

dot.size            = 6;                       % dotz size in pixel; with DrawDots it is only possible to specify same value for width/height i.e. making circles/squares; only even values
dot.type            = 0;                        % dot shape; 1 = round, 0 = rectengular
dot.number          = 100;                      % number of dots
dot.dir             = [-1 1;-1 1];              % movement direction of the dot cloud [x;y]; [-1 1; -1 1] allows movement to both x and y directions %ToDo: Why is there no 0 movement allowed?
dot.movstep         = 1;                        % pixel step that dot can make when position is updated (position is updated for every "on" and "off" frame)

trial.duration      = 10;%1.25+2;                        % duration of the RDK in seconds
trial.cueons        = 1.25;
trial.ITI           = 1.7;
trial.eventwindow   = []; %ToDo: probably synchronized to flicker freq

cross.col           = [1 1 1];                  % fixation cross color
cross.cuecol        = [];                       % ToDo: add cue color
cross.size          = [2 14];                   % width and length of fixation cross bar; only even values
cross.cutout        = 0;                        % 1: forbid overlap of dots and fixcross; 0: no cutout

%% Prepare some positions

scr.center = [scr.xCenter scr.yCenter];
cross.half = cross.size(2)/2;
cross.bars = [-cross.half cross.half 0 0; 0 0 -cross.half cross.half]; % 'DrawLines' needs a two dimensional vector of x coordinates and y coordinates of start end end points of all lines i.e. [x1start x1stop ... xNstart xNstop; y1start y1stop ... yNstart yNstop]

% prepare normal video processing (120Hz) or the QUAD4X mode (480Hz) and fixation cross
switch scr.refrate
    case 480
        Propixx = 4;
        scr.shift = [-scr.xCenter/2, -scr.yCenter/2; scr.xCenter/2, -scr.yCenter/2;... % shifts to four quadrants: upper left, upper right, lower left, lower right
            -scr.xCenter/2, scr.yCenter/2; scr.xCenter/2, scr.yCenter/2];
        
        cross.lines = [];
        for p=1:Propixx
        cross.lines = cat(2, cross.lines, [cross.bars(1,:)+scr.shift(p,1); cross.bars(2,:)+scr.shift(p,2)]); %array with start and end points for the fixation cross lines, for all four quadrants
        end
 
    case 120
        Propixx = 1;
        cross.lines = cross.bars;
end


%% Initialize RDK
% initialize variables %ToDo: fix: is this necessary? put it elsewhere?
[RDK(:).rad_x] =  deal(zeros(1,length(RDK))); 
[RDK(:).rad_y] = deal(zeros(1,length(RDK))); 

[colmat,dotmat,rdkidx,RDK,cross,frames] = RDK_init(scr,Propixx,RDK,trial,dot,cross);

%% frame loop
% initialize structure for timing checks %ToDo: Clean this later
timing = struct('VBLTimestamp',NaN(1,frames.pertrial),'StimulusOnsetTime',NaN(1,frames.pertrial),'FlipTimestamp',NaN(1,frames.pertrial),'Missed',NaN(1,frames.pertrial));
time1 = GetSecs();

for fl = 1:frames.flips 
    % Drawing         
    Screen('DrawDots', scr.window, dotmat(:,:,fl), dot.size, colmat(:,:,fl), scr.center, dot.type, 0);
    Screen('DrawLines', scr.window, cross.lines, cross.size(1), cross.col', scr.center, 0);

    %ToDo: Add triggers and scheduler

    % Flip
    [timing.VBLTimestamp(fl), timing.StimulusOnsetTime(fl), timing.FlipTimestamp(fl), timing.Missed(fl)] = Screen('Flip', scr.window, 0);
end
time2=GetSecs();
%% timing plots

figure;
% VBLTimestamp: plot time when buffer swap/vertical blanking starts, image is "sent" to graphics buffer
subplot(3,2,1); plot(diff(timing.VBLTimestamp));title('diff VBLTimestamp','FontSize',8)
% StimulusOnsetTime: actual time when actual first scanline is started, image is started to be drawn on screen/beamer; VBLTimestamp + constant VBL time
subplot(3,2,2); plot(diff(timing.StimulusOnsetTime));title('diff StimulusOnsetTime','FontSize',8)
% FlipTimestamp:  timestamp taken at the end of Flip's execution, estimate of how long flip took
subplot(3,2,3); plot(diff(timing.FlipTimestamp));title('diff FlipTimestamp','FontSize',8)
% difference is an estimate of systems jitter: high values are bad...
subplot(3,2,4); plot(timing.FlipTimestamp-timing.VBLTimestamp); title('diff FlipTimestamp-VBLTimestamp | 1/refresh rate','FontSize',8)
% Missed: compares VBLTimeStamp against the requested timestamp of when bufferswap should happen (depending on refrate etc.) 1.05*estimate = missed
subplot(3,2,5); plot((timing.Missed));title('Missed | negative = cool; positive = miss','FontSize',8);

%ToDo: remove after testing
timediff = time2-time1;