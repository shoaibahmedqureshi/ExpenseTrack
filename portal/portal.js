(function () {
  'use strict';
  var cfg = window.OUTLAY_PORTAL;
  var sb = window.supabase.createClient(cfg.supabaseUrl, cfg.anonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'implicit' }
  });
  var view = document.getElementById('view');
  var banner = document.getElementById('banner');
  var PLATFORMS = { tiktok: 'TikTok', youtube: 'YouTube', instagram: 'Instagram', x: 'X', other: 'Other' };
  var BANDS = { under_1k: 'Under 1K', '1k_10k': '1K to 10K', '10k_50k': '10K to 50K', '50k_250k': '50K to 250K', over_250k: 'Over 250K' };
  var STATUS = { pending_confirmation: 'Awaiting confirmation', confirmed: 'Under review', approved: 'Approved', rejected: 'Not accepted', onboarded: 'Active' };

  // Everything user-supplied goes through textContent, never innerHTML.
  function el(tag, attrs) {
    var n = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'text') n.textContent = attrs[k];
      else if (k === 'class') n.className = attrs[k];
      else if (k.slice(0, 2) === 'on') n.addEventListener(k.slice(2), attrs[k]);
      else if (attrs[k] !== undefined && attrs[k] !== null) n.setAttribute(k, attrs[k]);
    });
    (function add(list) {
      list.forEach(function (c) {
        if (c === null || c === undefined || c === false) return;
        if (Array.isArray(c)) return add(c);
        n.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
      });
    })(Array.prototype.slice.call(arguments, 2));
    return n;
  }
  function show(msg, kind) { banner.textContent = msg; banner.className = 'banner ' + (kind || 'ok'); }
  function hideBanner() { banner.className = 'banner hidden'; }
  function mount() { hideBanner(); view.replaceChildren.apply(view, arguments); }
  function msgOf(e) { return (e && (e.message || e.error_description)) || 'Something went wrong. Please try again.'; }
  function opts(map, blank) {
    var out = blank ? [el('option', { value: '', text: blank })] : [];
    Object.keys(map).forEach(function (k) { out.push(el('option', { value: k, text: map[k] })); });
    return out;
  }
  function field(label, input, errKey) {
    return [el('label', { text: label }), input, el('div', { class: 'err', 'data-err': errKey || '' })];
  }
  function dl(pairs) {
    var d = el('dl');
    pairs.forEach(function (p) { if (p[1]) { d.appendChild(el('dt', { text: p[0] })); d.appendChild(el('dd', { text: p[1] })); } });
    return d;
  }
  function safeUrl(u) { return /^https?:\/\//i.test(u || '') ? u : null; }

  // ── Sign in ─────────────────────────────────────────────────────────
  function renderSignIn(note) {
    var email = el('input', { type: 'email', id: 'email', autocomplete: 'email', maxlength: '200', required: 'required' });
    var btn = el('button', { type: 'submit', text: 'Email me a sign-in link' });
    var form = el('form', { onsubmit: function (ev) {
      ev.preventDefault();
      btn.disabled = true;
      sb.auth.signInWithOtp({ email: email.value.trim(), options: { emailRedirectTo: location.origin + location.pathname } })
        .then(function (r) {
          if (r.error) throw r.error;
          renderCheckEmail(email.value.trim());
        })
        .catch(function (e) { show(msgOf(e), 'bad'); })
        .then(function () { btn.disabled = false; });
    } }, field('Email', email), el('div', { class: 'row' }, btn));
    var card = el('div', { class: 'card' },
      el('h1', { text: 'Outlay Creator Program' }),
      el('p', { text: 'Earn 20% of what each subscriber you bring pays, paid once per subscriber. Sign in with your email to apply or check your application. No password needed.' }),
      form);
    if (cfg.googleEnabled) {
      card.appendChild(el('div', { class: 'row' }, el('button', { class: 'secondary', type: 'button', text: 'Continue with Google', onclick: function () {
        sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + location.pathname } });
      } })));
    }
    mount(card);
    if (note) show(note, 'ok');
  }

  function renderCheckEmail(email) {
    var code = el('input', { type: 'text', inputmode: 'numeric', autocomplete: 'one-time-code', maxlength: '8', placeholder: '6-digit code' });
    var btn = el('button', { type: 'submit', text: 'Sign in with code' });
    mount(el('div', { class: 'card' },
      el('h1', { text: 'Check your email' }),
      el('p', { text: 'We sent a sign-in link to ' + email + '. Open it on this device. If your email shows a code instead, enter it here.' }),
      el('p', { class: 'muted', text: 'Nothing arrived? Check spam or Promotions, then try again in a minute.' }),
      el('form', { onsubmit: function (ev) {
        ev.preventDefault(); btn.disabled = true;
        sb.auth.verifyOtp({ email: email, token: code.value.trim(), type: 'email' })
          .then(function (r) { if (r.error) throw r.error; route(); })
          .catch(function (e) { show(msgOf(e), 'bad'); })
          .then(function () { btn.disabled = false; });
      } }, code, el('div', { class: 'row' }, btn,
        el('button', { type: 'button', class: 'secondary', text: 'Use a different email', onclick: function () { renderSignIn(); } })))));
  }

  // A link that carries token_hash lands on a button, so mail scanners that pre-open links can't use it up.
  function renderConfirmButton(tokenHash, type) {
    mount(el('div', { class: 'card' },
      el('h1', { text: 'Finish signing in' }),
      el('p', { text: 'Tap the button to sign in to the Outlay Creator Portal.' }),
      el('div', { class: 'row' }, el('button', { text: 'Sign in', onclick: function (ev) {
        ev.target.disabled = true;
        sb.auth.verifyOtp({ token_hash: tokenHash, type: type || 'email' })
          .then(function (r) { if (r.error) throw r.error; history.replaceState(null, '', location.pathname); route(); })
          .catch(function (e) { renderSignIn(); show('That link has expired or was already used. Request a new one. (' + msgOf(e) + ')', 'bad'); });
      } }))));
  }

  // ── Creator view ────────────────────────────────────────────────────
  function renderApply(user, existing) {
    var f = {
      name: el('input', { type: 'text', maxlength: '100', value: existing ? existing.name : '' }),
      platform: el('select', {}, opts(PLATFORMS, 'Choose…')),
      handle: el('input', { type: 'text', maxlength: '100' }),
      profile_url: el('input', { type: 'url', maxlength: '300', placeholder: 'https://' }),
      audience_band: el('select', {}, opts(BANDS, 'Choose…')),
      niche: el('input', { type: 'text', maxlength: '120' }),
      country: el('input', { type: 'text', maxlength: '60' }),
      about: el('textarea', { maxlength: '1000' })
    };
    var consent = el('input', { type: 'checkbox' });
    if (existing) {
      ['platform', 'handle', 'profile_url', 'audience_band', 'niche', 'country', 'about'].forEach(function (k) { f[k].value = existing[k] || ''; });
    }
    var btn = el('button', { type: 'submit', text: existing ? 'Update application' : 'Submit application' });
    var form = el('form', { novalidate: 'novalidate', onsubmit: function (ev) {
      ev.preventDefault();
      var body = { consent: consent.checked };
      Object.keys(f).forEach(function (k) { body[k] = f[k].value.trim(); });
      btn.disabled = true;
      sb.rpc('submit_creator_application', { p: body })
        .then(function (r) { if (r.error) throw r.error; renderStatus(user, r.data); show('Application received. We review each one by hand.', 'ok'); })
        .catch(function (e) { show(msgOf(e), 'bad'); })
        .then(function () { btn.disabled = false; });
    } },
      field('Your name', f.name), field('Main platform', f.platform), field('Handle or channel name', f.handle),
      field('Link to your profile (optional)', f.profile_url), field('Audience size', f.audience_band),
      field('What do you create content about?', f.niche), field('Country (optional)', f.country),
      field('Anything else we should know (optional)', f.about),
      el('label', { class: 'check' }, consent, el('span', { text: 'I agree that Outlay may email me about the Creator Program.' })),
      el('div', { class: 'row' }, btn));
    mount(el('div', { class: 'card' }, el('h1', { text: existing ? 'Edit your application' : 'Apply to the Creator Program' }),
      el('p', { class: 'muted', text: 'Signed in as ' + user.email + '. You will get a personal discount code once approved.' }), form));
  }

  function renderStatus(user, app) {
    var s = app.status;
    var card = el('div', { class: 'card' },
      el('h1', { text: 'Your application' }),
      el('p', {}, el('span', { class: 'pill ' + s, text: STATUS[s] || s })),
      dl([['Name', app.name], ['Platform', PLATFORMS[app.platform] || app.platform], ['Handle', app.handle],
          ['Audience', BANDS[app.audience_band]], ['Niche', app.niche], ['Country', app.country]]));
    if (s === 'approved' || s === 'onboarded') {
      card.appendChild(el('h2', { text: 'Your discount code' }));
      if (app.assigned_code) {
        card.appendChild(el('div', { class: 'code', text: app.assigned_code }));
        card.appendChild(el('p', { class: 'muted', text: 'Share this with your audience. You earn 20% of what each new subscriber who uses it pays, paid once per subscriber.' }));
      } else {
        card.appendChild(el('p', { text: 'You are approved. We are setting up your personal code and will email you shortly.' }));
      }
    } else if (s === 'rejected') {
      card.appendChild(el('p', { text: 'Thanks for applying. We are not able to take this one forward right now.' }));
    } else {
      card.appendChild(el('p', { text: 'We review each application by hand and will email you at ' + user.email + '.' }));
      card.appendChild(el('div', { class: 'row' }, el('button', { class: 'secondary', text: 'Edit application', onclick: function () { renderApply(user, app); } })));
    }
    mount(card);
  }

  // ── Admin view ──────────────────────────────────────────────────────
  function renderMfa(user, factors, onDone) {
    var verified = (factors.totp || []).filter(function (f) { return f.status === 'verified'; })[0];
    var code = el('input', { type: 'text', inputmode: 'numeric', autocomplete: 'one-time-code', maxlength: '6', placeholder: '6-digit code' });
    var holder = el('div');
    function verify(factorId) {
      sb.auth.mfa.challengeAndVerify({ factorId: factorId, code: code.value.trim() })
        .then(function (r) { if (r.error) throw r.error; onDone(); })
        .catch(function (e) { show(msgOf(e), 'bad'); });
    }
    var card = el('div', { class: 'card' }, el('h1', { text: 'Admin verification' }), holder);
    if (verified) {
      holder.appendChild(el('p', { text: 'Enter the code from your authenticator app to open the admin area.' }));
      holder.appendChild(code);
      holder.appendChild(el('div', { class: 'row' }, el('button', { text: 'Verify', onclick: function () { verify(verified.id); } })));
      mount(card);
    } else {
      // Drop any half-finished enrolment first, then start a fresh one.
      var stale = (factors.all || []).filter(function (f) { return f.factor_type === 'totp' && f.status !== 'verified'; });
      Promise.all(stale.map(function (f) { return sb.auth.mfa.unenroll({ factorId: f.id }); }))
        .then(function () { return sb.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'Authenticator ' + Date.now() }); })
        .then(function (r) {
          if (r.error) throw r.error;
          var qr = el('img', { src: r.data.totp.qr_code, alt: 'QR code', width: '180', height: '180' });
          holder.appendChild(el('p', { text: 'Admin accounts need a second step. Scan this QR code with an authenticator app (1Password, Google Authenticator, Authy), then enter the 6-digit code.' }));
          holder.appendChild(qr);
          holder.appendChild(el('p', { class: 'muted', text: 'Or enter this key by hand: ' + r.data.totp.secret }));
          holder.appendChild(code);
          holder.appendChild(el('div', { class: 'row' }, el('button', { text: 'Turn on and verify', onclick: function () { verify(r.data.id); } })));
          mount(card);
        })
        .catch(function (e) { mount(card); show(msgOf(e), 'bad'); });
    }
  }

  function renderAdmin(user) {
    var filter = 'confirmed';
    var listBox = el('div', { class: 'list' });
    var select = el('select', { onchange: function () { filter = select.value; load(); } },
      el('option', { value: 'confirmed', text: 'Waiting for review' }),
      el('option', { value: 'approved', text: 'Approved' }),
      el('option', { value: 'rejected', text: 'Not accepted' }),
      el('option', { value: 'pending_confirmation', text: 'Not confirmed yet' }),
      el('option', { value: 'all', text: 'All' }));
    mount(el('div', { class: 'card' }, el('h1', { text: 'Creator applications' }), select, listBox));
    function load() {
      listBox.replaceChildren(el('p', { class: 'muted', text: 'Loading…' }));
      var q = sb.from('creator_applications').select('id,name,email,platform,handle,audience_band,niche,status,created_at').order('created_at', { ascending: false }).limit(200);
      if (filter !== 'all') q = q.eq('status', filter);
      q.then(function (r) {
        if (r.error) throw r.error;
        if (!r.data.length) { listBox.replaceChildren(el('p', { class: 'muted', text: 'Nothing here.' })); return; }
        listBox.replaceChildren.apply(listBox, r.data.map(function (a) {
          return el('div', { onclick: function () { openDetail(a.id); } },
            el('div', { class: 'grow' }, el('strong', { text: a.name }),
              el('small', { text: (PLATFORMS[a.platform] || a.platform) + ' · ' + a.handle + ' · ' + (BANDS[a.audience_band] || '') })),
            el('span', { class: 'pill ' + a.status, text: STATUS[a.status] || a.status }));
        }));
      }).catch(function (e) { listBox.replaceChildren(); show(msgOf(e), 'bad'); });
    }
    function openDetail(id) {
      sb.from('creator_applications').select('*').eq('id', id).single().then(function (r) {
        if (r.error) throw r.error;
        var a = r.data;
        var notes = el('textarea', { maxlength: '2000' }); notes.value = a.admin_notes || '';
        var code = el('input', { type: 'text', maxlength: '40', placeholder: 'e.g. SARA20' }); code.value = a.assigned_code || '';
        var url = safeUrl(a.profile_url);
        function decide(status) {
          var c = code.value.trim();
          if (status === 'approved' && c && !/^[A-Za-z0-9_-]{3,40}$/.test(c)) { show('Code must be 3 to 40 letters, numbers, - or _', 'bad'); return; }
          var patch = { status: status, admin_notes: notes.value.trim() || null, decided_at: new Date().toISOString(), decided_by: user.id };
          if (status === 'approved') patch.assigned_code = c || null;
          sb.from('creator_applications').update(patch).eq('id', a.id).select('id').then(function (u) {
            if (u.error) throw u.error;
            if (!u.data.length) throw new Error('Could not save the decision');
            renderAdmin(user); show('Saved.', 'ok');
          }).catch(function (e) { show(msgOf(e), 'bad'); });
        }
        var reviewable = a.status === 'confirmed';
        mount(el('div', { class: 'card' },
          el('button', { class: 'link', text: '← Back', onclick: function () { renderAdmin(user); } }),
          el('h1', { text: a.name }),
          el('p', {}, el('span', { class: 'pill ' + a.status, text: STATUS[a.status] || a.status })),
          dl([['Email', a.email], ['Platform', PLATFORMS[a.platform] || a.platform], ['Handle', a.handle], ['Audience', BANDS[a.audience_band]],
              ['Niche', a.niche], ['Country', a.country], ['About', a.about], ['Applied', new Date(a.created_at).toLocaleString()], ['Source', a.source]]),
          url ? el('p', {}, el('a', { href: url, target: '_blank', rel: 'noopener noreferrer', text: 'Open profile' })) : null,
          field('Discount code to give them (create the store offers first)', code),
          field('Notes', notes),
          el('div', { class: 'row' },
            el('button', { text: a.status === 'approved' ? 'Save code and notes' : 'Approve', onclick: function () { decide('approved'); } }),
            reviewable ? el('button', { class: 'danger', text: 'Reject', onclick: function () { decide('rejected'); } }) : null)));
      }).catch(function (e) { show(msgOf(e), 'bad'); });
    }
    load();
  }

  // ── Routing ─────────────────────────────────────────────────────────
  function route() {
    sb.auth.getSession().then(function (s) {
      var session = s.data.session;
      var out = document.getElementById('signout'), who = document.getElementById('who');
      if (!session) { out.classList.add('hidden'); who.textContent = ''; renderSignIn(); return; }
      var user = session.user;
      out.classList.remove('hidden'); who.textContent = user.email;
      return sb.rpc('is_app_admin').then(function (r) {
        if (r.data === true) {
          return sb.auth.mfa.getAuthenticatorAssuranceLevel().then(function (a) {
            if (a.data && a.data.currentLevel === 'aal2') return renderAdmin(user);
            return sb.auth.mfa.listFactors().then(function (fl) { renderMfa(user, fl.data || {}, route); });
          });
        }
        return sb.rpc('my_creator_application').then(function (m) {
          if (m.error) throw m.error;
          if (m.data) renderStatus(user, m.data); else renderApply(user, null);
        });
      });
    }).catch(function (e) { show(msgOf(e), 'bad'); });
  }

  document.getElementById('signout').addEventListener('click', function () {
    sb.auth.signOut().then(function () { route(); });
  });

  var q = new URLSearchParams(location.search);
  if (q.get('token_hash')) { renderConfirmButton(q.get('token_hash'), q.get('type')); }
  else { route(); }
  sb.auth.onAuthStateChange(function (ev) { if (ev === 'SIGNED_IN' && !q.get('token_hash')) route(); });
})();
