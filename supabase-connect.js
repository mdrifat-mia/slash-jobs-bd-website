(function () {
  const SUPABASE_URL = 'https://buwnriwmcsyfleutdvuw.supabase.co';
  const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1d25yaXdtY3N5ZmxldXRkdnV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDQyOTksImV4cCI6MjEwNzIyMDI5OX0.YAuNs8vvrl9Xr-USNeUyLK9cnBJavjFpw5IT5_TPvmg';

  const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  window.sb = sb;

  // hide the demo role buttons and disable them
  const demoBox = document.querySelector('.demo');
  if (demoBox) demoBox.style.display = 'none';
  window.demoLogin = function () {};

  // real sign in
  window.handleLogin = async function (event) {
    event.preventDefault();
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) { toast('Wrong email or password'); return; }
    await enterApp();
  };

  // load the profile of the signed in user and open the app with their role
  async function enterApp() {
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return;
    const { data: p, error } = await sb.from('profiles')
      .select('id, name, role').eq('id', user.id).single();
    if (error || !p) {
      toast('No profile found for this account');
      await sb.auth.signOut();
      return;
    }
    loginAs(p.role);
    currentUser.name = p.name;
    currentUser.id = p.id;
  }

  // real sign out
  const originalLogout = window.logout;
  window.logout = async function () {
    await sb.auth.signOut();
    originalLogout();
  };

  // keep the user signed in after a page refresh
  sb.auth.getSession().then(({ data: { session } }) => {
    if (session) enterApp();
  });
})();
