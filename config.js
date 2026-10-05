/* Injected per deployment — this file is what makes the page "hosted".
   Absent (opening index.html on its own) the app falls back to IndexedDB and
   runs exactly as the local build did.

   The anon key is public by design: it identifies the project, it does not
   grant access. Every row the app can read or write is decided by row-level
   security in Postgres, against the signed-in user's role. */
window.__SB_URL__  = 'https://mkzcykmbienlnnbaicwg.supabase.co';
window.__SB_ANON__ = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1remN5a21iaWVubG5uYmFpY3dnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExODUxMjUsImV4cCI6MjEwNjc2MTEyNX0.z1G_E5xZsxlZfjjaSDc8ywpdz5t25wFVc-PnCEsaoq0';
