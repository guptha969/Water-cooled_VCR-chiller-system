function [out, wout, info] = blk_evaporator(in, wi, par, on)
%BLK_EVAPORATOR  Refrigerant-to-chilled-water heat exchanger (refrigerant boils).
%   in   refrigerant stream leaving the expansion valve (low-pressure two-phase)
%   wi   chilled-water stream entering (return water)
%
%   Equations (eps-NTU, refrigerant at constant T_evap so Cmin = water side)
%     T_evap  = T_sat(P_in)
%     UA      = UA_des * (mdot_w/mdot_w_des)^0.8
%     eps     = 1 - exp(-UA / (mdot_w*cp_w))
%     Q       = eps * mdot_w*cp_w * (T_w,in - T_evap)          [W absorbed]
%     h_out   = h_in + Q/mdot_ref        (energy balance, refrigerant side)
%     T_w,out = T_w,in - Q/(mdot_w*cp_w)
%   If h_out < h_g the refrigerant leaves still wet (superheat = 0, x < 1).
%   OFF (or no flow): out = in, wout = wi.
info.name = 'Evaporator'; info.on = on; info.Q = 0; info.W = 0; info.eps = 0; info.UA = 0; info.note = '';
out = in; wout = wi;
if ~on
    info.note = 'BYPASSED: out = in, no heat absorbed'; return;
end
if in.mdot <= 1e-9 || wi.mdot <= 1e-9
    info.note = 'no flow: no heat transfer'; return;
end
Te = in.Tsat;
Cw = wi.mdot*wi.cp;
UA = par.UA*(wi.mdot/par.mdot_w_des)^0.8;
eps = 1 - exp(-UA/Cw);
Q = max(0, eps*Cw*(wi.T - Te));
h1 = in.h + Q/in.mdot;
out = ref_props('state', in.P - par.dP, h1, in.mdot);
wout.T = wi.T - Q/Cw;
info.Q = Q; info.eps = eps; info.UA = UA; info.Te = Te;
info.note = sprintf('Q = %.2f kW, eps = %.2f, water %.1f -> %.1f degC', Q/1e3, eps, wi.T, wout.T);
if wout.T < 3
    info.note = [info.note ' | FREEZE RISK'];
end
end
