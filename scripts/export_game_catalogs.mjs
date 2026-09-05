import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const sourceRoot = resolve(process.argv[2] || process.cwd());
const destination = resolve(process.argv[3] || resolve(dirname(fileURLToPath(import.meta.url)), '..'));
const requireSource = createRequire(resolve(sourceRoot, 'package.json'));
const { build } = requireSource('esbuild');
const paths = {
  catalog: 'src/client/contexts/caravan/catalog.ts',
  carriers: 'src/client/contexts/caravan/carrier-catalog.ts',
  coreUpgrades: 'src/client/contexts/caravan/vehicle-upgrades.ts',
  buildRules: 'src/client/contexts/caravan/build-rules.ts',
  roadFury: 'src/client/contexts/caravan/road-fury.ts',
  contracts: 'src/client/contexts/progression/contracts.ts',
  sidegrades: 'src/client/contexts/progression/sidegrades.ts',
  spawning: 'src/client/contexts/combat/spawning.ts',
  director: 'src/client/contexts/combat/director.ts',
  priorityVehicles: 'src/client/contexts/combat/priority-vehicles.ts',
  garrison: 'src/client/contexts/combat/garrison-tuning.ts',
  leviathan: 'src/client/contexts/combat/leviathan.ts',
  counterDroneJammer: 'src/client/contexts/combat/counter-drone-jammer.ts',
  jammerRocket: 'src/client/contexts/combat/jammer-rocket.ts',
  mineHacking: 'src/client/contexts/combat/mine-hacking.ts',
  hazards: 'src/client/contexts/combat/hazards.ts',
  tornado: 'src/client/contexts/combat/tornado.ts',
  combatSynergies: 'src/client/contexts/combat/combat-synergies.ts',
  encounterEffects: 'src/client/contexts/combat/encounter-effects.ts',
  spawnTelegraphs: 'src/client/contexts/combat/spawn-telegraphs.ts',
  worldActivities: 'src/client/contexts/world/world-activity.ts',
  extraction: 'src/client/contexts/world/extraction.ts',
  weather: 'src/shared/gameplay-weather.ts',
  waves: 'src/shared/wave-progression.ts',
  worldBoundary: 'src/shared/world-boundary.ts',
  worldLayout: 'src/shared/world-layout.ts',
  worldCollision: 'src/shared/world-collision-manifest.ts',
  config: 'src/client/core/config.ts',
};
const contents = Object.entries(paths).map(([key, path]) => `import * as ${key} from ${JSON.stringify(resolve(sourceRoot, path))};`).join('\n') + '\nexport default {' + Object.keys(paths).join(',') + '};';
const bundle = await build({ stdin: { contents, resolveDir: sourceRoot, loader: 'ts' }, bundle: true, platform: 'node', format: 'esm', write: false, logLevel: 'silent' });
const { default: namespaces } = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const omittedFunctions = [];
function serializable(value, location) {
  if (typeof value === 'function') { omittedFunctions.push(location); return undefined; }
  if (value instanceof Set) return [...value];
  if (Array.isArray(value)) return value.map((item, index) => serializable(item, `${location}[${index}]`));
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serializable(item, `${location}.${key}`)]).filter(([, item]) => item !== undefined));
  if (typeof value === 'number' && !Number.isFinite(value)) throw Error(`Nonfinite number at ${location}`);
  return value;
}
const constants = Object.fromEntries(Object.entries(namespaces).map(([key, value]) => [key, serializable(value, key)]));
const sources = {};
for (const [key, path] of Object.entries(paths)) sources[key] = { path, sha256: createHash('sha256').update(await readFile(resolve(sourceRoot, path))).digest('hex') };
const catalog = {
  _meta: { schemaVersion: 1, scope: 'singleplayer-offline', origin: 'original TypeScript exports evaluated through esbuild; no tuning invented', sources, omittedFunctions, warning: 'Data equality does not imply Godot behavior or visual parity. Function effects must be ported and tested.' },
  modules: { ...constants.catalog.moduleDefinitions },
  moduleSlots: constants.catalog.moduleSlots,
  levelUpgrades: constants.catalog.upgradeDefinitions,
  coreUpgrades: constants.coreUpgrades.CORE_UPGRADE_DEFINITIONS,
  carriers: constants.carriers,
  protocols: constants.buildRules.PROTOCOL_DEFINITIONS,
  moduleBuildProfiles: { ...constants.buildRules.MODULE_BUILD_PROFILES },
  soldiers: constants.spawning.SOLDIER_STATS,
  drones: constants.spawning.DRONE_DEFINITIONS,
  priorityVehicles: constants.priorityVehicles.PRIORITY_VEHICLE_DEFINITIONS,
  sidegrades: constants.sidegrades.SIDEGRADE_CATALOG,
  contracts: constants.contracts.CONTRACT_CATALOG,
  waves: Array.from({ length: namespaces.waves.FINAL_WAVE }, (_, index) => ({ wave: index + 1, composition: namespaces.waves.waveComposition(index + 1), areaFraction: namespaces.waves.waveAreaFraction(index + 1), radius: namespaces.waves.waveRadius(index + 1), enemyCount: namespaces.waves.waveEnemyCount(index + 1), minimumClearSeconds: namespaces.waves.waveMinimumClearSeconds(index + 1), infantryKinds: namespaces.spawning.getInfantryKindsForWave(index + 1, 4), unlockGuidance: namespaces.director.getWaveUnlockGuidance(index + 1) })),
  constants,
};
const additions = JSON.parse(await readFile(new URL('./godot_module_additions.json', import.meta.url), 'utf8'));
Object.assign(catalog.modules, additions.modules);
Object.assign(catalog.moduleBuildProfiles, additions.moduleBuildProfiles);
catalog._meta.origin = 'original TypeScript exports with explicit Godot module additions';
catalog._meta.nativeAdditions = { source: 'scripts/godot_module_additions.json', modules: Object.keys(additions.modules) };
await mkdir(resolve(destination, 'data'), { recursive: true });
await writeFile(resolve(destination, 'data/game_catalogs.json'), JSON.stringify(catalog, null, 2) + '\n');
console.log(JSON.stringify({ file: resolve(destination, 'data/game_catalogs.json'), modules: Object.keys(catalog.modules).length, levelUpgrades: catalog.levelUpgrades.length, protocols: Object.keys(catalog.protocols).length, contracts: Object.keys(catalog.contracts).length, sourceModules: Object.keys(sources).length, omittedFunctions: omittedFunctions.length }));
