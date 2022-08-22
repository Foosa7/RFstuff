%
% pcbmodelgen usage example (using Octave script files)
%

close all
clear
% clc

% Skip FDTD and analyze data if previously generated
post_proc_only = 0;

% Show only model geometry no simulation (check before real run)
show_model_only = 0;

% Run preprocessing of FDTD (can use to output model dumps and information)
fdtd_preproc_only = 0;

disp('openEMS FDTD startup');
disp('Using Octave script files');

% Using ~/.octaverc instead
% addpath("/mnt/c/openEMS/matlab/");

% Setup the simulation
physical_constants;
unit = 1e-3; % all length in mm

% Setup FDTD parameter & excitation function
% frequency range of interest
f_start = 1e9;
f_stop  = 4e9;
f0 = 0.5 * (f_start + f_stop);
fc = f_stop - f0;

% Setup exitation types
FDTD = InitFDTD('NrTs', 40000);
FDTD = SetGaussExcite(FDTD, f0, f_stop - f0);

% boundary conditions
BC = {'MUR' 'MUR' 'MUR' 'MUR' 'MUR' 'MUR'};
FDTD = SetBoundaryCond(FDTD, BC);

% Setup CSXCAD geometry & mesh
CSX = InitCSX();

% Define excitation port
start = [2.5 -3.5 0];
stop  = [2.5 -5.5 1];

% Priority MUST be > 3
[CSX port] = AddLumpedPort(CSX, 15, 1, 50, start, stop, [0 0 1], true);

% Setup materials used (WARNING: check that material names are same in config.json)
CSX = AddMaterial(CSX, 'pcb');
CSX = SetMaterialProperty(CSX, 'pcb', 'Epsilon', 4.2, 'Mue', 1, 'Kappa', 0, 'Sigma', 0, 'Density', 1);
CSX = AddMetal(CSX, 'metal_top');
CSX = AddMetal(CSX, 'metal_bot');
CSX = AddMaterial(CSX, 'drill_fill');
CSX = SetMaterialProperty(CSX, 'drill_fill', 'Epsilon', 1, 'Mue', 1, 'Kappa', 0, 'Sigma', 0, 'Density', 1);
CSX = AddMaterial(CSX, 'box_material');
CSX = SetMaterialProperty(CSX, 'box_material', 'Epsilon', 1, 'Mue', 1, 'Kappa', 0, 'Sigma', 0, 'Density', 1);

% load model in CSX structure (model script is output from pcbmodelgen)
CSX = test_pcb(CSX);

% load auto generated grid mesh lines
model_mesh = kicad_pcb_mesh();

% define grid (WARNING: check that units is what was used in design)
CSX = DefineRectGrid(CSX, unit, model_mesh);

disp('Model import and simulation setup done');

% Prepare simulation folder
Sim_Path = 'tmp';
Sim_CSX = 'simulation.xml';

if(post_proc_only == 0)
    [status, message, messageid] = rmdir(Sim_Path, 's'); % clear previous directory
    [status, message, messageid] = mkdir(Sim_Path); % create empty simulation folder

    disp('Generating simulation configuration file');

    % write openEMS compatible xml-file
    WriteOpenEMS([Sim_Path '/' Sim_CSX], FDTD, CSX);
    disp('Done');

    disp('Showing geometry');

    % show the structure
    CSXGeomPlot([Sim_Path '/' Sim_CSX]);

    if(show_model_only)
        disp('Showing only model - exit');
        exit();
    end

    cmd_params = '--debug-PEC --debug-material';
    if(fdtd_preproc_only)
        cmd_params = '--debug-PEC --debug-material --no-simulation';
    end

    disp('Starting openEMS');

    % run openEMS
    RunOpenEMS(Sim_Path, Sim_CSX, cmd_params);

    if(fdtd_preproc_only)
        disp('Only preprocessing - exit');
        exit();
    end
end


% Do post processing as you normaly would with openEMS and Plots
% ===========================================================================================

freq = linspace(max([1e9,f0-fc]), f0 + fc, 501);

U = ReadUI({'port_ut1','et'}, [Sim_Path '/'], freq); % time domain/freq domain voltage
I = ReadUI('port_it1', [Sim_Path '/'], freq); % time domain/freq domain current (half time step is corrected)

% Plot time domain voltage
figure
[ax,h1,h2] = plotyy(U.TD{1}.t / 1e-9, U.TD{1}.val, U.TD{2}.t / 1e-9, U.TD{2}.val);
set(h1, 'Linewidth', 2);
set(h1, 'Color', [1 0 0]);
set(h2, 'Linewidth', 2);
set(h2, 'Color', [0 0 0]);
grid on
title('Voltage vs Time');
xlabel('Time (ns)');
ylabel(ax(1), 'ut1 Voltage (V)');
ylabel(ax(2), 'et Voltage (V)');

% Now make the y-axis symmetric to y=0 (align zeros of y1 and y2)
y1 = ylim(ax(1));
y2 = ylim(ax(2));
ylim(ax(1), [-max(abs(y1)) max(abs(y1))]);
ylim(ax(2), [-max(abs(y2)) max(abs(y2))]);
print -dpng Ut.png

% Plot feed point impedance
figure
Zin = U.FD{1}.val ./ I.FD{1}.val;
plot(freq / 1e6, real(Zin), 'k-', 'Linewidth', 2);
hold on
grid on
plot(freq / 1e6, imag(Zin), 'r--', 'Linewidth', 2);
title('Feed Point Impedance');
xlabel('Frequency (MHz)');
ylabel('Z_{in} Impedance (Ohm)');
legend('real', 'imag');
print -dpng Z.png

% Plot reflection coefficient S11
figure
uf_inc = 0.5 * (U.FD{1}.val + I.FD{1}.val * 50);
if_inc = 0.5 * (I.FD{1}.val - U.FD{1}.val / 50);
uf_ref = U.FD{1}.val - uf_inc;
if_ref = I.FD{1}.val - if_inc;
s11 = uf_ref ./ uf_inc;
plot(freq / 1e6, 20 * log10(abs(s11)), 'k-', 'Linewidth', 2);
grid on
title('Reflection Coefficient S_{11}');
xlabel('Frequency (MHz)');
ylabel('Reflection Coefficient |S_{11}|');
print -dpng S11.png
