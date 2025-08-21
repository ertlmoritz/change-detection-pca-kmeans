function [fullChangeMaps, fullBorderMask, cumChanges, relGrowthPerStep] = changeDetectionPCAKMeans(imgs, scene, varargin)
%   Unsupervised change detection using PCA and K-Means clustering
%   Based on: T. Celik, "Unsupervised Change Detection in Satellite Images Using
%   Principal Component Analysis and k-Means Clustering," IEEE GRSL, 6(4):772–776, 2009.
%
%   Inputs:
%     imgs       : Cell array of RGB images (already registered)
%     scene      : 'urbanization' | 'deforestation' | 'glacier melting' | 'desiccation' | 'general'
%   Name-Value Pairs:
%     'folderPath' : Path to save output GIF (default: '')
%     'h'          : Block size for PCA (default: 2)
%     'S'          : # principal components (default: 3, must be <= h^2)
%     'doPlot'     : show overlays (default: false)
%     'doGraph'    : plot cumulative curve (default: false)
%     'delayTime'  : GIF delay per frame [s] (default: 1.0)
%
%   Outputs:
%     fullChangeMaps    : Cell array of binary change masks (full image size)
%     fullBorderMask    : Number of valid pixels in analysis area
%     cumChanges        : Cumulative change ratio per time step
%     relGrowthPerStep  : Incremental growth (difference of cumChanges)

    % --- Parse inputs
    p = inputParser; p.FunctionName = mfilename;
    p.addRequired('imgs', @(x) iscell(x) && ~isempty(x));
    p.addRequired('scene', @(x) ischar(x)||isstring(x));
    p.addParameter('folderPath','', @(x) ischar(x)||isstring(x));
    p.addParameter('h',2, @(x) isnumeric(x)&&isscalar(x)&& x>0);
    p.addParameter('S',3, @(x) isnumeric(x)&&isscalar(x)&&x>0);
    p.addParameter('doPlot',false, @(x) islogical(x)&&isscalar(x));
    p.addParameter('doGraph',false, @(x) islogical(x)&&isscalar(x));
    p.addParameter('delayTime',1.0, @(x) isnumeric(x)&&isscalar(x)&&x>=0);
    p.parse(imgs, scene, varargin{:});

    imgs       = p.Results.imgs;
    folderPath = char(p.Results.folderPath);
    scene      = char(p.Results.scene);
    h          = p.Results.h;
    S          = p.Results.S;
    doPlot     = p.Results.doPlot;
    doGraph    = p.Results.doGraph;
    delayTime  = p.Results.delayTime;
    makeGif    = ~isempty(folderPath);

    if S > h^2
        error('S (%d) must not exceed h^2 (%d).', S, h^2);
    end

    % --- Preprocess / valid area
    origCell = imgs; nImgs = numel(origCell);
    grayCell = cell(1,nImgs);
    for k = 1:nImgs
        grayCell{k} = im2double(rgb2gray(origCell{k}));
    end
    maskAll = true(size(grayCell{1}));
    for k = 1:nImgs
        maskAll = maskAll & (grayCell{k} > 0);
    end
    [r,c] = find(maskAll);
    rmin = min(r); rmax = max(r);
    cmin = min(c); cmax = max(c);
    border = 15;

    cropColor = cell(1,nImgs);
    cropGray  = cell(1,nImgs);
    for k = 1:nImgs
        cropColor{k} = origCell{k}(rmin:rmax, cmin:cmax, :);
        cropGray{k}  = grayCell{k}(rmin:rmax, cmin:cmax);
    end
    maskC = maskAll(rmin:rmax, cmin:cmax);
    maskC([1:border,end-border+1:end], :) = false;
    maskC(:, [1:border,end-border+1:end]) = false;

    % Keep: nValidPixels for metrics; borderMask if you ever want to draw a frame
    nValidPixels = nnz(maskC);
    borderMask   = bwperim(maskC); % (not drawn in GIF anymore)

    % --- Containers
    changeMapsRaw = cell(1,nImgs-1);
    satMasks      = cell(1,nImgs-1);
    valueMasks    = cell(1,nImgs-1);
    variMasks     = cell(1,nImgs-1);
    blueMasks     = cell(1,nImgs-1);

    % --- Process pairs
    for i = 2:nImgs
        fprintf('=== Processing pair %d vs %d ===\n', i, i-1);
        idx = i-1;

        % Difference
        tDiff = tic;
        D = abs(cropGray{i} - cropGray{i-1});
        D(~maskC) = 0;

        % Scene-specific masks / thresholds
        switch scene
            case 'general'
                thr = 0.12; D(D < thr) = 0;
                fprintf('Pair %d: diff computation: %.4f s\n', idx, toc(tDiff));
            case 'urbanization'
                thr = 0.08; D(D < thr) = 0;
                fprintf('Pair %d: diff computation: %.4f s\n', idx, toc(tDiff));
                satMasks{idx} = bwareaopen(computeSaturationMask(cropColor{i}, maskC, 0.30), 50);
            case 'deforestation'
                thr = 0.10; D(D < thr) = 0;
                fprintf('Pair %d: diff computation: %.4f s\n', idx, toc(tDiff));
                variMasks{idx} = computeVARIMask(cropColor{idx}, maskC, 0.1);
            case 'glacier melting'
                thr = 0.10; D(D < thr) = 0;
                fprintf('Pair %d: diff computation: %.4f s\n', idx, toc(tDiff));
                valueMasks{idx} = computeValueMask(cropColor{idx}, maskC, 0.60);
            case 'desiccation'
                thr = 0.10; D(D < thr) = 0;
                fprintf('Pair %d: diff computation: %.4f s\n', idx, toc(tDiff));
                blueMasks{idx} = computeBlueMask(cropColor{idx}, maskC);
        end

        % Blocks
        tBlock = tic;
        B = extractBlocksFast(D, h);
        fprintf('Pair %d: extractBlocksFast: %.4f s\n', idx, toc(tBlock));

        % PCA
        tPCA = tic;
        [E, mu] = pcaCovariance(B, S);
        fprintf('Pair %d: pcaCovariance: %.4f s\n', idx, toc(tPCA));

        % Features
        tFeat = tic;
        [F, pos] = computeFeaturesFast(D, h, E, mu);
        fprintf('Pair %d: computeFeaturesFast: %.4f s\n', idx, toc(tFeat));

        % K-Means → binary map
        tKM = tic;
        cm = kmeansChangeMap(F, pos, D);
        fprintf('Pair %d: kmeansChangeMap: %.4f s\n', idx, toc(tKM));

        % Apply masks
        tMask = tic;
        cm(~maskC) = 0;
        switch scene
            case "urbanization"
                cm(~satMasks{idx}) = 0;
            case "deforestation"
                cm(~variMasks{idx}) = 0;
            case "glacier melting"
                cm(valueMasks{idx}) = 0;
            case "desiccation"
                cm(~blueMasks{1}) = 0;   
        end

        changeMapsRaw{idx} = cm;
        fprintf('Pair %d: masking and clean-up: %.4f s\n', idx, toc(tMask));
    end

    % --- Build cumulative-by-step (only newly added pixels per step)
    cumMask = false(size(cropGray{1}));
    changeMaps = cell(1,nImgs-1);
    for k = 1:nImgs-1
        cm = changeMapsRaw{k};
        cm(cumMask) = 0;
        changeMaps{k} = cm;
        cumMask = cumMask | cm;
    end

    % --- Expand to full size
    [H_full, W_full, ~] = size(origCell{1});
    fullChangeMaps = cell(size(changeMaps));
    for k = 1:numel(changeMaps)
        bigMask = false(H_full, W_full);
        bigMask(rmin:rmax, cmin:cmax) = changeMaps{k};
        fullChangeMaps{k} = bigMask;
    end

    % --- Metrics
    [cumChanges, relGrowthPerStep] = plotCumulativeChange(fullChangeMaps, nValidPixels, doGraph);

    % Expose number of valid pixels as documented output
    fullBorderMask = nValidPixels;

    % --- Optional overlays
    if doPlot
        for i=2:nImgs
            figure; imshow(origCell{i}); hold on;
            overlay = cat(3, ones(size(fullChangeMaps{i-1})), zeros(size(fullChangeMaps{i-1})), zeros(size(fullChangeMaps{i-1})));
            hImg = imshow(overlay);
            set(hImg,'AlphaData',0.3*fullChangeMaps{i-1});
            title(sprintf('Changes %d vs %d',i,i-1));
            hold off;

            switch scene
                case "urbanization"
                    figure; imshow(satMasks{i-1});  title(sprintf('Saturation-mask %d',i-1));
                case "deforestation"
                    figure; imshow(variMasks{i-1}); title(sprintf('VARI-mask %d',i-1));
                case "glacier melting"
                    figure; imshow(valueMasks{i-1}); title(sprintf('Value-mask %d',i-1));
                case "desiccation"
                    figure; imshow(~blueMasks{i-1}); title(sprintf('Blue-mask %d',i-1));
            end
        end
    end

    % --- Optional GIF
    if makeGif
        fprintf('Creating GIF at %s\n', folderPath);
        gifPath = fullfile(folderPath, 'progress.gif');
        cmap = lines(nImgs);
        accMask = false(H_full, W_full);
        accCol  = zeros(H_full, W_full, 3);
        init = false;

        for i = 1:nImgs
            frameRGB = im2uint8(origCell{i});

            if i > 1
                newC  = fullChangeMaps{i-1};
                newPx = newC & ~accMask;
                accMask = accMask | newC;
                for c = 1:3
                    ch = accCol(:,:,c); ch(newPx) = cmap(i,c); accCol(:,:,c) = ch;
                end
            end

            % blend accumulated change colors onto frame
            outF = frameRGB;
            alpha = 0.4;
            idx = accMask;
            for c = 1:3
                base = double(outF(:,:,c));
                overlayCh = 255 * accCol(:,:,c);
                base(idx) = (1-alpha)*base(idx) + alpha*overlayCh(idx);
                outF(:,:,c) = uint8(base);
            end

            % IMPORTANT: no red border overlay; disable dithering
            [ind, map] = rgb2ind(outF, 256, 'nodither');
            if ~init
                imwrite(ind, map, gifPath, 'gif', 'LoopCount', Inf, 'DelayTime', delayTime);
                init = true;
            else
                imwrite(ind, map, gifPath, 'gif', 'WriteMode', 'append', 'DelayTime', delayTime);
            end
        end
        fprintf('GIF saved: %s\n', gifPath);
    end
end

% --- Helper functions (unchanged except value mask consistency) ---
function B = extractBlocksFast(D, h)
    [H, W] = size(D); nY = floor(H/h); nX = floor(W/h);
    D1 = D(1:nY*h, 1:nX*h);
    D1 = reshape(D1, h, nY, h, nX);
    B  = reshape(permute(D1, [1,3,2,4]), h*h, []);
end

function [E, mu] = pcaCovariance(B, S)
    mu = mean(B,2); X = B - mu; M = size(B,2);
    C = (1/M) * (X * X'); [V, D] = eig(C);
    [~, idx] = sort(diag(D), 'descend'); E = V(:, idx(1:S));
end

function [F, pos] = computeFeaturesFast(D, h, E, mu)
    [H, W] = size(D); low = floor((h-1)/2);
    B = im2col(D, [h h], 'sliding'); X = B - mu; F = E' * X;
    [i_grid, j_grid] = ndgrid(1:(H-h+1), 1:(W-h+1));
    ypos = i_grid(:) + low; xpos = j_grid(:) + low; pos = [ypos'; xpos'];
end

function cm = kmeansChangeMap(F, pos, D)
    k = 2; opts = statset('MaxIter',100,'TolFun',1e-3);
    idx = kmeans(F', k, 'Replicates',2, 'Options',opts);
    means = arrayfun(@(c) mean(D(sub2ind(size(D), pos(1,idx==c), pos(2,idx==c)))), 1:k)';
    [~,order] = sort(means); wc = order(2);
    cm = zeros(size(D));
    lin = sub2ind(size(D), pos(1,idx==wc), pos(2,idx==wc));
    cm(lin) = 1;
end

function satMask = computeSaturationMask(rgbImg, validMask, qLev)
    hsv = rgb2hsv(rgbImg); sat = hsv(:,:,2);
    thresh = quantile(sat(validMask), qLev);
    satMask = sat <= thresh;
    satMask(~validMask) = false;
end

function valMask = computeValueMask(rgbImg, validMask, qLev)
    hsv = rgb2hsv(rgbImg); val = hsv(:,:,3);
    thresh = quantile(val(validMask), qLev);
    valMask = val <= thresh;
    valMask(~validMask) = false; % consistency fix
end

function variMask = computeVARIMask(rgbImg, validMask, qLev)
    if max(rgbImg(:))>1; rgbImg = im2double(rgbImg); end
    R=rgbImg(:,:,1); G=rgbImg(:,:,2); B=rgbImg(:,:,3);
    denom = G+R-B; denom(denom==0)=eps;
    VARI = (G-R)./denom;
    thresh = quantile(VARI(validMask), qLev);
    variMask = VARI >= thresh;
    variMask(~validMask) = false;
end

function blueMask = computeBlueMask(rgbImg, validMask)
    H = rgb2hsv(rgbImg); H = H(:,:,1);
    blueMask = false(size(H));
    blueMask(validMask) = H(validMask) >= 0.22 & H(validMask) <= 0.67;
end

function [cumChanges, relGrowthPerStep] = plotCumulativeChange(fullChangeMaps, analysedArea, doGraph)
    if nargin < 3, doGraph = true; end
    nChanges = numel(fullChangeMaps);
    cumChanges = zeros(1, nChanges);
    absChanges = zeros(1, nChanges);

    accMask = false(size(fullChangeMaps{1}));
    for i = 1:nChanges
        current = fullChangeMaps{i};
        newPixels = current & ~accMask;
        absChanges(i) = nnz(newPixels);
        accMask = accMask | current;
        cumChanges(i) = nnz(accMask) / analysedArea;
    end
    relGrowthPerStep = [0, diff(cumChanges)];

    if doGraph
        rateLabels = arrayfun(@(i) sprintf('%d-%d', i, i+1), 1:nChanges-1, 'UniformOutput', false);
        figure;
        subplot(2,1,1);
        plot(1:nChanges, cumChanges, 'b-o', 'LineWidth', 2);
        ylabel('Cumulative change (ratio)'); xlabel('Time step');
        title('Cumulative change relative to analyzed area'); grid on; ylim([0 1]);

        subplot(2,1,2);
        plot(1:nChanges-1, relGrowthPerStep(2:end), 'r--s', 'LineWidth', 2);
        set(gca, 'XTick', 1:nChanges-1, 'XTickLabel', rateLabels);
        ylabel('Rate of change'); xlabel('Intervals'); grid on;
    end
end
