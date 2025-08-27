%% demoUrbanization.m
% Demo script for change detection (urbanization scenario)
%
% This script loads pre-registered images from data/urbanization,
% applies the PCA + K-Means change detection algorithm,
% and visualizes the results.

clear; clc; close all;

% --- Load images ---
% assumes you have files like "01_2000.png", "02_2010.png", ...
imgs = loadRegisteredImages('data/Las Vegas');

% --- Run change detection ---
[changeMaps, nValidPixels, cumChanges, relGrowth] = changeDetectionPCAKMeans(imgs, 'urbanization', 'folderPath', 'data/Las Vegas', 'doPlot', true, 'doGraph', true);


