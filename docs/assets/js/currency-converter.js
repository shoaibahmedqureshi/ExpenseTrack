(function () {
  const T = window.T || {
    rateSub: (from, rateStr, to) => `1 ${from} = ${rateStr} ${to}`,
    defaultFrom: 'USD',
    defaultTo: 'PKR',
  };

  const amountInput = document.getElementById('amount');
  const fromSelect = document.getElementById('from');
  const toSelect = document.getElementById('to');
  const swapBtn = document.getElementById('swap');
  const resultBox = document.getElementById('resultBox');
  const errorBox = document.getElementById('errorBox');

  const CURRENCIES = ['USD', 'EUR', 'GBP', 'INR', 'PKR', 'AED', 'AUD', 'CAD', 'CNY', 'JPY', 'SGD', 'CHF', 'SAR', 'TRY', 'BDT', 'IDR', 'VND', 'PHP'];

  CURRENCIES.forEach(c => {
    fromSelect.appendChild(new Option(c, c));
    toSelect.appendChild(new Option(c, c));
  });
  fromSelect.value = T.defaultFrom;
  toSelect.value = T.defaultTo;

  let rateCache = {};

  async function getRate(from, to) {
    if (from === to) return 1;
    const key = from + '_' + to;
    if (rateCache[key]) return rateCache[key];
    const res = await fetch(`https://open.er-api.com/v6/latest/${from}`);
    if (!res.ok) throw new Error('rate fetch failed');
    const data = await res.json();
    const rate = data.rates && data.rates[to];
    if (!rate) throw new Error('rate missing');
    rateCache[key] = rate;
    return rate;
  }

  async function update() {
    const amount = parseFloat(amountInput.value);
    const from = fromSelect.value;
    const to = toSelect.value;
    errorBox.style.display = 'none';

    if (!amount || amount <= 0) {
      resultBox.style.display = 'none';
      return;
    }
    try {
      const rate = await getRate(from, to);
      const converted = amount * rate;
      document.getElementById('resultAmount').textContent =
        converted.toLocaleString(undefined, { maximumFractionDigits: 2 }) + ' ' + to;
      document.getElementById('rateSub').textContent =
        T.rateSub(from, rate.toLocaleString(undefined, { maximumFractionDigits: 4 }), to);
      resultBox.style.display = 'block';
    } catch (e) {
      resultBox.style.display = 'none';
      errorBox.style.display = 'block';
    }
  }

  swapBtn.addEventListener('click', () => {
    const tmp = fromSelect.value;
    fromSelect.value = toSelect.value;
    toSelect.value = tmp;
    update();
  });

  [amountInput, fromSelect, toSelect].forEach(el => el.addEventListener('input', update));
  fromSelect.addEventListener('change', update);
  toSelect.addEventListener('change', update);
  update();
})();
