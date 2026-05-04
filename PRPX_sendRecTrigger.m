function [] = PRPX_sendRecTrigger(Trig)
% function to start/stop EEG recording
%   sends start or stop trigger twice
%   and stops all schedules

if nargin <1, Trig = 'start'; end
switch lower(Trig)
    case 'start'
        code = 253;
    case 'stop'
        code = 254;
end
Datapixx('StopAllSchedules');
Datapixx('RegWrRd');
WaitSecs(1);
Datapixx('SetDoutValues', 0);
Datapixx('RegWrRd');
WaitSecs(0.01);
Datapixx('SetDoutValues', code); % send trigger
Datapixx('RegWrRd');
WaitSecs(0.01);
Datapixx('SetDoutValues', 0);
Datapixx('RegWrRd');
WaitSecs(0.01);
Datapixx('SetDoutValues', code); % send trigger again
Datapixx('RegWrRd');
WaitSecs(0.01);
Datapixx('SetDoutValues', 0);
Datapixx('RegWrRd');

end

