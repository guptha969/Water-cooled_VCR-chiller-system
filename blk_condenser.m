function [out, wout, info] = blk_condenser(in, wi, par, on)
%BLK_CONDENSER  Water-cooled shell-and-tube condenser.
%   in   refrigerant stream from the compressor (superheated vapour)
%   wi   condenser-water stream entering (from cooling tower basin)
%
%   Equations (eps-NTU, refrigerant at constant T_cond so Cmin = water side)
%     T_cond  = T_sat(P_in)
%     UA      = UA_des * (mdot_w/mdot_w_des)^0.8
%     eps     = 1 - exp(-UA/(mdot_w*cp_w))
%     Q       = eps * mdot_w*cp_w * (T_cond - T_w,in)         [W rejected]
%     h_out   = h_in - Q/mdot_ref          (desuperheat + condense + subcool lumped)
%     T_w,out = T_w,in + Q/(mdot_w*cp_w)
%   Subcooling (or leftover quality) at the outlet is a RESULT of this balance.
%   OFF (or no flow): out = in, wout = wi.
info.name = 'Condenser'; info.on = on; info.Q = 0; info.W = 0; info.eps = 0; info.UA = 0; info.note = '';
out = in; wout = wi;
if ~on
    info.note = 'BYPASSED: out = in, no heat rejected'; return;
end
if in.mdot <= 1e-9 || wi.mdot <= 1e-9
    info.note = 'no flow: no heat transfer'; return;
end
Tc = in.Tsat;
Cw = wi.mdot*wi.cp;
UA = par.UA*(wi.mdot/par.mdot_w_des)^0.8;
eps = 1 - exp(-UA/Cw);
Q = max(0, eps*Cw*(Tc - wi.T));
h3 = in.h - Q/in.mdot;
out = ref_props('state', in.P - par.dP, h3, in.mdot);
wout.T = wi.T + Q/Cw;
info.Q = Q; info.eps = eps; info.UA = UA; info.Tc = Tc;
info.note = sprintf('Q = %.2f kW, eps = %.2f, water %.1f -> %.1f degC', Q/1e3, eps, wi.T, wout.T);
end
