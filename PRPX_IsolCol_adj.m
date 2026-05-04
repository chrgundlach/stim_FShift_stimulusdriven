% function [AdjConditions]=PRPX_IsolCol_adj(Colors,TrialsPerCon,MaxStd,Shift,varargin);
%
% -Colors: rows with R/G/B values (max 1). Colors will be adjusted to first row.
% -TrialsPerCon: Number of repetitions for each color
% -Shift: displacement of ellipse from center in pixel e.g [-300 0 +421]
% - optional (varargin)
%       - size in pixel [x y], eg. [360 540] is default
%
% -Assumes psychtoolbox is initiated and ProPixx attached
% -runs with 120 Hz
% -only works in Linux
%   requires:
%               - PsychDefaultSetup(2);
%               - Datapixx('Open');
%               - Datapixx('SetPropixxDlpSequenceProgram', 0);
%               - Datapixx('RegWrRd');
% example call:
%   [AdjConditions]=PRPX_IsolCol_adj([0.03 0.03 0.03; 1 0 0; 0 0 1],5,20,[0 -300]);
%
% for troubleshooting: 
%   Colors = [0.2 0.2 0.2; 1 0 0; 0 0 1]; TrialsPerCon = 6;MaxStd = 15; Shift = [0 -300];
%   Colors = [0.2 0.2 0.2; 1 0 0]; TrialsPerCon = 6;MaxStd = 15; Shift = [0 -300];
%
% open points:_v2
%   - use more coloovalRectr values? done
%   - what to do with Screen('BlendFunction'
%
% (c) 2006,2008 - S.Andersen
% (c) 2018      - C.Gundlach  
function [AdjConditions]=PRPX_IsolCol_adj(Colors,TrialsPerCon,MaxStd,Shift,varargin)
sca
% psychtoolbox start screen in black (instead of white)
Screen('Preference', 'VisualDebugLevel', 1);

if nargin <5
    p.stim_size = [360 540];
else
    p.stim_size = varargin{1};
end

% get settings of screen
p.screen_num = max(Screen('Screens'));
p.screen = Screen('ConfigureDisplay', 'Scanout',p.screen_num, 0);

% check for violations
if any([p.screen.width~=1920, p.screen.height~=1080, p.screen.hz~=120])
    % set to 1920 * 1080 at 120 Hz
    try Screen('ConfigureDisplay', 'Scanout',p.screen_num, 0, 1920,1080,120);
        disp('...adjusting settings to 1920 X 1080 with 120 Hz...may take some while...')
        WaitSecs(10)
    catch
        fprintf(['!!!!\n...not able to adjust settings to 1920 X 1080 with 120 Hz!' ...
            '\ncurrent settings: %1.0f X %1.0f with %1.0f Hz\n!!!!\n'],...
            p.screen.width, p.screen.height, p.screen.hz)
    end
        
else
    disp('...settings are fine: 1920 X 1080 with 120 Hz')
end

% set up window
[p.window, p.windowRect] = PsychImaging('OpenWindow', p.screen_num, Colors(1,:));
Screen('ColorRange', p.window,1,0); % restrict colors to range of 0 to 1
Screen('BlendFunction', p.window,  GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
% Screen('BlendFunction', p.window,  GL_ONE, GL_ZERO); % no blending
[p.screenXpixels, p.screenYpixels] = Screen('WindowSize', p.window); % get window size
[p.xCenter, p.yCenter] = RectCenter(p.windowRect); % get center values of screen
Buttons = [KbName('Q') KbName('SPACE') KbName('n') KbName('m')];
RestrictKeysForKbCheck(Buttons); % allow input from all buttons
[SECRETkey, SPACEkey, Nkey, Mkey] = deal(...
    Buttons(1),Buttons(2),Buttons(3),Buttons(4));
ListenChar(-1) % block button presses to matlab; window STRG + C to exit and ListenChar(0) at end


% display start of isoluminance adjustment
key.keyisdown = 0;
while ~(key.keyisdown==1)            
    [key.keyisdown,key.secs,key.keycode] = KbCheck(-1);
    Screen('TextSize', p.window, 35);
    DrawFormattedText(p.window, 'Isoluminanzeinstellung','center', 'center', [1 1 1]);
    Screen('Flip', p.window, 0);
end

% start isoluminance adjustment
ShAdj=numel(Shift); % shifts to adjust
LumAdj=zeros((size(Colors,1)-1)*ShAdj,1); % luminance values to adjust
LumAdjMed = LumAdj;
Pos2Pre=repmat(Shift',size(Colors,1)-1,1); % positions to present
Col2Pre = []; % create matrix with color values
for i_col = 1:size(Colors,1)-1
    Col2Pre(end+1:end+ShAdj,:)=repmat(Colors(i_col+1,:),ShAdj,1);
end

while any(LumAdj==0)
    disp(' ');
    Tr2Rep=find(LumAdj==0); % which luminance adjustments to do?
    TotTrials=numel(Tr2Rep)*TrialsPerCon; % number of total trials
    ConOrd=Tr2Rep(1+mod(randperm(TotTrials),numel(Tr2Rep))); % randomize trial sequence
    for n1=1:TotTrials
        fprintf('\b%d\n',mod(n1,10));
        TmpCon=ConOrd(n1);
        TmpPos=sum(ConOrd(1:n1)==ConOrd(n1));
        % disp([Pos2Pre(TmpCon,:) TmpCon Col2Pre(TmpCon,:) TmpPos]) % troubleshooting
        TmpLumAdj(TmpCon,TmpPos)=DoHFP(Colors(1,:),Col2Pre(TmpCon,:),Pos2Pre(TmpCon,:),p);
    end
    %LumAdj(1)=DoHFP(Colors(1,:),Colors(2,:));
    %LumAdj(2)=DoHFP(Colors(1,:),Colors(3,:));
    LumAdj(Tr2Rep)=round(mean(TmpLumAdj(Tr2Rep,:),2));
    LumAdjStd=std(TmpLumAdj(:,:),1,2);
    LumAdjMed(Tr2Rep)=median(TmpLumAdj(Tr2Rep,:),2);
    LumAdjAvg=mean(TmpLumAdj(:,:),2);
    
    % set up text to be displayed
    Text2Disp = 'Eingestellte Bedingungen:';
    for n1=1:size(Col2Pre,1)
        Text2Disp = [Text2Disp '\n\n' sprintf('col [%1.1f %1.1f %1.1f], pos [%4.0f]:',Col2Pre(n1,:),Pos2Pre(n1)),...
            '   ' sprintf(' %5.1f',TmpLumAdj(n1,:)) sprintf(': MEAN(STD) = %5.2f(%5.2f), MEDIAN = %5.2f',...
            LumAdjAvg(n1),LumAdjStd(n1),LumAdjMed(n1))];
    end
    % display results
    if any(LumAdjStd>MaxStd)
        again = true;
        fprintf(1,['\n#############\nEinstellung muss wiederholt werden...\n' Text2Disp '\n#############\n'])
        fprintf(1,'\nODER den Geheimknopf druecken um mit den Median-Werten fortzufahren!\n')         
    else
        again = false;
        fprintf(1,['\n#############\nSehr gut!\n' Text2Disp '\n#############\n'])
    end
    WaitSecs(1);
    key.keyisdown = 0;
    while ~(key.keyisdown==1) % i.e. takes any of the response active keys
        [key.keyisdown,key.secs,key.keycode] = KbCheck(-1);
        Screen('TextSize', p.window, 24);
        Screen('TextFont', p.window, 'Courier');
        DrawFormattedText(p.window, Text2Disp,'center', 'center', [1 1 1]);
        Screen('Flip', p.window, 0);
        if key.keycode(SECRETkey) && again
            % scale the median values
            LumAdj = round(LumAdjMed);
        elseif ~key.keycode(SECRETkey) && again
            LumAdj(LumAdjStd>MaxStd)=0; % set adjusted luminance values to 0 for values higher than cutoff, running luminance adjustment over again 
        end
    end
end
AdjConditions=[Colors(1,:);ScaleLuminance(Col2Pre(1:end,:),LumAdj)];
ListenChar(0)
end

% ========== Subfunctions ==============
function [LumAdj]=DoHFP(ColFix,ColAdj,PosAdj,p) % heterochromatic flicker presentation
Keys=[KbName('n') KbName('m') KbName('Space')]; % [decreases luminance, increases luminance, select luminance]

% ellipse parameters
%XRad=p.screenXpixels*0.1875; % width of ellipse
%YRad=p.screenYpixels*0.5; % height of ellipse
FreqDiv=round(p.screen.hz/15); % frequency of 15
%disp(sprintf('Adjusting isoluminance at %3.1f Hz',p.screen.hz*100/FreqDiv/100));
ovalRect = [0 0 p.stim_size]; % create rectangular shape of oval [x_center y_center width height]
ovalRect_PosAdj = CenterRectOnPointd(ovalRect,p.xCenter + PosAdj, p.yCenter);

% fixation cross parameters
crs.xCoords         = [-10 10 0 0];
crs.yCoords         = [0 0 -10 10];
crs.allCoords       = [crs.xCoords; crs.yCoords];

Screen('Flip', p.window, 0); % show background
key.keycode(Keys(3))=1; % set keypress to 0
LumAdj=floor(rand*2560)/10; % set starting luminance to random value
FrameCounter=0;
StepSize=0.05;
ActivityCount=0;
key.keycode_prev = key.keycode;
% start present1ation, stop when space bar is pressed
while (~key.keycode(Keys(3)) && ~key.keycode_prev(Keys(3))) || key.keycode_prev(Keys(3))
    % check for button presses
    key.keycode_prev = key.keycode;
    key.keycode(Keys(3))=0;
    [key.keyisdown,key.secs,key.keycode] = KbCheck(-1);
    
    if any(key.keycode(Keys(1:2))) % has increase or decrease button been pressed?
        LumAdj=max([LumAdj-key.keycode(Keys(1))*StepSize 0]); % adjust luminance
        LumAdj=min([LumAdj+key.keycode(Keys(2))*StepSize 255]); % adjust luminance
        %disp(LumAdj)
        ActivityCount=round(p.screen.hz/5); % map button presses to adjust step size ActivityCount=round(p.screen.hz/5);
        StepSize=min([StepSize+0.005 1]); % adjust step size of color changes StepSize=min([StepSize+1 8]);
    else
        ActivityCount=max([ActivityCount-1 0]); % map button presses to adjust step size
        if ActivityCount==0
            StepSize=0.05; % set step size to minimum value if button wasn't pressed for a long time StepSize=2;
        end
    end
    % scale luminance value of color acording to set luminance value
    NewCol=ScaleLuminance(ColAdj,LumAdj); 
    
    % draw ellipse
    FrameCounter=mod(FrameCounter+1,FreqDiv); % according to on/off frequency
    if FrameCounter<(FreqDiv/2)
        OvalCol = [NewCol(1),NewCol(2),NewCol(3)]; % color of on frame
    else
        OvalCol = [ColFix(1),ColFix(2),ColFix(3)]; % color of off frame
    end
    Screen('FillOval', p.window, OvalCol, ovalRect_PosAdj) % actual drawing command
    
    % draw fixation cross
    Screen('DrawLines', p.window, crs.allCoords, 3, [0.8 0.8 0.8], [p.xCenter p.yCenter], 2);
    
    % trouble shooting display
%     Screen('TextSize', p.window, 20);
%     Screen('TextFont', p.window, 'Courier');
%     DrawFormattedText(p.window, ['\n\n\n\n' sprintf('%1.2f',StepSize) '\n' sprintf('%1.2f',LumAdj)],'center', 'center', [1 1 1]);
       
    Screen('Flip', p.window, 0); % show background
end
end

function [NewCol]=ScaleLuminance(Color,NewLum)
NewLum=NewLum(:);
NewCol=Color.*repmat(max(Color,[],2).*(NewLum/255),[1 3]);
end