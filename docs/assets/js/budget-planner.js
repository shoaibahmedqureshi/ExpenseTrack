(function () {
  const T = window.T || {
    incomePlaceholder: 'e.g. Salary',
    expensePlaceholders: ['e.g. Rent', 'e.g. Groceries', 'e.g. Subscriptions'],
    untitled: 'Untitled',
    csv: {
      title: 'Monthly Budget Planner',
      currency: 'Currency',
      incomeHeader: 'Income,Amount',
      totalIncome: 'Total Income',
      expensesHeader: 'Expenses,Amount',
      totalExpenses: 'Total Expenses',
      leftover: 'Leftover',
    },
  };

  const incomeRows = document.getElementById('incomeRows');
  const expenseRows = document.getElementById('expenseRows');
  const currencySelect = document.getElementById('currency');

  function addRow(container, placeholder, listId, name = '', amount = '') {
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `
      <input type="text" class="name" list="${listId}" placeholder="${placeholder}" value="${name}">
      <input type="number" class="amount" placeholder="0" min="0" step="0.01" value="${amount}">
      <button type="button" class="remove" aria-label="${T.removeLabel || 'Remove'}">×</button>
    `;
    row.querySelector('.remove').addEventListener('click', () => { row.remove(); update(); });
    row.querySelectorAll('input').forEach(inp => inp.addEventListener('input', update));
    container.appendChild(row);
  }

  document.querySelectorAll('.add-row').forEach(btn => {
    btn.addEventListener('click', () => {
      if (btn.dataset.target === 'income') addRow(incomeRows, T.incomePlaceholder, 'incomeSuggestions');
      else addRow(expenseRows, T.expensePlaceholders[0], 'expenseSuggestions');
    });
  });

  addRow(incomeRows, T.incomePlaceholder, 'incomeSuggestions');
  addRow(expenseRows, T.expensePlaceholders[0], 'expenseSuggestions');
  addRow(expenseRows, T.expensePlaceholders[1], 'expenseSuggestions');
  addRow(expenseRows, T.expensePlaceholders[2], 'expenseSuggestions');

  function sumRows(container) {
    let total = 0;
    container.querySelectorAll('.row').forEach(row => {
      const val = parseFloat(row.querySelector('.amount').value);
      if (!isNaN(val)) total += val;
    });
    return total;
  }

  function format(n, symbol) {
    return symbol + n.toLocaleString(undefined, { maximumFractionDigits: 0 });
  }

  function update() {
    const symbol = currencySelect.value;
    const income = sumRows(incomeRows);
    const expenses = sumRows(expenseRows);
    const leftover = income - expenses;

    document.getElementById('totalIncome').textContent = format(income, symbol);
    document.getElementById('totalExpenses').textContent = format(expenses, symbol);
    const leftoverBox = document.getElementById('leftoverBox');
    const leftoverEl = document.getElementById('leftover');
    leftoverEl.textContent = format(leftover, symbol);
    leftoverBox.classList.toggle('negative', leftover < 0);
  }

  currencySelect.addEventListener('change', update);
  update();

  function csvEscape(value) {
    const str = String(value);
    return /[",\n]/.test(str) ? '"' + str.replace(/"/g, '""') + '"' : str;
  }

  function rowsToCsvLines(container) {
    const lines = [];
    container.querySelectorAll('.row').forEach(row => {
      const name = row.querySelector('.name').value.trim();
      const amount = row.querySelector('.amount').value;
      if (!name && !amount) return;
      lines.push([csvEscape(name || T.untitled), csvEscape(amount || '0')].join(','));
    });
    return lines;
  }

  document.getElementById('printBtn').addEventListener('click', () => window.print());

  document.getElementById('downloadBtn').addEventListener('click', () => {
    const symbol = currencySelect.value;
    const income = sumRows(incomeRows);
    const expenses = sumRows(expenseRows);
    const leftover = income - expenses;

    const csvLines = [
      T.csv.title,
      `${T.csv.currency},${csvEscape(symbol)}`,
      '',
      T.csv.incomeHeader,
      ...rowsToCsvLines(incomeRows),
      `${T.csv.totalIncome},${income}`,
      '',
      T.csv.expensesHeader,
      ...rowsToCsvLines(expenseRows),
      `${T.csv.totalExpenses},${expenses}`,
      '',
      `${T.csv.leftover},${leftover}`,
    ];

    const blob = new Blob([csvLines.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'monthly-budget-plan.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  });
})();
