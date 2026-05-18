% function [ Scr.ScrNum, screensize, xCenter, yCenter, window, framerate,...
%   RespDev, keymap, Scr.RefRate  ] = ScreenInit_GLSL( Scr, [0] )
%   making some standard screen preparations for visual stimulation
%   importantly, GLSL functionality is initialized here, make sure that the
%   graphics card is capable of it, otherwise the function may crash
%   input is a structure Scr with the following fields and a flag "onPRPX" indicating whether the ProPixx is the presenting device:
%       - PRPXres:      resolution of PRPX, should be [1920 1080]
%       - RefRate:      refresh rate, defaults to 120 Hz on PRPX and if not
%       specified
%       - BckGrCol:     displayed background color, defaults to black [0 0 0]
%       - ScrRes:       size of to be opened Psychtoolbox window; using a
%       resolution other than PRPXres on the ProPixx may result in strange
%       outputs!
%       - ScrNum:       number of screen where to open the Psychtoolbox
%       window
%       - PRPXmode:     Propixx presentation mode: 0 = 120 Hz; 4 = 480 Hz;
%       5 = 1440 Hz (grayscale only
% OUTPUT updates screennumber and refresh rate after checkups plus window
% properties, window handle and keyboard related information
%
% 2023 - N.Forschack: updated version that fixes text renderer to
%       Psychtoolbox library
%
function [ varargout ] = PTExpInit_GLSL( Scr , onPRPX)

fprintf('PSYCHTOOLBOX: adjusting video settings...requires some seconds')
AssertOpenGL
% PsychDefaultSetup(2); % magic, does: AssertOpenGL, execute KbName('UnifyKeyNames') and Screen('ColorRange', window, 1, [], 1)
% PsychImaging('PrepareConfiguration');% - Prepare setup of imaging pipeline for onscreen window.
% This is the first step in the sequence of configuration steps.

% defaults
if nargin < 2
    onPRPX = 0;
end
if ~isfield(Scr,'PRPXres')
    Scr.PRPXres = [1920 1080]; % this shouldn't be changed as its values can only be set up within propixx windows utility "vputil"
end
if ~isfield(Scr,'RefRate') || onPRPX
    Scr.RefRate = 120; % Hz
end
if ~isfield(Scr,'BckGrCol')
    Scr.BckGrCol = [0 0 0 1]; % black background, fully opaque
end
if ~isfield(Scr,'ScrRes')
    Scr.ScrRes = Scr.PRPXres;
end

% get number of available screens
if ~isfield(Scr,'ScrNum')
    Scr.ScrNum = [];
end
screens=Screen('Screens');
if isempty(Scr.ScrNum) || all(screens == 0)
    Scr.ScrNum=max(screens);
end
if ~isfield(Scr,'PRPXmode')
    Scr.PRPXmode = 0;
end
% Propixx
if onPRPX
    Datapixx('Open');
    Datapixx('SetPropixxDlpSequenceProgram', Scr.PRPXmode); % 2 for 480, 5 for 1440 Hz, 0 for normal (120Hz)
    Datapixx('RegWrRd');
end

% Query size of screen: 
% [screenXpixels, screenYpixels] = Screen('WindowSize', window); 
screensize=Screen('Rect', Scr.ScrNum);

% some keyboard settings
KbName('UnifyKeyNames')
keymap = zeros(1,256); % the keymap index vector for KbQueue function family

% adjust screen parameters if necessary, only possible on linux
if IsLinux 
    if ~all(screensize(1,3:4) == Scr.PRPXres) % to force a certain screen resolution on the Propixx
        Screen('ConfigureDisplay', 'Scanout', Scr.ScrNum, 0, Scr.PRPXres(1),Scr.PRPXres(2),Scr.RefRate); %'0' is the virtual screen output id?? sets up the target screen with prompted parameters
        WaitSecs(10); % allow screen changes to take place
        screensize=Screen('Rect', Scr.ScrNum);
    end
    % parallel port
    try ppdev_mex('Close', 1); % open triggerport
    catch me
        disp(me)
    end
    try ppdev_mex('Open', 2);  % open triggerport %%% new setup: changed from 1 to 2, to use old setup change back to 1
    catch me
        disp(me)
    end
    lptwrite(1,0); % ensure it's set to zero (solves the LPT-4-issue!)
%     RespDev = [];
    try
        % ask for keyboard default: PsychHID('devices',-1), returns default
        % response device index that changes after every system reboot
        % chicony elite == the EEG chambers default keyboard
        % RespDev = GetKeyboardIndices('Chicony HP Elite USB Keyboard',[],3); % either enter 'product' (name) | 'serialNumber' | locationID (did not changed after system restart (probably as long as usb plug won't change))
        RespDev = GetKeyboardIndices('CHERRY CHERRY Keyboard',[],3); % either enter 'product' (name) | 'serialNumber' | locationID (did not changed after system restart (probably as long as usb plug won't change))
        RespDev = RespDev(1);
    catch me
        disp(me)
        RespDev = -1;
    end
else
    RespDev = -1; % for KbQueueX functions this will indicate to use the default device
    
end
% choose text renderer
Screen('Preference','TextRenderer', 1); % force to use text renderer from Psychtoolbox library
%     Screen('DrawText', window, Screen('Preference','TextRenderer'))
% psychtoolbox start screen in black (instead of white)
Screen('Preference', 'VisualDebugLevel', 1);
% open a psychtoolbox window in background color
% window = Screen('OpenWindow', Scr.ScrNum, Scr.BckGrCol.*255); % 1 = main screen (0|2 -> main screen with menu bar|second monitor), color = 0 (white|[1 1 1 a]), rect = default (fullscreen|[0,0,width,height])
window = Screen('OpenWindow', Scr.ScrNum, Scr.BckGrCol.*255, [0,0,Scr.ScrRes]);
% get screen/window dimensions
screensize=Screen('Rect', window);
% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(screensize);
% clamping color range to 1 also has good effects on graphic card communication...sometimes
% Screen('ColorRange', window,1); 
Screen('ColorRange', window,1,[],1);
% set blending modes
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
% Make sure the GLSL shading language is supported:
AssertGLSL;

framerate=Screen('NominalFramerate', window); % in Hz
if framerate ~= Scr.RefRate
    warning('measured screen refresh rate of %s does not correspond to queried rate of %s...presentation assumes the latter.',num2str(framerate),num2str(Scr.RefRate))
    framerate= Scr.RefRate;
end

% block button presses to matlab window STRG + C to exit and ListenChar(0) at end
ListenChar(-1) % only suppress keypresses into Matlabs or Octaves command window, but not collect characters for use with CharAvail
% or GetChar; this command might interfere with KbQueue family
% ListenChar(2) % enables listening, additionally any output of keypresses to Matlabs or Octaves windows is suppressed
% commands
% set priority to high (1)
Priority(1); 

% structure output
varargout{1} = Scr.ScrNum;
varargout{2} = screensize;
varargout{3} = xCenter;
varargout{4} = yCenter;
varargout{5} = window;
varargout{6} = framerate;
varargout{7} = RespDev;
varargout{8} = keymap;
varargout{9} = Scr.RefRate;

fprintf('done!\n')
end

