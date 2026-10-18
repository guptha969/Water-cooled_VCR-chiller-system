function chiller_gui()
%CHILLER_GUI  Live block-chain model of a water-cooled chiller plant with fan-coil units.
%   Run:  chiller_gui
%   Each block has an ON/OFF switch. An OFF block is bypassed: its output equals its input.
%   The simulation runs live, so you can flip switches while it is running.
%   Needs MATLAB R2018a or newer (uifigure). No toolboxes.

P = plant_defaults();
D = plant_design(P);
[S, sw, ctl] = plant_init(P, D);
app.P = P; app.D = D; app.S = S; app.sw = sw; app.ctl = ctl; app.H = [];
app.running = false; app.dt = 30; app.steps = 10; app.tmax = 180*60;

fig = uifigure('Name', 'Chiller plant block chain: evaporator - compressor - condenser - expansion valve + water loops', ...
               'Position', [15 15 1470 890]);
fig.CloseRequestFcn = @(src, ~) cb_close(src);
n = numel(P.room_names);

main = uigridlayout(fig, [3 1]);
main.RowHeight = {'1.55x', '1x', 38};
main.Padding = [4 4 4 4]; main.RowSpacing = 4;

top = uigridlayout(main, [1 3]);
top.ColumnWidth = {290, '1.15x', '1.3x'}; top.Padding = [0 0 0 0];

%% ---------------- left: switches and controls ----------------
pl = uipanel(top, 'Title', 'Block switches (ON / OFF) and controls');
gl = uigridlayout(pl, [27 2]);
gl.RowHeight = repmat({22}, 1, 27); gl.ColumnWidth = {'1x', 120}; gl.Scrollable = 'on';
gl.Padding = [6 4 6 4]; gl.RowSpacing = 3;
keys = {'expansion', 'evaporator', 'compressor', 'condenser', 'chw_pump', 'fcu1', 'fcu2', 'fcu3', 'cw_pump', 'tower'};
labs = {'Expansion valve', 'Evaporator', 'Compressor', 'Condenser', 'Chilled-water pump', ...
        ['FCU ' P.room_names{1}], ['FCU ' P.room_names{2}], ['FCU ' P.room_names{3}], ...
        'Condenser-water pump', 'Cooling tower (fan)'};
r = 1;
hdr = uilabel(gl, 'Text', 'BLOCK SWITCHES', 'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]);
hdr.Layout.Row = r; hdr.Layout.Column = [1 2];
for k = 1:numel(keys)
    r = r + 1;
    l = uilabel(gl, 'Text', labs{k}); l.Layout.Row = r; l.Layout.Column = 1;
    s = uiswitch(gl, 'slider', 'Items', {'OFF', 'ON'}, 'Value', 'ON');
    s.Layout.Row = r; s.Layout.Column = 2;
    s.ValueChangedFcn = @(src, ~) cb_switch(fig, keys{k}, src);
end
r = r + 1;
hdr = uilabel(gl, 'Text', 'CONTROLS', 'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]);
hdr.Layout.Row = r; hdr.Layout.Column = [1 2];
r = r + 1; addlabel(gl, r, 'Room setpoint (degC)');
e = uieditfield(gl, 'numeric', 'Value', P.T_set_room, 'Limits', [18 30]); e.Layout.Row = r; e.Layout.Column = 2;
e.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'T_set_room', src);
r = r + 1; addlabel(gl, r, 'Chilled-water setpoint (degC)');
e = uieditfield(gl, 'numeric', 'Value', P.T_chw_sup, 'Limits', [4 12]); e.Layout.Row = r; e.Layout.Column = 2;
e.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'T_chw_set', src);
r = r + 1; addlabel(gl, r, 'Compressor control');
d = uidropdown(gl, 'Items', {'Auto (PI)', 'Manual'}, 'Value', 'Auto (PI)'); d.Layout.Row = r; d.Layout.Column = 2;
d.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'comp_auto', src);
r = r + 1; addlabel(gl, r, 'Compressor speed (manual)');
sl = uislider(gl, 'Limits', [0.2 1], 'Value', 1, 'MajorTicks', [0.2 0.6 1]); sl.Layout.Row = r; sl.Layout.Column = 2;
sl.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'comp_speed', src);
r = r + 1; addlabel(gl, r, 'Expansion valve control');
d = uidropdown(gl, 'Items', {'Auto (superheat)', 'Manual'}, 'Value', 'Auto (superheat)'); d.Layout.Row = r; d.Layout.Column = 2;
d.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'exv_auto', src);
r = r + 1; addlabel(gl, r, 'Valve opening (manual)');
sl = uislider(gl, 'Limits', [0.1 1], 'Value', 0.6, 'MajorTicks', [0.1 0.5 1]); sl.Layout.Row = r; sl.Layout.Column = 2;
sl.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'exv_open', sl);
r = r + 1; addlabel(gl, r, 'Chilled-water pump speed');
sl = uislider(gl, 'Limits', [0.3 1], 'Value', 1, 'MajorTicks', [0.3 0.65 1]); sl.Layout.Row = r; sl.Layout.Column = 2;
sl.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'chw_speed', src);
r = r + 1; addlabel(gl, r, 'Condenser-water pump speed');
sl = uislider(gl, 'Limits', [0.3 1], 'Value', 1, 'MajorTicks', [0.3 0.65 1]); sl.Layout.Row = r; sl.Layout.Column = 2;
sl.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'cw_speed', src);
r = r + 1; addlabel(gl, r, 'Compressor type');
d = uidropdown(gl, 'Items', {'Reciprocating', 'Centrifugal (scaled)'}, 'Value', 'Reciprocating'); d.Layout.Row = r; d.Layout.Column = 2;
d.ValueChangedFcn = @(src, ~) cb_comptype(fig, src);
r = r + 1; addlabel(gl, r, 'Run until (min)');
e = uieditfield(gl, 'numeric', 'Value', 180, 'Limits', [10 1440]); e.Layout.Row = r; e.Layout.Column = 2;
e.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'tmax', src);
r = r + 1; addlabel(gl, r, 'Steps per screen update');
d = uidropdown(gl, 'Items', {'1', '2', '5', '10', '20'}, 'Value', '10'); d.Layout.Row = r; d.Layout.Column = 2;
d.ValueChangedFcn = @(src, ~) cb_ctl(fig, 'steps', src);

%% ---------------- centre: schematic ----------------
ax = uiaxes(top);
ax.XLim = [-4 120]; ax.YLim = [0 66]; ax.XTick = []; ax.YTick = []; ax.Box = 'on';
ax.XColor = 'none'; ax.YColor = 'none'; hold(ax, 'on'); title(ax, 'Block chain (green = running, yellow = ON but idle, red = OFF / bypassed)');
bx.expansion  = [30 26 12 8];   bx.evaporator = [46 6 22 8];   bx.compressor = [80 16 14 8];
bx.condenser  = [46 46 22 8];   bx.chw_pump   = [2 4 20 8];    bx.cw_pump    = [100 26 18 8];
bx.tower      = [100 44 18 10]; bx.fcu1 = [2 44 20 8]; bx.fcu2 = [2 32 20 8]; bx.fcu3 = [2 20 20 8];
blue = [0.1 0.35 0.9]; red = [0.85 0.15 0.1]; cyan = [0 0.55 0.75]; org = [0.9 0.5 0];
arrow(ax, [68 87 87], [10 10 16], '^', blue);          % evaporator -> compressor
arrow(ax, [87 87 68], [24 50 50], '<', red);           % compressor -> condenser
arrow(ax, [46 36 36], [50 50 34], 'v', red);           % condenser -> expansion valve
arrow(ax, [36 36 46], [26 10 10], '>', blue);          % expansion valve -> evaporator
arrow(ax, [22 46], [8 8], '>', cyan);                  % CHW pump -> evaporator (water)
% three separate PARALLEL supply lines (evaporator -> each FCU) and three separate return lines (each FCU -> pump)
arrow(ax, [50 50 28 28 22], [6 4.0 4.0 48 48], '<', cyan);       % supply to FCU 1 (outer lane)
arrow(ax, [53 53 26 26 22], [6 2.5 2.5 36 36], '<', cyan);       % supply to FCU 2
arrow(ax, [56 56 24 24 22], [6 1.0 1.0 24 24], '<', cyan);       % supply to FCU 3 (inner lane)
arrow(ax, [2 -3.0 -3.0 2], [48 48 6 6], '>', cyan);              % return FCU 1 -> pump
arrow(ax, [2 -1.8 -1.8 2], [36 36 8 8], '>', cyan);              % return FCU 2 -> pump
arrow(ax, [2 -0.6 -0.6 2], [24 24 10 10], '>', cyan);            % return FCU 3 -> pump
arrow(ax, [68 109 109], [52 52 54], '>', org);         % condenser -> tower
arrow(ax, [109 109], [44 34], 'v', org);               % tower -> CW pump
arrow(ax, [100 97 97 68], [30 30 49 49], '<', org);    % CW pump -> condenser
text(ax, 61, 57.5, 'R134a refrigerant loop', 'FontSize', 9, 'Color', red, 'HorizontalAlignment', 'center');
text(ax, 12, 58, 'chilled water (parallel branches)', 'FontSize', 9, 'Color', cyan, 'HorizontalAlignment', 'center');
text(ax, 109, 59, 'condenser water', 'FontSize', 9, 'Color', org, 'HorizontalAlignment', 'center');
h.box = struct(); h.txt = struct();
fn = fieldnames(bx);
for k = 1:numel(fn)
    p = bx.(fn{k});
    h.box.(fn{k}) = rectangle('Parent', ax, 'Position', p, 'Curvature', 0.2, 'FaceColor', [0.9 0.9 0.9], 'LineWidth', 1.3);
    h.txt.(fn{k}) = text(ax, p(1) + p(3)/2, p(2) + p(4)/2, fn{k}, 'HorizontalAlignment', 'center', 'FontSize', 8);
end
h.pt = gobjects(1, 4);
ptpos = [87 8; 90 38; 36 40; 36 18];
for k = 1:4
    h.pt(k) = text(ax, ptpos(k, 1), ptpos(k, 2), '', 'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.25 0.25 0.25], ...
                   'BackgroundColor', [1 1 1], 'Margin', 1);
end
h.room = text(ax, 61, 40, '', 'FontSize', 9, 'HorizontalAlignment', 'center');

%% ---------------- right: tables ----------------
rt = uigridlayout(top, [3 1]); rt.RowHeight = {170, '1x', 118}; rt.Padding = [0 0 0 0]; rt.RowSpacing = 3;
h.tRef = uitable(rt, 'ColumnName', {'Refrigerant stream', 'P kPa', 'T degC', 'Tsat degC', 'Phase', 'x', 'Superheat K', ...
                                    'Subcool K', 'm g/s', 'V L/s', 'h kJ/kg'});
h.tRef.ColumnWidth = {170, 55, 55, 65, 125, 40, 75, 65, 55, 55, 65};
h.tBlk = uitable(rt, 'ColumnName', {'Block', 'Switch', 'Result of the block equations'});
h.tBlk.ColumnWidth = {130, 65, 560};
h.tWat = uitable(rt, 'ColumnName', {'Water stream', 'T degC', 'm kg/s', 'P kPa gauge'});
h.tWat.ColumnWidth = {160, 70, 70, 90};

%% ---------------- plots ----------------
bot = uigridlayout(main, [1 3]); bot.Padding = [0 0 0 0];
a1 = uiaxes(bot); a2 = uiaxes(bot); a3 = uiaxes(bot);
cols = lines(7);
for a = [a1 a2 a3], hold(a, 'on'); grid(a, 'on'); xlabel(a, 'time (min)'); end
title(a1, 'Room temperatures'); ylabel(a1, 'degC');
title(a2, 'Water temperatures'); ylabel(a2, 'degC');
title(a3, 'Heat and power'); ylabel(a3, 'kW');
for i = 1:n, h.lr(i) = plot(a1, NaN, NaN, 'Color', cols(i, :), 'LineWidth', 1.5); end
h.lset = plot(a1, NaN, NaN, 'k--');
legend(a1, [P.room_names, {'setpoint'}], 'Location', 'northeast');
h.lw(1) = plot(a2, NaN, NaN, 'Color', [0 0.5 0.8], 'LineWidth', 1.5);
h.lw(2) = plot(a2, NaN, NaN, 'Color', [0.4 0.75 0.95], 'LineWidth', 1.5);
h.lw(3) = plot(a2, NaN, NaN, 'Color', [0.9 0.5 0], 'LineWidth', 1.5);
h.lw(4) = plot(a2, NaN, NaN, 'Color', [0.95 0.75 0.3], 'LineWidth', 1.5);
legend(a2, {'CHW supply', 'CHW return', 'CW to condenser', 'CW from condenser'}, 'Location', 'northeast');
h.lp(1) = plot(a3, NaN, NaN, 'Color', [0 0.5 0.8], 'LineWidth', 1.5);
h.lp(2) = plot(a3, NaN, NaN, 'Color', [0.85 0.15 0.1], 'LineWidth', 1.5);
h.lp(3) = plot(a3, NaN, NaN, 'k', 'LineWidth', 1.5);
h.lp(4) = plot(a3, NaN, NaN, 'Color', [0.4 0.7 0.3], 'LineWidth', 1.5);
legend(a3, {'Chiller cooling', 'Room heat load', 'Electric power', 'Compressor power'}, 'Location', 'northeast');
h.axes = [a1 a2 a3];

%% ---------------- bottom bar ----------------
bar_ = uigridlayout(main, [1 6]); bar_.ColumnWidth = {110, 110, 110, 130, 130, '1x'}; bar_.Padding = [0 0 0 0];
h.bStart = uibutton(bar_, 'push', 'Text', 'Start', 'FontWeight', 'bold');
h.bStart.ButtonPushedFcn = @(~, ~) cb_start(fig);
h.bPause = uibutton(bar_, 'push', 'Text', 'Pause');
h.bPause.ButtonPushedFcn = @(~, ~) cb_pause(fig);
h.bReset = uibutton(bar_, 'push', 'Text', 'Reset');
h.bReset.ButtonPushedFcn = @(~, ~) cb_reset(fig);
h.bExp = uibutton(bar_, 'push', 'Text', 'Export CSV...');
h.bExp.ButtonPushedFcn = @(~, ~) cb_export(fig);
h.bAbout = uibutton(bar_, 'push', 'Text', 'About');
h.bAbout.ButtonPushedFcn = @(~, ~) cb_about(fig);
h.status = uilabel(bar_, 'Text', 'Press Start. Switches and controls can be changed while running.');

app.h = h; app.keys = keys; app.labs = labs;
fig.UserData = app;
refresh(fig, true);
end

%% =====================================================================
%  Callbacks (state lives in fig.UserData)
%% =====================================================================
function addlabel(g, r, txt)
l = uilabel(g, 'Text', txt); l.Layout.Row = r; l.Layout.Column = 1;
end

function arrow(ax, x, y, head, col)
plot(ax, x, y, '-', 'Color', col, 'LineWidth', 1.6);
plot(ax, x(end), y(end), head, 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 6);
end

function cb_switch(fig, key, src)
app = fig.UserData;
on = strcmp(src.Value, 'ON');
if strncmp(key, 'fcu', 3)
    app.sw.fcu(str2double(key(4))) = on;
else
    app.sw.(key) = on;
end
fig.UserData = app;
if ~app.running, refresh(fig, true); end
end

function cb_ctl(fig, field, src)
app = fig.UserData;
switch field
    case 'comp_auto', app.ctl.comp_auto = strncmp(src.Value, 'Auto', 4);
    case 'exv_auto',  app.ctl.exv_auto = strncmp(src.Value, 'Auto', 4);
    case 'tmax',      app.tmax = src.Value*60;
    case 'steps',     app.steps = str2double(src.Value);
    otherwise,        app.ctl.(field) = src.Value;
end
fig.UserData = app;
if ~app.running, refresh(fig, true); end
end

function cb_comptype(fig, src)
app = fig.UserData;
if app.running
    uialert(fig, 'Pause the simulation before changing the compressor type.', 'Compressor type');
    src.Value = ternary(strcmp(app.P.comp_type, 'reciprocating'), 'Reciprocating', 'Centrifugal (scaled)');
    return;
end
if strncmp(src.Value, 'Cent', 4), app.P.comp_type = 'centrifugal'; else, app.P.comp_type = 'reciprocating'; end
app.D = plant_design(app.P);
fig.UserData = app;
cb_reset(fig);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

function cb_start(fig)
app = fig.UserData;
if app.running, return; end
app.running = true; fig.UserData = app;
app.h.bStart.Enable = 'off';
while isvalid(fig)
    app = fig.UserData;
    if ~app.running, break; end
    for k = 1:app.steps
        app.S = plant_step(app.S, app.P, app.D, app.sw, app.ctl, app.dt);
        app.H = plant_log(app.H, app.S);
        if app.S.t >= app.tmax, app.running = false; break; end
    end
    fig.UserData = app;
    refresh(fig, false);
    drawnow limitrate;
end
if isvalid(fig)
    app = fig.UserData; app.running = false; fig.UserData = app;
    app.h.bStart.Enable = 'on';
    if app.S.t >= app.tmax
        app.h.status.Text = sprintf('Finished at %.0f min.  Energy used %.2f kWh.', app.S.t/60, app.S.E_kWh);
    end
end
end

function cb_pause(fig)
app = fig.UserData; app.running = false; fig.UserData = app;
end

function cb_reset(fig)
app = fig.UserData;
app.running = false; fig.UserData = app; drawnow;
app = fig.UserData;
[S, sw, ctl] = plant_init(app.P, app.D);
% keep the user's present switch and control settings, restart the physical state
app.S = S; app.H = [];
fig.UserData = app;
app.h.bStart.Enable = 'on';
for k = 1:numel(app.h.lr), set(app.h.lr(k), 'XData', NaN, 'YData', NaN); end
for k = 1:numel(app.h.lw), set(app.h.lw(k), 'XData', NaN, 'YData', NaN); end
for k = 1:numel(app.h.lp), set(app.h.lp(k), 'XData', NaN, 'YData', NaN); end
app.h.status.Text = 'Reset. Press Start.';
refresh(fig, true);
end

function cb_close(fig)
if isvalid(fig)
    app = fig.UserData; app.running = false; fig.UserData = app;
    drawnow;
end
delete(fig);
end

function cb_export(fig)
app = fig.UserData;
if isempty(app.H), uialert(fig, 'Nothing to export yet. Run the simulation first.', 'Export'); return; end
[f, p] = uiputfile('chiller_history.csv', 'Save simulation history');
if isequal(f, 0), return; end
writetable(struct2table(app.H), fullfile(p, f));
app.h.status.Text = ['Saved ' fullfile(p, f)];
end

function cb_about(fig)
msg = sprintf(['All building, weather and equipment values are ASSUMED (the 3-room flat from the earlier project).\n\n' ...
    'Every block is its own .m file. An OFF block is bypassed: output = input.\n' ...
    'The refrigerant loop only circulates when evaporator, compressor, condenser and expansion valve are ON, ' ...
    'the compressor is running and both water pumps flow; otherwise refrigerant sits at the standby state.\n\n' ...
    'Protection: high-pressure and freeze/low-pressure cut-outs stop the compressor for 5 minutes.\n' ...
    'The centrifugal option is scaled to this small duty only to demonstrate the model; real centrifugal chillers start near 100-200 TR.']);
uialert(fig, msg, 'About', 'Icon', 'info');
end

%% =====================================================================
%  Display update
%% =====================================================================
function refresh(fig, preview)
app = fig.UserData; h = app.h; S = app.S;
if preview
    S = plant_step(S, app.P, app.D, app.sw, app.ctl, 0);     % dt = 0: evaluate the chain, change nothing
end
o = S.out; c = S.chain; D = app.D; P = app.P; n = numel(P.room_names);
% ---- schematic
active = c.active;
cols.run = [0.62 0.88 0.62]; cols.idle = [1 0.95 0.65]; cols.off = [0.95 0.65 0.62];
ri = c.refinfo;
setbox(h, 'expansion', app.sw.expansion, active, sprintf('Expansion valve\nopen %s  dP %.0f kPa', pct(ri.exv.opening), ri.exv.dP/1e3), cols);
setbox(h, 'evaporator', app.sw.evaporator, active, sprintf('Evaporator\nTe %s  Q %.1f kW', num(o.Te), o.Q_evap/1e3), cols);
setbox(h, 'compressor', app.sw.compressor, active, sprintf('Compressor\nPR %s  %.2f kW  %s', num(ri.comp.PR), o.W_comp/1e3, pct(o.speed)), cols);
setbox(h, 'condenser', app.sw.condenser, active, sprintf('Condenser\nTc %s  Q %.1f kW', num(o.Tc), o.Q_cond/1e3), cols);
setbox(h, 'chw_pump', app.sw.chw_pump, c.pump_chw.W > 0, sprintf('CHW pump\n%.2f kg/s  %.0f W', o.m_chw, c.pump_chw.W), cols);
setbox(h, 'cw_pump', app.sw.cw_pump, c.pump_cw.W > 0, sprintf('CW pump\n%.2f kg/s  %.0f W', o.m_cw, c.pump_cw.W), cols);
setbox(h, 'tower', app.sw.tower, c.tower.Q > 0, sprintf('Cooling tower\n%.1f -> %.1f degC', o.T_cw_out, o.T_cw_cold), cols);
for i = 1:n
    key = sprintf('fcu%d', i);
    setbox(h, key, app.sw.fcu(i), c.fcu{i}.Q > 0, sprintf('%s\nroom %.1f degC  %.1f kW', P.room_names{i}, o.T_room(i), o.Q_fcu(i)/1e3), cols);
end
names = {'1', '2', '3', '4'};
for k = 1:4
    st = c.ref{k};
    set(h.pt(k), 'String', sprintf('%s: %.1fC %.0fkPa', names{k}, st.T, st.P/1e3));
end
if ~isempty(o.trip) && S.lock > 0
    set(h.room, 'String', sprintf('COMPRESSOR LOCKED OUT: %s (%.0f s)', o.trip, S.lock), 'Color', [0.8 0 0]);
elseif active
    set(h.room, 'String', sprintf('t = %.0f min   COP %.2f   %.2f kW/TR', o.t/60, o.COP, o.kW_per_TR), 'Color', [0 0.4 0]);
else
    set(h.room, 'String', sprintf('t = %.0f min   refrigerant not circulating', o.t/60), 'Color', [0.4 0.4 0.4]);
end
% ---- refrigerant stream table
rn = {'1  Evaporator out / compressor in', '2  Compressor out / condenser in', ...
      '3  Condenser out / valve in', '4  Valve out / evaporator in'};
data = cell(4, 11);
for k = 1:4
    st = c.ref{k};
    data(k, :) = {rn{k}, rnd(st.P/1e3, 0), rnd(st.T, 1), rnd(st.Tsat, 1), st.phase, nz(st.x), rnd(st.superheat, 1), ...
                  rnd(st.subcool, 1), rnd(st.mdot*1e3, 1), rnd(st.vdot*1e3, 2), rnd(st.h/1e3, 1)};
end
h.tRef.Data = data;
% ---- block table
swtxt = @(b) ternary(b, 'ON', 'OFF');
blk = { ...
  'Expansion valve',  swtxt(app.sw.expansion), ri.exv.note; ...
  'Evaporator',       swtxt(app.sw.evaporator), ri.evap.note; ...
  'Compressor',       swtxt(app.sw.compressor), ri.comp.note; ...
  'Condenser',        swtxt(app.sw.condenser), ri.cond.note; ...
  'CHW pump',         swtxt(app.sw.chw_pump), c.pump_chw.note};
for i = 1:n
    blk(end+1, :) = {['FCU ' P.room_names{i}], swtxt(app.sw.fcu(i)), c.fcu{i}.note}; %#ok<AGROW>
end
blk(end+1, :) = {'CW pump', swtxt(app.sw.cw_pump), c.pump_cw.note};
blk(end+1, :) = {'Cooling tower', swtxt(app.sw.tower), c.tower.note};
h.tBlk.Data = blk;
% ---- water table
w = c.water;
h.tWat.Data = { ...
  'CHW return (to pump)',        rnd(w.chw_ret.T, 1),  rnd(w.chw_ret.mdot, 3),  rnd(w.chw_ret.P/1e3, 0); ...
  'CHW supply (from evaporator)', rnd(w.chw_sup.T, 1),  rnd(w.chw_sup.mdot, 3),  rnd(w.chw_sup.P/1e3, 0); ...
  'CW to condenser',             rnd(w.cw_in.T, 1),    rnd(w.cw_in.mdot, 3),    rnd(w.cw_in.P/1e3, 0); ...
  'CW from condenser',           rnd(w.cw_hot.T, 1),   rnd(w.cw_hot.mdot, 3),   rnd(w.cw_hot.P/1e3, 0); ...
  'CW from tower',               rnd(w.cw_cold.T, 1),  rnd(w.cw_cold.mdot, 3),  rnd(w.cw_cold.P/1e3, 0)};
% ---- plots and status
H = app.H;
if ~isempty(H)
    t = H.t_min;
    for i = 1:n, set(h.lr(i), 'XData', t, 'YData', H.(sprintf('T_room%d', i))); end
    set(h.lset, 'XData', [t(1) t(end)], 'YData', [app.ctl.T_set_room app.ctl.T_set_room]);
    set(h.lw(1), 'XData', t, 'YData', H.T_chw_sup); set(h.lw(2), 'XData', t, 'YData', H.T_chw_ret);
    set(h.lw(3), 'XData', t, 'YData', H.T_cw_in);  set(h.lw(4), 'XData', t, 'YData', H.T_cw_out);
    qload = zeros(size(t));
    for i = 1:n, qload = qload + H.(sprintf('Q_fcu%d_kW', i)); end
    set(h.lp(1), 'XData', t, 'YData', H.Q_evap_kW); set(h.lp(2), 'XData', t, 'YData', qload);
    set(h.lp(3), 'XData', t, 'YData', H.W_total_kW); set(h.lp(4), 'XData', t, 'YData', H.W_comp_kW);
end
if ~preview
    h.status.Text = sprintf('t = %.0f min | rooms %s degC | chw supply %.1f | energy %.2f kWh | tower makeup %.1f L', ...
                            o.t/60, sprintf('%.1f ', o.T_room), o.T_chw_sup, S.E_kWh, S.makeup_L);
    if ~isempty(S.events)
        h.status.Text = [h.status.Text ' | ' S.events{end}];
    end
end
end

function setbox(h, key, on, running, label, cols)
if ~on
    set(h.box.(key), 'FaceColor', cols.off);
    label = sprintf('%s\nOFF: BYPASSED (out = in)', strtok(label, newline));
elseif running
    set(h.box.(key), 'FaceColor', cols.run);
else
    set(h.box.(key), 'FaceColor', cols.idle);
end
set(h.txt.(key), 'String', label);
end

function s = num(x)
if isnan(x), s = '-'; else, s = sprintf('%.1f', x); end
end

function s = pct(x)
if isnan(x), s = '-'; else, s = sprintf('%.0f%%', 100*x); end
end

function y = rnd(x, d)
if isnan(x), y = NaN; else, y = round(x*10^d)/10^d; end
end

function y = nz(x)
if isnan(x), y = NaN; else, y = round(x*100)/100; end
end
