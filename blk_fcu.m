function [chw_out, air_out, info] = blk_fcu(chw_in, air_in, par, on)
%BLK_FCU  Fan-coil unit (chilled-water coil + blower) in one room.
%   chw_in   chilled water entering this coil (flow already = this branch's flow)
%   air_in   room air struct with field T [degC]
%
%   Equations (counter-flow eps-NTU)
%     C_air = mdot_air * cp_air / SHR   (total-heat equivalent: sensible + latent)
%     C_w   = mdot_w * cp_w;   Cmin = min(C_air, C_w);  Cr = Cmin/Cmax
%     UA    = UA_des * (mdot_w/mdot_w_des)^0.4
%     NTU   = UA/Cmin;   eps = (1 - exp(-NTU(1-Cr))) / (1 - Cr*exp(-NTU(1-Cr)))
%     Q     = eps * Cmin * (T_air,in - T_w,in)
%     T_w,out = T_w,in + Q/C_w;   T_air,out = T_air,in - Q/C_air
%   Blower electric power ends up as heat in the room air.
%   OFF: chw_out = chw_in and air_out = air_in (coil skipped, no cooling).
info.name = par.name; info.on = on; info.Q = 0; info.W = 0; info.note = ''; info.eps = 0;
chw_out = chw_in; air_out = air_in;
if ~on
    info.note = 'BYPASSED: coil skipped, water passes unchanged'; return;
end
mw = chw_in.mdot;
info.W = par.P_blower;
if mw <= 1e-9
    info.note = 'no chilled-water flow'; return;
end
Ca = par.m_air*par.cp_eff;
Cw = mw*chw_in.cp;
Cmin = min(Ca, Cw); Cmax = max(Ca, Cw); Cr = Cmin/Cmax;
UA = par.UA*(mw/par.mdot_w_des)^0.4;
NTU = UA/Cmin;
if abs(1 - Cr) < 1e-6
    eps = NTU/(1 + NTU);
else
    ex = exp(-NTU*(1 - Cr));
    eps = (1 - ex)/(1 - Cr*ex);
end
Q = max(0, eps*Cmin*(air_in.T - chw_in.T));
chw_out.T = chw_in.T + Q/Cw;
air_out.T = air_in.T - Q/Ca;
info.Q = Q; info.eps = eps;
info.note = sprintf('Q = %.2f kW, water %.1f -> %.1f degC, air %.1f -> %.1f degC', ...
                    Q/1e3, chw_in.T, chw_out.T, air_in.T, air_out.T);
end
