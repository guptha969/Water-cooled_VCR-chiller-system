function print_chain(S, P)
%PRINT_CHAIN  Print the block chain (streams and block results) of the latest plant step as text.
%   print_chain(S, P)   S = plant state after plant_step, P = plant_defaults()
o = S.out; c = S.chain; ri = c.refinfo;
fprintf('\n=== t = %.0f min   (%s) ===\n', o.t/60, ternary_(c.active, 'refrigerant loop RUNNING', 'refrigerant NOT circulating'));
names = {'1 Evap out -> Comp in ', '2 Comp out -> Cond in ', '3 Cond out -> Valve in', '4 Valve out -> Evap in '};
fprintf('%-24s %8s %8s %9s %-22s %6s %8s %7s %8s\n', 'Refrigerant stream', 'P kPa', 'T degC', 'Tsat degC', 'Phase', 'SH/SC', 'm g/s', 'V L/s', 'h kJ/kg');
for k = 1:4
    st = c.ref{k};
    if st.superheat > 0, sc = sprintf('SH %.1f', st.superheat); elseif st.subcool > 0, sc = sprintf('SC %.1f', st.subcool); else, sc = '-'; end
    fprintf('%-24s %8.0f %8.1f %9.1f %-22s %6s %8.1f %7.2f %8.1f\n', names{k}, st.P/1e3, st.T, st.Tsat, st.phase, sc, st.mdot*1e3, st.vdot*1e3, st.h/1e3);
end
fprintf('\n%-22s %s\n', 'Block', 'Result');
fprintf('%-22s %s\n', 'Expansion valve', ri.exv.note);
fprintf('%-22s %s\n', 'Evaporator', ri.evap.note);
fprintf('%-22s %s\n', 'Compressor', ri.comp.note);
fprintf('%-22s %s\n', 'Condenser', ri.cond.note);
fprintf('%-22s %s\n', 'CHW pump', c.pump_chw.note);
for i = 1:numel(c.fcu), fprintf('%-22s %s\n', ['FCU ' P.room_names{i}], c.fcu{i}.note); end
fprintf('%-22s %s\n', 'CW pump', c.pump_cw.note);
fprintf('%-22s %s\n', 'Cooling tower', c.tower.note);
fprintf('\nrooms %s degC | chiller %.2f kW cooling, %.2f kW electric, COP %.2f | energy %.2f kWh\n', ...
        sprintf('%.1f ', o.T_room), o.Q_evap/1e3, o.W_total/1e3, o.COP, S.E_kWh);
if ~isempty(o.trip), fprintf('PROTECTION: %s (lock-out %.0f s left)\n', o.trip, S.lock); end
end

function v = ternary_(c, a, b)
if c, v = a; else, v = b; end
end
