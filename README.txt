CHILLER PLANT BLOCK-CHAIN MODEL (MATLAB)
========================================
Water-cooled vapour-compression chiller (R134a) serving three fan-coil units (one per room of the
earlier 3-room flat). Every major component is a separate block with an input stream, equations and
an output stream. Each block can be switched ON/OFF; an OFF block is bypassed (output = input).

HOW TO RUN
  1. Put ALL files of this folder in one folder and make it the MATLAB current folder.
  2. Type   chiller_gui   in the Command Window.
  3. Press Start. The simulation runs live; flip any block switch or change a control while it runs.
  Requires MATLAB R2018a or newer. No toolboxes, no Python.

FILES
  chiller_gui.m        live GUI: block switches, controls, schematic, stream tables, plots
  plant_defaults.m     all assumed input numbers (loads of the flat, weather, design temperatures ...)
  plant_design.m       sizes every block from the design duty (10 kW, 12/7 C chilled water, 32/37 C CW)
  plant_init.m         initial state, default switches (all ON) and control settings
  plant_step.m         advances the whole plant by dt: chains all blocks, controls, trips, integrates
  plant_log.m          appends outputs to a history struct (used for plots / CSV export)
  solve_refrigerant.m  closes the refrigerant ring (iterates evaporating and condensing temperature)
  BLOCKS (one file each)
    blk_expansion.m    orifice flow + isenthalpic throttling, pressure drop, flash-gas quality
    blk_evaporator.m   refrigerant <-> chilled water, eps-NTU, outlet superheat / wet state
    blk_compressor.m   reciprocating (displacement, clearance, volumetric eff.) or centrifugal (head map, surge)
    blk_condenser.m    refrigerant <-> condenser water, eps-NTU, subcooling result
    blk_pump.m         pump curve vs pipe system curve, power
    blk_fcu.m          chilled-water coil + blower in a room
    blk_tower.m        evaporative cooling tower, approach to wet-bulb, make-up water
  ref_props.m + r134a_props.mat   R134a properties (tables made by make_r134a_tables.py from CoolProp)
  wstream.m            water stream constructor

STREAM FIELDS (refrigerant): P, T, h, s, rho, Tsat, x (quality), phase, superheat, subcool, mdot, vdot
STREAM FIELDS (water):       T, mdot, P, cp, vdot

WHAT HAPPENS WHEN A BLOCK IS OFF
  Chain rule: output = input. Physical consequences (all shown live):
   - Cooling tower OFF      condenser water heats up, condensing temperature rises, high-pressure trip
   - Compressor / evaporator / condenser / expansion valve OFF   refrigerant stops circulating, no cooling
   - CHW pump OFF           no chilled-water flow, rooms warm up
   - CW pump OFF            no condenser flow, chiller cannot run
   - One FCU OFF            that room warms, the others receive more water
  Refrigerant streams then sit at one equalised standby state with zero flow.

SIMPLIFICATIONS (be aware)
  Quasi-steady refrigerant loop (solved every step), lumped room / water-loop capacities, charge is
  represented by a fixed condenser-outlet subcooling, no pressure drop in heat exchangers except the valve,
  humidity is lumped into a coil sensible-heat ratio. The centrifugal option is scaled to this 3 TR duty only
  to demonstrate the model; real centrifugal chillers start around 100-200 TR.
  All numbers are ASSUMED example values.
