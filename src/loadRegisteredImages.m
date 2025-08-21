function imgs = loadRegisteredImages(folderPath)
%   imgs = loadRegisteredImages(folderPath) reads all images in the given 
%   folder with filenames of the form MM_YYYY and extensions .png, .jpg, .tif.
%   The images are returned as a cell array in sorted order.

    % Unterstützte Endungen
    exts = {'.png', '.jpg', '.jpeg', '.tif', '.tiff'};
    files = [];

    % Alle Dateien mit den Endungen sammeln
    for i = 1:numel(exts)
        files = [files; dir(fullfile(folderPath, ['*' exts{i}]))]; %#ok<AGROW>
    end

    if isempty(files)
        error('No image files found in folder: %s', folderPath);
    end

    % Sortiere nach Dateiname (damit Reihenfolge zeitlich stimmt: MM_YYYY)
    [~, idx] = sort({files.name});
    files = files(idx);

    % Einlesen
    imgs = cell(1, numel(files));
    for i = 1:numel(files)
        imgPath = fullfile(folderPath, files(i).name);
        imgs{i} = imread(imgPath);
    end

    fprintf('Loaded %d images from %s\n', numel(files), folderPath);
end
