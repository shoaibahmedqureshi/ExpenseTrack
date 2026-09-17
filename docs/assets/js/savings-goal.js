(function () {
  const T = window.T || {
    monthlySuffix: (amountStr) => amountStr + ' / month',
    monthsSub: (n) => 'over ' + n + ' month' + (n === 1 ? '' : 's'),
    equivSub: (weeklyStr, dailyStr) => 'or ' + weeklyStr + ' / week · ' + dailyStr + ' / day',
  };

  const goalInput = document.getElementById('goal');
  const currentInput = document.getElementById('current');
  const yearsInput = document.getElementById('years');
  const monthsInput = document.getElementById('months');
  const rateInput = document.getElementById('rate');
  const currencySelect = document.getElementById('currency');
  const resultBox = document.getElementById('resultBox');

  function update() {
    const goal = parseFloat(goalInput.value);
    const current = parseFloat(currentInput.value) || 0;
    const annualRatePct = parseFloat(rateInput.value) || 0;
    const symbol = currencySelect.value;
    const years = parseFloat(yearsInput.value) || 0;
    const months = parseFloat(monthsInput.value) || 0;
    const n = Math.round(years * 12 + months);

    if (!goal || goal <= 0 || n <= 0) {
      resultBox.style.display = 'none';
      return;
    }
    const remaining = Math.max(0, goal - current);

    let monthly;
    if (annualRatePct > 0) {
      const r = annualRatePct / 100 / 12;
      const fvCurrent = current * Math.pow(1 + r, n);
      const stillNeeded = Math.max(0, goal - fvCurrent);
      const annuityFactor = (Math.pow(1 + r, n) - 1) / r;
      monthly = stillNeeded / annuityFactor;
    } else {
      monthly = remaining / n;
    }

    const weekly = (monthly * 12) / 52;
    const daily = (monthly * 12) / 365;

    const monthlyStr = symbol + monthly.toLocaleString(undefined, { maximumFractionDigits: 0 });
    const weeklyStr = symbol + weekly.toLocaleString(undefined, { maximumFractionDigits: 0 });
    const dailyStr = symbol + daily.toLocaleString(undefined, { maximumFractionDigits: 2 });

    document.getElementById('monthlyAmount').textContent = T.monthlySuffix(monthlyStr);
    document.getElementById('monthsSub').textContent = T.monthsSub(n);
    document.getElementById('equivSub').textContent = T.equivSub(weeklyStr, dailyStr);
    resultBox.style.display = 'block';
  }

  [goalInput, currentInput, yearsInput, monthsInput, rateInput, currencySelect].forEach(el =>
    el.addEventListener('input', update));
})();
