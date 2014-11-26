function A = bilread(base)
%BILREAD Read a ESRI ArcGIS band-interleaved-by-line file
%
% Input variables:
%
%   base:   base name of files
%
% Output variables:
%
%   A:      1 x 1 structure with the following fields:
%
%           x:      x coordinates
%
%           y:      y coordinates
%
%           data:   data grid
%
%           cmap:   colormap (if .clr file found)

% Copyright 2013 Kelly Kearney

[pth, file, ext] = fileparts(base);
headerfile = fullfile(pth, [file '.hdr']);
colorfile = fullfile(pth, [file '.clr']);

%-----------------------
% Parse header file
%-----------------------

if ~exist(headerfile, 'file')
    error('Header file not found');
end

% Default values

Hdr.nrows = NaN;
Hdr.ncols = NaN;
Hdr.nbands = 1;
Hdr.nbits = 8;
Hdr.pixeltype = 'unsigned';
Hdr.byteorder = 'n'; % native
Hdr.layout = 'bil';
Hdr.skipbytes = 0;
Hdr.ulxmap = NaN;
Hdr.ulymap = NaN;
Hdr.xdim = NaN;
Hdr.ydim = NaN;
Hdr.bandrowbytes = NaN;
Hdr.totalrowbytes = NaN;
Hdr.bandgapbytes = 0;

% Read header file

fid = fopen(headerfile);
hdrdata = textscan(fid, '%s%s');
fclose(fid);

hdrdata = cat(2, hdrdata{:});
hdrdata(:,1) = lower(hdrdata(:,1));

ischar = ismember(hdrdata(:,1), {'pixeltype', 'byteorder', 'layout'});
hdrdata(~ischar,2) = cellfun(@str2num, hdrdata(~ischar,2), 'uni', 0);
hdrdata = hdrdata'; 

Hdr = parsepv(Hdr, hdrdata(:));

% Parse machine format

switch Hdr.byteorder
    case 'I'
        Hdr.byteorder = 'l';
    case 'M'
        Hdr.byteorder = 'b';
end

% Parse precision value

switch Hdr.pixeltype
    case 'unsigned'
        prec = sprintf('uint%d', Hdr.nbits);
    case 'signedint'
        prec = sprintf('int%d', Hdr.nbits);
    otherwise
        error('Unexpected pixeltype value');
end

% Parse grid variables

dimvars = [Hdr.ulxmap Hdr.ulymap Hdr.xdim Hdr.ydim];
if all(isnan(dimvars))
    Hdr.ulxmap = 0;
    Hdr.ulymap = Hdr.nrows - 1;
    Hdr.xdim = 1;
    Hdr.ydim = 1;
elseif any(isnan(dimvars))
    error('Missing dimension variable in header (ulxmap, ulymap, xdim, or ydim)');
end

% Parse file type

Hdr.layout = lower(Hdr.layout);

imagefile = fullfile(pth, [file '.' Hdr.layout]);
if ~exist(imagefile)
    error('Image file (%s) not found', imagefile);
end

%-----------------------
% Check for world file
%-----------------------

% x1 = Ax + By + C
% y1 = Dx + Ey + F
% 
% x1 = calculated x-coordinate of the pixel on the map
% y1 =  calculated y-coordinate of the pixel on the map
% x = column number of a pixel in the image
% y = row number of a pixel in the image
% A = x-scale; dimension of a pixel in map units in x direction
% B, D = rotation terms
% C, F = translation terms; x,y map coordinates of the center of the upper left pixel
% E = negative of y-scale; dimension of a pixel in map units in y direction

worldfile = fullfile(pth, [file '.blw']);
if exist(worldfile, 'file')
    wrld = load(worldfile); % ADBECF
    
    [x,y] = ndgrid(1:Hdr.nrows, 1:Hdr.ncols);
    A.x = wrld(1).*x + wrld(3).*y + wrld(5);
    A.y = wrld(2).*x + wrld(4).*y + wrld(6);
end

%-----------------------
% Read image data
%-----------------------

A.data = multibandread(imagefile, [Hdr.nrows Hdr.ncols Hdr.nbands], prec, Hdr.skipbytes, Hdr.layout, Hdr.byteorder);

%-----------------------
% Read color data
%-----------------------
    
colorfile = fullfile(pth, [file '.clr']);

if exist(colorfile, 'file')
    fid = fopen(colorfile);
    clr = textscan(fid, '%s', 'delimiter', '\n');
    fclose(fid);
    clr = clr{1};
    isdata = regexpfound(clr, '^[0-9]');
    clr = cellfun(@str2num, clr(isdata), 'uni', 0);
    A.cmap = cat(1, clr{:})./255;
end



