const BASE: string = (import.meta.env.VITE_API_URL ?? "").replace(/\/$/, "");
const KEY = "election.session";

export interface Session { token: string; exp: number }
export const getToken = (): string | null => {
  try { const s: Session | null = JSON.parse(localStorage.getItem(KEY) ?? "null"); return s && s.exp > Date.now() ? s.token : null; } catch { return null; }
};
export const setToken = (token: string | null) => {
  try { if (token) localStorage.setItem(KEY, JSON.stringify({ token, exp: Date.now() + 11 * 3600_000 })); else localStorage.removeItem(KEY); } catch { /* storage unavailable */ }
};

export class ApiError extends Error {
  constructor(public status: number, message: string, public code?: string, public details?: unknown) { super(message); }
}

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const t = getToken();
  let res: Response;
  try {
    res = await fetch(BASE + path, {
      method: init.method ?? (init.body ? "POST" : "GET"),
      headers: { "Content-Type": "application/json", ...(t ? { Authorization: `Bearer ${t}` } : {}) },
      body: init.body ? JSON.stringify(init.body) : undefined,
    });
  } catch { throw new ApiError(0, "Cannot reach the server. Check your internet connection and try again.", "NETWORK"); }
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && t) { setToken(null); window.dispatchEvent(new Event("election:signed-out")); }
  if (!res.ok) throw new ApiError(res.status, data.error ?? "Something went wrong.", data.code, data.details);
  return data as T;
}

// ── types ──
export interface UiState { state: string; headline: string; body: string }
export interface ElectionSummary {
  id: string; title: string; description: string; status: string; startAt: string | null; endAt: string | null;
  startLabel: string | null; endLabel: string | null; requirePresence: boolean; hasVoted: boolean; canVote: boolean; ui: UiState;
}
export interface Overview { serverTime: string; elections: ElectionSummary[]; empty: { headline: string; body: string } | null }
export interface Candidate { id: string; name: string; number: number; photoUrl: string | null; manifesto: string; department: string | null; programme: string | null }
export interface Position { id: string; title: string; maxSelections: number; allowAbstain: boolean; candidates: Candidate[] }
export interface ElectionDetail extends ElectionSummary { positions: Position[]; serverTime: string }
export interface PositionResult {
  positionId: string; title: string; seats: number; abstained: number; totalVotes: number; tie: boolean; runoffRequired: boolean;
  candidates: { candidateId: string; name: string; number: number; photoUrl: string | null; votes: number; winner: boolean; tied: boolean }[];
}
export interface Results { id: string; title: string; status: string; publishedLabel: string | null; turnout: number; results: PositionResult[] }
export interface Me { indexNumber: string; fullName: string; department: string; programme: string; level: number; semester: number | null; officialLevel: number }
