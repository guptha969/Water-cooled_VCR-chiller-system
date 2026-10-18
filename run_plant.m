function [H, S] = run_plant(tmax_min, events, dt)
%RUN_PLANT  Run the block-chain chiller plant WITHOUT the GUI, with scheduled switch events.
%
%   [H, S] = run_plant()                         default 150 min demo with example events
%   [H, S] = run_plant(180, {})                  180 min, everything ON all the time
%   [H, S] = run_plant(120, events, 30)          events = { time_min, 'key', value ; ... }
%
%   Keys for blocks (value true = ON, false = OFF/bypassed):
%     'expansion' 'evaporator' 'compressor' 'condenser' 'chw_pump' 'cw_pump' 'tower' 'fcu1' 'fcu2' 'fcu3'
%   Keys for controls:
%     'T_set_room' 'T_chw_set' 'comp_auto'(true/false) 'comp_speed'(0..1) 'exv_auto'(true/false)
%     'exv_open'(0..1) 'chw_speed' 'cw_speed'
%   Example:  events = { 60, 'tower', false ; 90, 'tower', true ; 110, 'fcu2', false };
%
%   Output: H = history struct (also saved to plant_history.csv), S = final plant state.
%   A text view of the block chain is printed at every event and at the end; a figure is drawn.
if nargin < 1 || isempty(tmax_min), tmax_min = 150; end
if nargin < 2
    events = { 60, 'tower', false; ...        % cooling tower fan switched OFF at 60 min
               90, 'tower', true;  ...        % ... and back ON at 90 min
              110, 'fcu2',  false };          % bedroom-1 fan coil switched OFF at 110 min
end
if nargin < 3, dt = 30; end

here = fileparts(mfilename('fullpath'));
P = plant_defaults(); D = plant_design(P); [S, sw, ctl] = plant_init(P, D);
fprintf('Plant: %.1f kW chiller (%s compressor), %d fan-coil units, design COP %.2f\n', ...
        P.Q_chiller/1e3, P.comp_type, numel(P.room_names), D.COP_des);
H = [];
nsteps = round(tmax_min*60/dt);
next = 1;
for k = 1:nsteps
    tmin = S.t/60;
    show = false;
    while next <= size(events, 1) && tmin >= events{next, 1}      % apply scheduled switch events
        [sw, ctl] = apply_event(sw, ctl, events{next, 2}, events{next, 3});
        fprintf('\n>>> t = %.0f min : %s -> %s\n', tmin, events{next, 2}, val_(events{next, 3}));
        next = next + 1; show = true;
    end
    S = plant_step(S, P, D, sw, ctl, dt);
    H = plant_log(H, S);
    if show, print_chain(S, P); end                                % block chain right after an event
    if mod(k, round(30*60/dt)) == 0
        o = S.out;
        fprintf('t=%4.0f min  rooms %s  chw %.1f/%.1f  Te %.1f Tc %.1f  Qe %.2f kW  P %.2f kW  COP %.2f\n', ...
                o.t/60, sprintf('%.1f ', o.T_room), o.T_chw_sup, o.T_chw_ret, o.Te, o.Tc, o.Q_evap/1e3, o.W_total/1e3, o.COP);
    end
end
fprintf('\nFINAL STATE\n'); print_chain(S, P);
fprintf('\nTotal electric energy %.2f kWh, tower make-up water %.1f L\n', S.E_kWh, S.makeup_L);
for i = 1:numel(S.events), fprintf('event: %s\n', S.events{i}); end

% ---- save history (plain fprintf so it works in MATLAB and Octave)
f = fieldnames(H); fn = fullfile(here, 'plant_history.csv');
fid = fopen(fn, 'w'); fprintf(fid, '%s\n', strjoin(f', ','));
for i = 1:numel(H.t_min)
    row = cellfun(@(n) H.(n)(i), f); fprintf(fid, '%.6g,', row(1:end-1)); fprintf(fid, '%.6g\n', row(end));
end
fclose(fid); fprintf('History saved to %s\n', fn);

% ---- figure (skipped silently if no display is available)
try
    figure('Name', 'Chiller plant block chain', 'Position', [60 60 1250 780]);
    t = H.t_min;
    subplot(2, 2, 1); hold on; grid on;
    for i = 1:numel(P.room_names), plot(t, H.(sprintf('T_room%d', i)), 'LineWidth', 1.5); end
    plot([t(1) t(end)], [P.T_set_room P.T_set_room], 'k--'); legend([P.room_names, {'setpoint'}]); title('Room temperatures (degC)');
    subplot(2, 2, 2); hold on; grid on;
    plot(t, H.T_chw_sup, t, H.T_chw_ret, t, H.T_cw_in, t, H.T_cw_out, 'LineWidth', 1.5);
    legend('CHW supply', 'CHW return', 'CW to condenser', 'CW from condenser'); title('Water temperatures (degC)');
    subplot(2, 2, 3); hold on; grid on;
    plot(t, H.Te, t, H.Tc, 'LineWidth', 1.5); plot(t, 10*H.speed, ':', 'LineWidth', 1.2);
    legend('T evaporating', 'T condensing', 'compressor speed x10'); title('Refrigerant (degC)'); xlabel('time (min)');
    subplot(2, 2, 4); hold on; grid on;
    plot(t, H.Q_evap_kW, t, H.W_total_kW, t, H.COP, 'LineWidth', 1.5);
    legend('Cooling kW', 'Electric kW', 'COP'); title('Capacity, power, COP'); xlabel('time (min)');
catch
    fprintf('(no display available: figure skipped, use plant_history.csv)\n');
end
end

function [sw, ctl] = apply_event(sw, ctl, key, val)
switch key
    case {'expansion', 'evaporator', 'compressor', 'condenser', 'chw_pump', 'cw_pump', 'tower'}
        sw.(key) = logical(val);
    case {'fcu1', 'fcu2', 'fcu3'}
        sw.fcu(str2double(key(4))) = logical(val);
    case {'comp_auto', 'exv_auto'}
        ctl.(key) = logical(val);
    case {'T_set_room', 'T_chw_set', 'comp_speed', 'exv_open', 'chw_speed', 'cw_speed'}
        ctl.(key) = val;
    otherwise
        error('run_plant: unknown event key "%s"', key);
end
end

function s = val_(v)
if islogical(v) || (isnumeric(v) && any(v == [0 1]) && numel(v) == 1), if v, s = 'ON'; else, s = 'OFF'; end
else, s = num2str(v); end
end
