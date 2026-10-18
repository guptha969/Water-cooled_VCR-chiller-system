function S = plant_step(S, P, D, sw, ctl, dt)
%PLANT_STEP  Advance the whole plant by dt seconds.
%   Block chain evaluated every step (a block that is OFF passes its input straight through):
%
%   CHILLED-WATER LOOP   tank -> [CHW pump] -> [Evaporator] -> [FCU 1..n in parallel] -> mix -> tank
%   CONDENSER-WATER LOOP basin -> [CW pump] -> [Condenser] -> [Cooling tower] -> basin
%   REFRIGERANT LOOP     [Evaporator] -> [Compressor] -> [Condenser] -> [Expansion valve] -> back
%   ROOMS                lumped thermal capacity, heated by envelope/internal gains, cooled by FCUs
%
%   sw   logical ON/OFF per block (see plant_init);   ctl  setpoints and manual/auto modes.
n = numel(P.room_names);
cpw = 4180;
hr = mod(P.hour0 + S.t/3600, 24);
amb.Tdb = P.Tdb_mean + P.Tdb_amp*cos(2*pi*(hr - 15)/24);
amb.Twb = P.Twb_mean + P.Twb_amp*cos(2*pi*(hr - 15)/24);
Qgain = P.Q24(floor(hr) + 1, :) + P.UA_room.*(S.Troom - 24);     % W heat gain into each room

%% ---- room thermostats -> FCU valves (PI)
valve = zeros(1, n);
for i = 1:n
    e = S.Troom(i) - ctl.T_set_room;
    S.Iv(i) = min(max(S.Iv(i) + e*dt, 0), 1/P.Ki_valve);
    valve(i) = min(max(P.Kp_valve*e + P.Ki_valve*S.Iv(i), 0.08), 1);
end
S.valve = valve;

%% ---- chiller start/stop and speed
Tsp = ctl.T_chw_set;
if S.lock > 0, S.lock = S.lock - dt; end
speed = 0;
if ctl.comp_auto
    if S.comp_run
        if S.Tsup_prev < Tsp - P.comp_off_dT, S.comp_run = false; S.t_off = 0; end
    else
        S.t_off = S.t_off + dt;
        if S.lock <= 0 && S.t_off >= P.t_min_off && S.Tret > Tsp + P.comp_on_dT
            S.comp_run = true; S.Ic = 0;
        end
    end
    if S.comp_run
        e = S.Tsup_prev - Tsp;
        S.Ic = min(max(S.Ic + e*dt, 0), 1/P.Ki_comp);
        speed = min(max(P.Kp_comp*e + P.Ki_comp*S.Ic, P.f_min), 1);
    end
else
    speed = ctl.comp_speed;
    S.comp_run = speed > 0 && S.lock <= 0;
end
if S.lock > 0, speed = 0; S.comp_run = false; end

%% ---- pumps (flow sources)
[w1, ipc] = blk_pump(wstream(S.Tret, 0), D.pump_chw, sw.chw_pump, ctl.chw_speed);
[c1, ipw] = blk_pump(wstream(S.Tb, 0),   D.pump_cw,  sw.cw_pump,  ctl.cw_speed);

%% ---- refrigerant loop (needs all four blocks ON, compressor running and both water flows)
active = sw.evaporator && sw.compressor && sw.condenser && sw.expansion && ...
         S.comp_run && speed > 0 && w1.mdot > 0 && c1.mdot > 0;
R = [];
if active
    [R, ok] = solve_refrigerant(P, D, ctl, w1, c1, speed, S.x_last, max(S.m_last, 0.2*D.m_des));
    if ok
        S.x_last = [R.Te; R.Tc]; S.m_last = R.m;
    else
        active = false; R = [];
        S.events{end+1} = sprintf('t=%.0f s: refrigerant loop did not converge', S.t);
    end
end
if active
    wev_out = R.wev_out; wcd_out = R.wcd_out;
    Qe = R.Q_evap; Qc = R.Q_cond; Wcomp = R.W_comp;
    Te = R.Te; Tc = R.Tc; mref = R.m; opening = R.opening;
    ref = {R.S1, R.S2, R.S3, R.S4};
    refinfo = R.info;
else
    % no circulation: all refrigerant streams sit at the equalised standby state, zero flow.
    Tst = 0.5*(amb.Tdb + mean(S.Troom));
    Pst = ref_props('Psat', Tst);
    hst = ref_props('hf', Tst) + 0.35*(ref_props('hg', Tst) - ref_props('hf', Tst));
    st = ref_props('state', Pst, hst, 0);
    [~, iex]  = blk_expansion(st, D.exv, sw.expansion, Pst, 0.05);
    [~, ~, iev] = blk_evaporator(st, w1, D.evap, sw.evaporator);
    [~, ico]  = blk_compressor(st, D.comp, sw.compressor, Pst, 0);
    [~, ~, icd] = blk_condenser(st, c1, D.cond, sw.condenser);
    refinfo.exv = iex; refinfo.evap = iev; refinfo.comp = ico; refinfo.cond = icd;
    ref = {st, st, st, st};
    wev_out = w1; wcd_out = c1;
    Qe = 0; Qc = 0; Wcomp = 0; Te = NaN; Tc = NaN; mref = 0; opening = NaN;
end

%% ---- fan-coil units: chilled water supplied in parallel
Tsup = wev_out.T;
kk = D.fcu_share.*valve;
mw = w1.mdot*kk/sum(kk);
Qf = zeros(1, n); Wb = zeros(1, n); Tout = zeros(1, n); fcuinfo = cell(1, n);
for i = 1:n
    [co, ~, ifc] = blk_fcu(wstream(Tsup, mw(i)), struct('T', S.Troom(i)), D.fcu(i), sw.fcu(i));
    Qf(i) = ifc.Q; Wb(i) = ifc.W; Tout(i) = co.T; fcuinfo{i} = ifc;
end
if w1.mdot > 0, Tmix = sum(mw.*Tout)/w1.mdot; else, Tmix = S.Tret; end

%% ---- cooling tower
[c2, itw] = blk_tower(wcd_out, amb, D.tower, sw.tower);

%% ---- protection
if active
    if Tc > P.Tc_trip
        S.lock = P.t_lock; S.comp_run = false; S.t_off = 0; S.trip = 'HIGH PRESSURE trip';
        S.events{end+1} = sprintf('t=%.0f s: HIGH PRESSURE trip (Tcond = %.1f degC)', S.t, Tc);
    elseif Te < P.Te_trip || Tsup < P.T_chw_freeze
        S.lock = P.t_lock; S.comp_run = false; S.t_off = 0; S.trip = 'LOW PRESSURE / FREEZE trip';
        S.events{end+1} = sprintf('t=%.0f s: LOW PRESSURE / FREEZE trip (Tevap = %.1f, chw supply = %.1f)', S.t, Te, Tsup);
    end
end
if S.lock <= 0 && ~isempty(S.trip) && S.comp_run, S.trip = ''; end

%% ---- integrate thermal states
if w1.mdot > 0, S.Tret = S.Tret + dt/D.C_chw*w1.mdot*cpw*(Tmix - S.Tret); end
if c1.mdot > 0, S.Tb = S.Tb + dt/D.C_cw*c1.mdot*cpw*(c2.T - S.Tb); end
S.Troom = S.Troom + dt*(Qgain + Wb - Qf)./P.C_room;
S.Tsup_prev = Tsup;

%% ---- outputs
Ptot = Wcomp + ipc.W + ipw.W + itw.W + sum(Wb);
S.E_kWh = S.E_kWh + Ptot*dt/3.6e6;
S.makeup_L = S.makeup_L + itw.makeup*dt;
o.t = S.t; o.hour = hr; o.Tdb = amb.Tdb; o.Twb = amb.Twb;
o.speed = speed; o.running = active; o.opening = opening;
o.Te = Te; o.Tc = Tc; o.m_ref = mref;
o.Q_evap = Qe; o.Q_cond = Qc; o.W_comp = Wcomp; o.W_total = Ptot;
o.COP = Qe/max(Wcomp, 1);  o.kW_per_TR = (Ptot/1e3)/max(Qe/3517, 1e-3);
o.T_chw_sup = Tsup; o.T_chw_ret = S.Tret; o.m_chw = w1.mdot;
o.T_cw_in = S.Tb; o.T_cw_out = wcd_out.T; o.T_cw_cold = c2.T; o.m_cw = c1.mdot;
o.Q_fcu = Qf; o.T_room = S.Troom; o.valve = valve; o.Q_load = Qgain;
o.W_chw_pump = ipc.W; o.W_cw_pump = ipw.W; o.W_fan = itw.W; o.W_blowers = sum(Wb);
o.makeup_Lph = itw.makeup*3600; o.trip = S.trip; o.E_kWh = S.E_kWh;
S.out = o;
S.chain.ref = ref; S.chain.refinfo = refinfo; S.chain.active = active;
S.chain.water = struct('chw_ret', wstream(S.Tret, w1.mdot), 'chw_sup', wstream(Tsup, w1.mdot), ...
                       'cw_in', c1, 'cw_hot', wcd_out, 'cw_cold', c2);
S.chain.pump_chw = ipc; S.chain.pump_cw = ipw; S.chain.tower = itw; S.chain.fcu = fcuinfo;
S.t = S.t + dt;
end
