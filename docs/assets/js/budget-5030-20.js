(function () {
  const T = window.T || { total: 'Total' };

  const incomeInput = document.getElementById('income');
  const currencySelect = document.getElementById('currency');
  const results = document.getElementById('results');
  const needsInput = document.getElementById('needsInput');
  const wantsInput = document.getElementById('wantsInput');
  const savingsInput = document.getElementById('savingsInput');
  const splitTotal = document.getElementById('splitTotal');

  function format(n, symbol) {
    return symbol + n.toLocaleString(undefined, { maximumFractionDigits: 0 });
  }

  function update() {
    const income = parseFloat(incomeInput.value);
    const symbol = currencySelect.value;
    const needsPct = parseFloat(needsInput.value) || 0;
    const wantsPct = parseFloat(wantsInput.value) || 0;
    const savingsPct = parseFloat(savingsInput.value) || 0;
    const total = needsPct + wantsPct + savingsPct;

    splitTotal.textContent = `${T.total}: ${total}%`;
    splitTotal.classList.toggle('warn', total !== 100);

    document.getElementById('needsPct').textContent = needsPct;
    document.getElementById('wantsPct').textContent = wantsPct;
    document.getElementById('savingsPct').textContent = savingsPct;

    if (!income || income <= 0) {
      results.style.display = 'none';
      return;
    }
    document.getElementById('needs').textContent = format(income * (needsPct / 100), symbol);
    document.getElementById('wants').textContent = format(income * (wantsPct / 100), symbol);
    document.getElementById('savings').textContent = format(income * (savingsPct / 100), symbol);
    results.style.display = 'grid';
  }

  incomeInput.addEventListener('input', update);
  currencySelect.addEventListener('change', update);
  [needsInput, wantsInput, savingsInput].forEach(el => el.addEventListener('input', update));

  document.getElementById('resetSplit').addEventListener('click', () => {
    needsInput.value = 50;
    wantsInput.value = 30;
    savingsInput.value = 20;
    update();
  });

  update();
})();
