function H = plant_log(H, S)
%PLANT_LOG  Append the latest plant outputs (scalars and per-room values) to the history struct H.
o = S.out;
row.t_min = o.t/60; row.hour = o.hour; row.Tdb = o.Tdb; row.Twb = o.Twb;
row.speed = o.speed; row.Te = o.Te; row.Tc = o.Tc; row.m_ref = o.m_ref;
row.Q_evap_kW = o.Q_evap/1e3; row.Q_cond_kW = o.Q_cond/1e3; row.W_comp_kW = o.W_comp/1e3;
row.W_total_kW = o.W_total/1e3; row.COP = o.COP;
row.T_chw_sup = o.T_chw_sup; row.T_chw_ret = o.T_chw_ret;
row.T_cw_in = o.T_cw_in; row.T_cw_out = o.T_cw_out; row.T_cw_cold = o.T_cw_cold;
for i = 1:numel(o.T_room)
    row.(sprintf('T_room%d', i)) = o.T_room(i);
    row.(sprintf('Q_fcu%d_kW', i)) = o.Q_fcu(i)/1e3;
    row.(sprintf('valve%d', i)) = o.valve(i);
end
f = fieldnames(row);
if isempty(H)
    for k = 1:numel(f), H.(f{k}) = row.(f{k}); end
else
    for k = 1:numel(f), H.(f{k})(end+1, 1) = row.(f{k}); end
end
end
