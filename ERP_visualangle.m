
% function [ext_width ext_height]=visualangle([pix],[dist],[res1 res2],[width height],visangle)
% pix       = (2D) Gr��e des Objektes in Pixeln
% dist      = Abstand der Vp zum Monitor in cm
% res       = Aufl�sung des Bildschirms in Pixeln (Breite x H�he, default: Full-HD)
% screen    = Gr��e des Bildschirms in cm (Breite x H�he, default: 63.5 x 36 cm)
% visangl   = indicate whether pix input is in visual angles (default = 0)
%
% OUTPUT:
%   ext_width  = width of visual object in degree visual angle (va=0) or pixel (va=1) 
%   ext_height = height of visual object in degree visual angle (va=0) or pixel (va=1)
%
% 2018, added second object size dimension and inverse input/output
% (c) 2010, Norman Forschack

function [a,b]=ERP_visualangle(pix,dist,res,screen,va)
if nargin<2, help(mfilename), return, end
if nargin<3, [res(1),res(2)]=deal(1920,1080);[width, height]=deal(63.5,36); va=0; 
elseif nargin==3, [width,height]=deal(63.5,36); va=0;
elseif nargin<5, [width,height]=deal(screen(1),screen(2)); va=0; 
else, [width,height]=deal(screen(1),screen(2));
end
if numel(pix)==1, pix=repmat(pix,1,2); end
switch va
    case 0
        disp('===Computing visual angle===')
        a=180/pi*atan((pix(1)*width/res(1))/(dist)); % can be done in one line, two lines just to illustrate the formula better
        b=180/pi*atan((pix(2)*height/res(2))/(dist));
    case 1
        disp('===Computing range in pixel===')
        a=res(1)*dist*tan(pix(1)*pi/180)/width;
        b=res(2)*dist*tan(pix(2)*pi/180)/height;
end