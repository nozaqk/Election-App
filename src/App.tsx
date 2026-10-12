import { useCallback, useEffect, useState } from "react";
import { api, getToken, Me, setToken } from "./api";
import { Auth } from "./screens/Auth";
import { Home } from "./screens/Home";
import { ElectionScreen } from "./screens/Election";

export default function App() {
  const [signedIn, setSignedIn] = useState(!!getToken());
  const [me, setMe] = useState<Me | null>(null);
  const [electionId, setElectionId] = useState<string | null>(null);

  const signOut = useCallback(() => { setToken(null); setSignedIn(false); setMe(null); setElectionId(null); }, []);
  useEffect(() => { const f = () => setSignedIn(false); window.addEventListener("election:signed-out", f); return () => window.removeEventListener("election:signed-out", f); }, []);
  useEffect(() => { if (signedIn) api<Me>("/auth/student/me").then(setMe).catch(() => undefined); }, [signedIn]);

  if (!signedIn) return <Auth onDone={() => setSignedIn(true)} />;
  return (
    <>
      <header className="top">
        <h1>{electionId ? <button onClick={() => setElectionId(null)} aria-label="Back">← Back</button> : "Student Election"}</h1>
        <div className="row" style={{ gap: 10 }}>
          {me && <span style={{ fontSize: ".8rem", opacity: .85 }}>{me.indexNumber}</span>}
          <button onClick={signOut}>Sign out</button>
        </div>
      </header>
      <main>
        {electionId
          ? <ElectionScreen id={electionId} />
          : <Home me={me} onOpen={setElectionId} />}
      </main>
    </>
  );
}
