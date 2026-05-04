function [] = plot_colorwheel(cols2plot,varargin)
%PLOT_COLORWHEEL Plots colors in CIE L*a*b colorwheel for illustration of hues and distances
%   input (required)
%       - cols2plot         triplet by color, e.g. [R1 G1 B1; R2 G2 B2]
%
%   input optional
%       requires 'key', value correspondance
%       - 'ColorSpace'      colorspace of cols2plot, currently supported:
%                           'sRGB','AdobeRGB','PROPixxRGB','XYZ','LAB'
%       - 'SavePath'        saves png, eps file in designate path with filename 'CIE_Lab_colorwheel'
%       - 'LAB_L'           L value of color wheel to be plotted. default is 75
%       - 'NumSegments'     number of color segments, i.e. color resolution of colorwheel default is 90
%       - 'AlphaColWheel'   alpha level of background color wheel default is 0.5
%       - 'LumBackground'   CIE L*a*b luminance of grey background default is 50
%
% C.Gundlach        2020

%% get input
if nargin < 1; help(mfilename), return, end

% extract input from varargin
p.possiblein={'ColorSpace','SavePath','LAB_L','NumSegments','AlphaColWheel','LumBackground'};
for i_inp = 1:length(p.possiblein)
    if ~isempty(varargin)&& any(strcmpi(varargin,p.possiblein{i_inp}))
        eval(['p.' p.possiblein{i_inp} ' = varargin{find(strcmpi(varargin,p.possiblein{i_inp}))+1};'])
    else
        eval(['p.' p.possiblein{i_inp} ' = [];'])
        
    end
end

%% prepare defaults
% colorspace
if isempty(p.ColorSpace)
    p.ColorSpace = 'sRGB';
elseif ~any(strcmpi(p.ColorSpace, {'sRGB','AdobeRGB','PROPixxRGB','XYZ','LAB'}))
    fprintf('!!! colorspace ''%s'' not supported, plese see function details:\n\n',p.ColorSpace)
    help(mfilename), return
end

% luminance of CIE LAB color space to be plotted
if isempty(p.LAB_L)
    p.LAB_L = 75;                                       % luminance of colors in CIE L*a*b space
end

% number of segments
if isempty(p.NumSegments)
    p.NumSegments = 90;                                 % number of color segments in color wheel
end

% color wheel alpha level
if isempty(p.AlphaColWheel)
    p.AlphaColWheel = 0.5;                               
end

% luminance of background grey
if isempty(p.LumBackground)
    p.LumBackground = 50;                               
end

p.figpos = [100 100 600 600];                           % size of figure
% p.figpos = [100 100 160 160];                         % size of figure
p.diamOut = round(1.0 * min(abs(diff(p.figpos,2,2))));  % diamater of donut
p.diamIn = round(0.25 * p.diamOut);                     % diamater of donut
p.diamOut_col = p.diamOut*1.8;                          % diameter of colors to be plotted --> they stick out
p.maskcol = lab2rgb([p.LumBackground 0 0]);             % greylevel of background



%% get color transforms of colors 2 plot
switch lower(p.ColorSpace)
    case 'srgb'
        cols2plot_lab = rgb2lab(cols2plot);
    case 'adobergb'
        cols2plot_lab = rgb2lab(cols2plot,'ColorSpace','Adobe');
    case 'propixxrgb'
        cols2plot_lab = xyz2lab(rgb2xyz_custom(cols2plot,[0.665 0.321], [0.172 0.726], [0.163 0.039], [0.3127 0.3290]));
    case 'xyz'
        cols2plot_lab = xyz2lab(cols2plot);
    case 'lab'
        cols2plot_lab = cols2plot;
end
cols2plot_lab_angle = atan2(cols2plot_lab(:,3),cols2plot_lab(:,2));
cols2plot_lab_angle(cols2plot_lab_angle<0) = 2*pi-abs(cols2plot_lab_angle(cols2plot_lab_angle<0));

%% start drawing procedure
[x, y] = meshgrid(-min(abs(diff(p.figpos,2,2))) : min(abs(diff(p.figpos,2,2))),...
    min(abs(diff(p.figpos,2,2))) :-1: -min(abs(diff(p.figpos,2,2)))); % get cartesian coordinates
[theta, rho] = cart2pol(x, y); % theta is the angle of the polar transfrom of the cartesian coordinates
theta(theta<0)=2*pi-abs(theta(theta<0));    % somehow has a different form than the conventional poloar coordinates --> taking care
                                            % is then in the range of [0 2*pi] and running counter clockwise from the right


% Set up color wheel for CIE L*a*b space.
hueImage = ceil(theta/ (2 * pi) * p.NumSegments) / p.NumSegments * (2 * pi);   % Quantize hue, restrict to number of colorsegments
cols2plot_lab_angle_rd = ceil(cols2plot_lab_angle/ (2 * pi) * p.NumSegments) / p.NumSegments * (2 * pi); % same for the colors to be printed


% calculate LAB color values for all unique hues for background circle
hue_unique = unique(hueImage);
hue_labcols = ([repmat(p.LAB_L,numel(hue_unique),1) ...
    repmat(p.LAB_L,numel(hue_unique),1).*cos(hue_unique) ...
    repmat(p.LAB_L,numel(hue_unique),1).*sin(hue_unique)]); % takses angles as hues of CIE L*a*b space and calculates CIE L*a*b colors

% hue_rgbcols = applycform(hue_labcols, makecform('lab2srgb')); % seems a bit off, value-wise
hue_rgbcols = lab2rgb(hue_labcols); % transfer back to rgb space for plotting
hue_rgbcols(hue_rgbcols<0)=0; hue_rgbcols(hue_rgbcols>1)=1; % scales values larger than 0 to 1 and smaller than 0 to 0


% Make it have the wheel shape.
% Make a mask 1 in the wheel, and 0 outside the wheel.
wheelMaskImage = rho >= ceil(p.diamIn/2) & rho <= ceil(p.diamOut/2);
wheelMaskCols = rho >= ceil(p.diamIn/2) & rho <= ceil(p.diamOut_col/2); % colors to be plotted stick out a bit

rgbimage = nan([size(hueImage) 3]); % colorwheel image
rgbimage_alpha = nan(size(hueImage)); % alpha map for later overlay of col2plot
rgbimage_col = rgbimage; % colorwheel image of col2plot

% loop through each coordinate
for i_x = 1:size(hueImage,1)
    for i_y = 1:size(hueImage,2)
        % check for color wheel: background color if not in wheel area
        if wheelMaskImage(i_x,i_y)
            rgbimage(i_x,i_y,:) = hue_rgbcols(hue_unique==hueImage(i_x,i_y),:);
        else
            rgbimage(i_x,i_y,:) = p.maskcol;
        end
        % check for cols2plot: background color and alpha 0 if not in cols2plot area
        if wheelMaskCols(i_x,i_y)
            rgbimage_col(i_x,i_y,:) = hue_rgbcols(hue_unique==hueImage(i_x,i_y),:); % creates larger colorwheel
            if any(cols2plot_lab_angle_rd == hueImage(i_x,i_y)) % only alpha for segment of cols2plot is 1
                rgbimage_alpha(i_x,i_y) = 1;
            end
        else
            rgbimage_alpha(i_x,i_y) = 0;
            rgbimage_col(i_x,i_y,:) = p.maskcol;
        end
    end
end


% actual drawing
figure;
set(gcf,'Position',p.figpos,'PaperPositionMode','auto')
h1 = imshow(rgbimage); % plots colorwheel
hold on
h2 = imshow(rgbimage_col); % plots color to be plotted as larger overlay
set(h1, 'AlphaData', p.AlphaColWheel); % sets alpha of color wheel to 0.5
set(h2, 'AlphaData', rgbimage_alpha); % only shows color2 to be plotted

% optional saving figure
if ~isempty(p.SavePath)
    filename = 'CIE_Lab_colorwheel';
    fprintf('...saving files %s [.png, .fig, .eps]\n',fullfile(p.SavePath,filename))
    print(gcf, fullfile(p.SavePath,filename),'-dpng','-r300')
    saveas(gcf,fullfile(p.SavePath,filename),'fig')
    print(gcf,fullfile(p.SavePath,filename),'-depsc2', '-painters','-r300')
    fprintf('...done!\n')
end



% %% start drawing procedure
% p.grey = 0.8;
% figure;
% set(gcf,'Position',p.figpos,'PaperPositionMode','auto')
% 
% [x, y] = meshgrid(-p.diamOut : p.diamOut);
% [theta, rho] = cart2pol(x, y); % theta is an image here.
% 
% % Set up color wheel in hsv space.
% hueImage = (theta + pi) / (2 * pi);     % Hue is in the range 0 to 1.
% hueImage = ceil(hueImage * p.NumSegments) / p.NumSegments;   % Quantize hue 
% saturationImage = ones(size(hueImage));      % Saturation (chroma) = 1 to be fully vivid.
% 
% % Make it have the wheel shape.
% % Make a mask 1 in the wheel, and 0 outside the wheel.
% wheelMaskImage = rho >= ceil(p.diamIn/2) & rho <= ceil(p.diamOut/2);
% % Hue and Saturation must be zero outside the wheel to get gray.
% hueImage(~wheelMaskImage) = 0;
% saturationImage(~wheelMaskImage) = 0;
% % Value image must be 1 inside the wheel, and the normalized gray level outside the wheel.
% valueImage = ones(size(hueImage)); % Initialize to all 1
% valueImage(~wheelMaskImage) = p.grey;	% Outside the wheel = the normalized gray level.
% 
% % Combine separate h, s, and v channels into a single 3D hsv image.
% hsvImage = cat(3, hueImage, saturationImage, valueImage);
% % Convert to rgb space for display.
% rgb = hsv2rgb(hsvImage);
% 
% % Display the final color wheel.
% imshow(rgb);


end

