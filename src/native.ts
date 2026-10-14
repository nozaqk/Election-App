/**
 * Bridge to the Android app (androidx.webkit WebMessageListener, origin-restricted to this site).
 * In a normal browser `window.ElectionNative` does not exist, so presence-gated voting asks for the app.
 */
interface NativePort { postMessage(msg: string): void; onmessage: ((e: { data: string }) => void) | null }
declare global { interface Window { ElectionNative?: NativePort } }

export interface BeaconClaim { beaconId: number; bootNonce: string; counter: number; mac: string }
export const hasNative = () => typeof window !== "undefined" && !!window.ElectionNative;

type Pending = { resolve: (c: BeaconClaim[]) => void; reject: (e: NativeError) => void; timer: number };
const pending = new Map<string, Pending>();
let wired = false;
export type BtState = "off" | "on" | "node";   // off = phone Bluetooth off, on = Bluetooth on, node = a polling-node signal is in range
const btListeners = new Set<(s: BtState) => void>();
let btState: BtState | null = null;

export class NativeError extends Error { constructor(public code: string, message: string) { super(message); } }

function wire() {
  if (wired || !window.ElectionNative) return;
  wired = true;
  window.ElectionNative.onmessage = (e) => {
    let m: { type: string; id: string; claims?: BeaconClaim[]; code?: string; message?: string; on?: boolean; node?: boolean };
    try { m = JSON.parse(e.data); } catch { return; }
    if (m.type === "bluetooth") { btState = !m.on ? "off" : m.node ? "node" : "on"; btListeners.forEach((f) => f(btState!)); return; }
    const p = pending.get(m.id);
    if (!p) return;
    clearTimeout(p.timer); pending.delete(m.id);
    if (m.type === "scanResult" && m.claims?.length) p.resolve(m.claims);
    else p.reject(new NativeError(m.code ?? "ERROR", m.message ?? "Scan failed."));
  };
}

/** Ask the app to scan for polling nodes. Resolves with up to 3 candidate beacons (strongest first); the server decides which is authorised. */
export function scanForNode(timeoutMs = 15000): Promise<BeaconClaim[]> {
  if (!window.ElectionNative) return Promise.reject(new NativeError("NO_APP", "Presence verification needs the Election Android app."));
  wire();
  const id = crypto.randomUUID();
  return new Promise((resolve, reject) => {
    const timer = window.setTimeout(() => { pending.delete(id); reject(new NativeError("TIMEOUT", "No polling device found. Move closer to the polling device and try again.")); }, timeoutMs + 3000);
    pending.set(id, { resolve, reject, timer });
    window.ElectionNative!.postMessage(JSON.stringify({ type: "scan", id, timeoutMs }));
  });
}

export const openAppSettings = () => window.ElectionNative?.postMessage(JSON.stringify({ type: "openSettings" }));

/** Follow the phone's Bluetooth state (app only). Calls back now if known, then on every change; returns an unsubscribe. */
export function watchBluetooth(cb: (s: BtState) => void): () => void {
  if (!window.ElectionNative) return () => undefined;
  wire();
  btListeners.add(cb);
  if (btState !== null) cb(btState);
  window.ElectionNative.postMessage(JSON.stringify({ type: "btStatus" }));
  return () => { btListeners.delete(cb); };
}
/** Ask the app to show the system "turn on Bluetooth" prompt again. */
export const askBluetoothOn = () => window.ElectionNative?.postMessage(JSON.stringify({ type: "btEnable" }));
