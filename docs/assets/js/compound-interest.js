(function () {
  const T = window.T || {
    yearLabel: (yr) => 'Yr ' + yr,
  };

  const principalInput = document.getElementById('principal');
  const contributionInput = document.getElementById('contribution');
  const yearsInput = document.getElementById('years');
  const rateInput = document.getElementById('rate');
  const currencySelect = document.getElementById('currency');
  const resultBox = document.getElementById('resultBox');

  function format(n, symbol) {
    return symbol + n.toLocaleString(undefined, { maximumFractionDigits: 0 });
  }

  function update() {
    const principal = parseFloat(principalInput.value) || 0;
    const contribution = parseFloat(contributionInput.value) || 0;
    const years = parseFloat(yearsInput.value);
    const annualRatePct = parseFloat(rateInput.value) || 0;
    const symbol = currencySelect.value;

    if (!years || years <= 0) {
      resultBox.style.display = 'none';
      return;
    }
    const months = Math.round(years * 12);
    const r = annualRatePct / 100 / 12;

    let balance = principal;
    let totalContributed = principal;
    const series = [{ year: 0, balance, contributed: totalContributed }];
    for (let i = 0; i < months; i++) {
      balance += contribution;
      totalContributed += contribution;
      balance *= (1 + r);
      if ((i + 1) % 12 === 0) {
        series.push({ year: (i + 1) / 12, balance, contributed: totalContributed });
      }
    }
    if (months % 12 !== 0) {
      series.push({ year: months / 12, balance, contributed: totalContributed });
    }

    const totalInterest = balance - totalContributed;

    document.getElementById('futureValue').textContent = format(balance, symbol);
    document.getElementById('totalContributed').textContent = format(totalContributed, symbol);
    document.getElementById('totalInterest').textContent = format(totalInterest, symbol);
    resultBox.style.display = 'block';
    drawChart(series);
  }

  function drawChart(series) {
    const chartWrap = document.getElementById('chartWrap');
    chartWrap.style.display = 'block';
    const canvas = document.getElementById('growthChart');
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const cssWidth = canvas.clientWidth;
    const cssHeight = canvas.clientHeight;
    canvas.width = cssWidth * dpr;
    canvas.height = cssHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssWidth, cssHeight);

    const padding = { top: 10, right: 8, bottom: 22, left: 8 };
    const w = cssWidth - padding.left - padding.right;
    const h = cssHeight - padding.top - padding.bottom;
    const maxBalance = Math.max(...series.map(p => p.balance), 1);
    const maxYear = series[series.length - 1].year || 1;

    const x = (year) => padding.left + (year / maxYear) * w;
    const y = (val) => padding.top + h - (val / maxBalance) * h;

    ctx.beginPath();
    ctx.moveTo(x(series[0].year), y(0));
    series.forEach(p => ctx.lineTo(x(p.year), y(p.contributed)));
    ctx.lineTo(x(maxYear), y(0));
    ctx.closePath();
    ctx.fillStyle = '#0F766E';
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(x(series[0].year), y(series[0].contributed));
    series.forEach(p => ctx.lineTo(x(p.year), y(p.contributed)));
    for (let i = series.length - 1; i >= 0; i--) {
      ctx.lineTo(x(series[i].year), y(series[i].balance));
    }
    ctx.closePath();
    ctx.fillStyle = '#5EEAD4';
    ctx.fill();

    ctx.fillStyle = '#5b6169';
    ctx.font = '11px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.textAlign = 'center';
    ctx.direction = 'ltr';
    const midYear = Math.round(maxYear / 2);
    [0, midYear, Math.round(maxYear)].forEach(yr => {
      ctx.fillText(T.yearLabel(yr), x(yr), cssHeight - 6);
    });
  }

  [principalInput, contributionInput, yearsInput, rateInput, currencySelect].forEach(el =>
    el.addEventListener('input', update));
  update();
})();
