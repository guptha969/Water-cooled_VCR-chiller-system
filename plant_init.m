function [S, sw, ctl] = plant_init(P, D)
%PLANT_INIT  Initial plant state, all-blocks-ON switch set and default control settings.
n = numel(P.room_names);
S.t = 0;
S.Troom = P.T_room0*ones(1, n);
S.Iv = zeros(1, n);
S.valve = ones(1, n);
S.Tret = P.T_room0;          % chilled-water loop starts at room temperature
S.Tb = P.Tdb_mean - 3;       % cooling-tower basin
S.Tsup_prev = S.Tret;
S.Ic = 0; S.comp_run = false; S.t_off = P.t_min_off; S.lock = 0; S.trip = '';
S.x_last = [P.Te_des; P.Tc_des]; S.m_last = D.m_des;
S.E_kWh = 0; S.makeup_L = 0; S.events = {};
S.out = []; S.chain = []; S.log = [];

sw.evaporator = true; sw.compressor = true; sw.condenser = true; sw.expansion = true;
sw.chw_pump = true; sw.cw_pump = true; sw.tower = true;
sw.fcu = true(1, n);

ctl.T_set_room = P.T_set_room;
ctl.T_chw_set = P.T_chw_sup;
ctl.comp_auto = true;  ctl.comp_speed = 1.0;      % auto = PI on chilled-water supply temperature
ctl.exv_auto = true;   ctl.exv_open = 0.6;   % auto = holds superheat; opening used in manual mode
ctl.chw_speed = 1.0;   ctl.cw_speed = 1.0;
end
