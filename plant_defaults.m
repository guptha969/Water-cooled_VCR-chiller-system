function P = plant_defaults()
%PLANT_DEFAULTS  Assumed inputs for the chilled-water plant serving the 3-room flat.
%   Room loads and UA values come from the earlier HVAC project (same flat, same summer day).

% ---- building: three rooms, one fan-coil unit each
P.room_names = {'Living', 'Bedroom1', 'Bedroom2'};
P.Q24 = [ ...   % hourly total cooling load (sensible + latent) in W at 24 degC room temperature
 1249  928  921; 1047  846  762;  848  771  601;  762  707  536;  697  762  484;  659  830  449; ...
  762 1063  500;  897  925  373; 1201  986  328; 1366 1102  369; 1614 1272  441; 1976 1400  625; ...
 2296 1477  806; 2723 1619 1079; 3057 1826 1319; 3371 1832 1597; 3546 1739 2058; 3572 1702 2185; ...
 3967 1751 2290; 3813 1653 2232; 3525 1592 2085; 3125 1379 1858; 2203 1403 1462; 1613 1133 1173];
P.UA_room = [87.5 61.5 56.2];        % W/K  (heat gain changes with room temperature)
P.C_room  = [1.74e6 1.22e6 1.07e6];  % J/K  lumped thermal capacity (air + furniture + walls)
P.T_set_room = 24.5;                 % degC thermostat setpoint (all rooms)
P.T_room0 = 30.0;                    % degC starting room temperature (hot afternoon)
P.hour0 = 14;                        % start time of day (h)

% ---- weather (Jamshedpur summer, arbitrary sinusoids peaking at 15:00)
P.Tdb_mean = 33; P.Tdb_amp = 6;
P.Twb_mean = 26.8; P.Twb_amp = 1.2;

% ---- chiller design duty and water temperatures
P.Q_chiller = 10000;                 % W   (about 2.8 TR, covers the 8.0 kW block peak)
P.T_chw_sup = 7;  P.T_chw_ret = 12;  % degC chilled water supply / return (design)
P.T_cw_in = 32;   P.T_cw_out = 37;   % degC condenser water in / out (design)
P.Te_des = 2.0;   P.Tc_des = 42.0;   % degC evaporating / condensing (design)
P.superheat = 5;  P.subcool = 5;     % K

% ---- compressor ('reciprocating' or 'centrifugal')
P.comp_type = 'reciprocating';
P.rpm = 1450; P.clearance = 0.05; P.poly_n = 1.1;
P.eta_is = 0.75; P.eta_motor = 0.90;
P.cf_rpm = 45000; P.cf_psi = 0.55; P.cf_surge = 0.45;    % centrifugal data (scaled to this duty)

% ---- expansion valve, pumps, fan coils, tower
P.exv_Cd = 0.65; P.exv_open_des = 0.60;
P.dP_chw = 80e3; P.dP_cw = 90e3; P.eta_pump = 0.60; P.pump_max_ratio = 1.6;
P.fcu_oversize = 1.25; P.SHR = 0.8; P.fcu_air_dT = 10;
P.tower_Twb_des = 28; P.tower_cycles = 4;
P.V_chw = 0.10; P.V_cw = 0.15;       % m3 of water in the chilled / condenser loop (thermal inertia)

% ---- protection
P.Tc_trip = 58;                      % degC high-pressure cut-out (as saturation temperature)
P.Te_trip = -4;                      % degC low-pressure cut-out
P.T_chw_freeze = 3;                  % degC chilled-water freeze protection
P.t_min_off = 180; P.t_lock = 300;   % s anti-short-cycle / trip lock-out time

% ---- control
P.Kp_valve = 0.8; P.Ki_valve = 3e-4;       % room thermostat -> FCU valve (PI)
P.Kp_comp = 0.25; P.Ki_comp = 1.5e-3;      % chilled-water supply temperature -> compressor speed (PI)
P.f_min = 0.35;
P.comp_on_dT = 1.5; P.comp_off_dT = 2.5;   % K around the chilled-water setpoint
end
