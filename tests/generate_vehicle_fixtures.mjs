import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const sourceRoot = resolve(process.argv[2] ?? '.');
const require = createRequire(resolve(sourceRoot, 'package.json'));
const { build } = require('esbuild');
const bundled = await build({
  stdin: {
    contents: `export { stepVehicleMotion } from './src/shared/vehicle-motion.ts';
export { consumeVehicleFuel, vehicleMaxSpeed, vehicleDriveAcceleration, applyVehicleUpgrade } from './src/client/contexts/caravan/vehicle-upgrades.ts';`,
    resolveDir: sourceRoot,
    loader: 'ts',
  },
  bundle: true,
  write: false,
  platform: 'node',
  format: 'esm',
});
const { stepVehicleMotion, consumeVehicleFuel, vehicleMaxSpeed, vehicleDriveAcceleration, applyVehicleUpgrade } = await import(`data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`);
const fields = { x: 'x', z: 'z', speed: 'speed', heading: 'heading', moveHeading: 'move_heading', throttle: 'throttle', steer: 'steer', yawVelocity: 'yaw_velocity', slipAngle: 'slip_angle' };
const scenarios = [
  { name: 'actual_starter', player: {weight:12}, segments:[{steps:300,throttle:1,steer:.2}] },
  { name: 'upgraded_motor_fuel', player:{weight:12,level:4,speedMult:1.14}, upgrades:['motor','motor','fuel','armor'], segments:[{steps:300,throttle:1,steer:.4},{steps:180,throttle:1,nitro:true}] },
  { name: 'loaded_trailer', player:{weight:20,level:2,fuelBurnMult:1.12}, upgrades:['motor'], segments:[{steps:300,throttle:1,steer:-.6},{steps:180,throttle:-1}] },
  { name: 'forward_coast', segments: [{ steps: 180, throttle: 1 }, { steps: 180 }] },
  { name: 'forward_reverse', segments: [{ steps: 180, throttle: 1 }, { steps: 240, throttle: -1, steer: -0.4 }] },
  { name: 'drift_heading_wrap', segments: [{ steps: 180, throttle: 1 }, { steps: 600, throttle: 1, steer: 1, handbrake: true }] },
  { name: 'nitro', segments: [{ steps: 180, throttle: 1, nitro: true }, { steps: 180, throttle: 1, steer: -1 }] },
  { name: 'ram', segments: [{ steps: 180, throttle: 1, ram: true }] },
  { name: 'empty_fuel', initial_fuel: 0, segments: [{ steps: 240, throttle: 1 }, { steps: 120, throttle: 1, nitro: true, ram: true }] },
  { name: 'fuel_depletion', initial_fuel: 0.2, segments: [{ steps: 360, throttle: 1, steer: 0.3 }] },
  { name: 'wet_traction', traction: 0.65, segments: [{ steps: 300, throttle: 1, steer: -1 }, { steps: 180, throttle: -1, handbrake: true }] },
];
for (const scenario of scenarios) {
  const state = Object.fromEntries(Object.keys(fields).map((key) => [key, 0]));
  const player = { fuel: scenario.initial_fuel ?? 100, maxFuel: 100, level: 1, weight: 10, speedMult: 1, hp:250,maxHp:250, ...scenario.player };
  for (const upgrade of scenario.upgrades??[]) applyVehicleUpgrade(player,upgrade);
  scenario.stats = Object.fromEntries(Object.entries(player).map(([key,value])=>[key.replace(/[A-Z]/g,c=>'_'+c.toLowerCase()),value]));
  scenario.initial_fuel = player.fuel;
  scenario.traction ??= 1;
  scenario.frames = [];
  for (const segment of scenario.segments) {
    const controls = { throttle: segment.throttle ?? 0, steer: segment.steer ?? 0, handbrake: segment.handbrake ?? false };
    for (let step = 0; step < segment.steps; step++) {
      const tuning = { maximumSpeed: vehicleMaxSpeed(player), acceleration: vehicleDriveAcceleration(player), braking: 15.5*player.speedMult, traction: scenario.traction, fueled: player.fuel > 0, nitro: segment.nitro ?? false, ram: segment.ram ?? false };
      stepVehicleMotion(state, controls, tuning, 1 / 60);
      consumeVehicleFuel(player, 1 / 60, state.speed, controls.throttle);
      if ((step + 1) % 60 === 0 || step === segment.steps - 1) {
        scenario.frames.push({ after_step: scenario.segments.slice(0, scenario.segments.indexOf(segment)).reduce((sum, item) => sum + item.steps, 0) + step + 1, fuel: player.fuel, ...Object.fromEntries(Object.entries(fields).map(([jsName, gdName]) => [gdName, state[jsName]])) });
      }
    }
  }
}
const output = fileURLToPath(new URL('./fixtures/vehicle_motion.json', import.meta.url));
writeFileSync(output, JSON.stringify({ source: 'src/shared/vehicle-motion.ts and src/client/contexts/caravan/vehicle-upgrades.ts', delta: 1 / 60, scenarios }, null, 2) + '\n');
console.log(`Generated ${scenarios.length} scenarios into ${output}`);
