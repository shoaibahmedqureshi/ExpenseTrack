(function () {
  const T = window.T || {
    personDefault: (n) => 'Person ' + n,
    namePlaceholder: 'Name',
    itemNamePlaceholder: 'e.g. Burger',
    removePerson: 'Remove person',
    removeItem: 'Remove item',
    csv: {
      titleEven: 'Bill Splitter — Even Split',
      titleItemized: 'Bill Splitter — Itemized Split',
      currency: 'Currency',
      billAmount: 'Bill Amount',
      taxPct: 'Tax (%)',
      taxAmount: 'Tax Amount',
      tipPct: 'Tip (%)',
      tipAmount: 'Tip Amount',
      total: 'Total',
      splitBetween: 'Split Between',
      people: 'people',
      perPerson: 'Per Person',
      itemHeader: 'Item,Price,Shared By',
      subtotal: 'Subtotal',
      taxTip: 'Tax + Tip',
      personHeader: 'Person,Ordered,Owes',
    },
  };

  const billInput = document.getElementById('bill');
  const taxInput = document.getElementById('tax');
  const currencySelect = document.getElementById('currency');
  const tipOptions = document.getElementById('tipOptions');
  const peopleCountLabel = document.getElementById('peopleCountLabel');
  const results = document.getElementById('results');
  const itemizedResults = document.getElementById('itemizedResults');

  let tipPct = 15;
  let evenPeopleCount = 2;
  let mode = 'even';

  let people = [T.personDefault(1), T.personDefault(2)];
  let items = [{ name: '', price: '', shared: [0, 1] }];

  function format(n, symbol) {
    return symbol + n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  document.querySelectorAll('.mode-tab').forEach(btn => {
    btn.addEventListener('click', () => {
      mode = btn.dataset.mode;
      document.querySelectorAll('.mode-tab').forEach(b => b.classList.toggle('active', b === btn));
      document.getElementById('evenModeFields').style.display = mode === 'even' ? 'block' : 'none';
      document.getElementById('itemizedModeFields').style.display = mode === 'itemized' ? 'block' : 'none';
      update();
    });
  });

  tipOptions.addEventListener('click', (e) => {
    const btn = e.target.closest('.tip-btn');
    if (!btn) return;
    tipOptions.querySelectorAll('.tip-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    tipPct = parseFloat(btn.dataset.tip);
    update();
  });

  document.getElementById('minus').addEventListener('click', () => {
    evenPeopleCount = Math.max(1, evenPeopleCount - 1);
    peopleCountLabel.textContent = evenPeopleCount;
    update();
  });
  document.getElementById('plus').addEventListener('click', () => {
    evenPeopleCount = Math.min(50, evenPeopleCount + 1);
    peopleCountLabel.textContent = evenPeopleCount;
    update();
  });

  billInput.addEventListener('input', update);
  taxInput.addEventListener('input', update);
  currencySelect.addEventListener('change', update);

  function renderPeople() {
    const container = document.getElementById('peopleRows');
    container.innerHTML = '';
    people.forEach((name, idx) => {
      const row = document.createElement('div');
      row.className = 'people-row';
      row.innerHTML = `
        <input type="text" class="person-name" value="${name}" placeholder="${T.namePlaceholder}">
        <button type="button" class="remove-small" aria-label="${T.removePerson}">×</button>
      `;
      row.querySelector('.person-name').addEventListener('input', (e) => {
        people[idx] = e.target.value;
        renderItems();
        update();
      });
      row.querySelector('.remove-small').addEventListener('click', () => removePerson(idx));
      container.appendChild(row);
    });
  }

  function removePerson(idx) {
    if (people.length <= 1) return;
    people.splice(idx, 1);
    items.forEach(item => {
      item.shared = item.shared.filter(i => i !== idx).map(i => (i > idx ? i - 1 : i));
      if (item.shared.length === 0) item.shared = people.map((_, i) => i);
    });
    renderPeople();
    renderItems();
    update();
  }

  document.getElementById('addPerson').addEventListener('click', () => {
    people.push(T.personDefault(people.length + 1));
    renderPeople();
    renderItems();
    update();
  });

  function renderItems() {
    const container = document.getElementById('itemRows');
    container.innerHTML = '';
    items.forEach((item, idx) => {
      const block = document.createElement('div');
      block.className = 'item-block';
      const checkboxesHtml = people.map((name, pIdx) => `
        <label><input type="checkbox" data-person="${pIdx}" ${item.shared.includes(pIdx) ? 'checked' : ''}> ${name || T.personDefault(pIdx + 1)}</label>
      `).join('');
      block.innerHTML = `
        <div class="item-row">
          <input type="text" class="item-name" placeholder="${T.itemNamePlaceholder}" value="${item.name}">
          <input type="number" class="item-price" placeholder="0.00" min="0" step="0.01" value="${item.price}">
          <button type="button" class="remove-small" aria-label="${T.removeItem}">×</button>
        </div>
        <div class="item-shared">${checkboxesHtml}</div>
      `;
      block.querySelector('.item-name').addEventListener('input', (e) => { item.name = e.target.value; update(); });
      block.querySelector('.item-price').addEventListener('input', (e) => { item.price = e.target.value; update(); });
      block.querySelector('.remove-small').addEventListener('click', () => {
        items.splice(idx, 1);
        renderItems();
        update();
      });
      block.querySelectorAll('input[type="checkbox"]').forEach(cb => {
        cb.addEventListener('change', (e) => {
          const pIdx = parseInt(e.target.dataset.person, 10);
          if (e.target.checked) {
            if (!item.shared.includes(pIdx)) item.shared.push(pIdx);
          } else {
            item.shared = item.shared.filter(i => i !== pIdx);
          }
          update();
        });
      });
      container.appendChild(block);
    });
  }

  document.getElementById('addItem').addEventListener('click', () => {
    items.push({ name: '', price: '', shared: people.map((_, i) => i) });
    renderItems();
    update();
  });

  function updateEven() {
    const bill = parseFloat(billInput.value);
    const taxPct = parseFloat(taxInput.value) || 0;
    const symbol = currencySelect.value;
    if (!bill || bill <= 0) {
      results.style.display = 'none';
      return;
    }
    const tax = bill * (taxPct / 100);
    const tip = bill * (tipPct / 100);
    const total = bill + tax + tip;
    const perPerson = total / evenPeopleCount;

    document.getElementById('taxAmount').textContent = format(tax, symbol);
    document.getElementById('tipAmount').textContent = format(tip, symbol);
    document.getElementById('totalAmount').textContent = format(total, symbol);
    document.getElementById('perPersonAmount').textContent = format(perPerson, symbol);
    results.style.display = 'grid';
  }

  function updateItemized() {
    const symbol = currencySelect.value;
    const taxPct = parseFloat(taxInput.value) || 0;
    const subtotals = people.map(() => 0);
    let billSubtotal = 0;

    items.forEach(item => {
      const price = parseFloat(item.price) || 0;
      if (price <= 0 || item.shared.length === 0) return;
      billSubtotal += price;
      const share = price / item.shared.length;
      item.shared.forEach(pIdx => { subtotals[pIdx] += share; });
    });

    if (billSubtotal <= 0) {
      itemizedResults.style.display = 'none';
      return;
    }

    const tax = billSubtotal * (taxPct / 100);
    const tip = billSubtotal * (tipPct / 100);
    const total = billSubtotal + tax + tip;

    document.getElementById('itemSubtotal').textContent = format(billSubtotal, symbol);
    document.getElementById('itemTaxTip').textContent = format(tax + tip, symbol);
    document.getElementById('itemTotal').textContent = format(total, symbol);

    const body = document.getElementById('breakdownBody');
    body.innerHTML = '';
    people.forEach((name, idx) => {
      const personSubtotal = subtotals[idx];
      const share = personSubtotal / billSubtotal;
      const owed = personSubtotal + (tax + tip) * share;
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${name || T.personDefault(idx + 1)}</td><td>${format(personSubtotal, symbol)}</td><td>${format(owed, symbol)}</td>`;
      body.appendChild(tr);
    });

    itemizedResults.style.display = 'block';
  }

  function update() {
    if (mode === 'even') {
      itemizedResults.style.display = 'none';
      updateEven();
    } else {
      results.style.display = 'none';
      updateItemized();
    }
  }

  function csvEscape(value) {
    const str = String(value);
    return /[",\n]/.test(str) ? '"' + str.replace(/"/g, '""') + '"' : str;
  }

  function downloadCsv(lines, filename) {
    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function buildEvenCsv() {
    const symbol = currencySelect.value;
    const bill = parseFloat(billInput.value) || 0;
    const taxPct = parseFloat(taxInput.value) || 0;
    const tax = bill * (taxPct / 100);
    const tip = bill * (tipPct / 100);
    const total = bill + tax + tip;
    const perPerson = total / evenPeopleCount;

    return [
      T.csv.titleEven,
      `${T.csv.currency},${csvEscape(symbol)}`,
      '',
      `${T.csv.billAmount},${bill.toFixed(2)}`,
      `${T.csv.taxPct},${taxPct}`,
      `${T.csv.taxAmount},${tax.toFixed(2)}`,
      `${T.csv.tipPct},${tipPct}`,
      `${T.csv.tipAmount},${tip.toFixed(2)}`,
      `${T.csv.total},${total.toFixed(2)}`,
      '',
      `${T.csv.splitBetween},${evenPeopleCount} ${T.csv.people}`,
      `${T.csv.perPerson},${perPerson.toFixed(2)}`,
    ];
  }

  function buildItemizedCsv() {
    const symbol = currencySelect.value;
    const taxPct = parseFloat(taxInput.value) || 0;
    const subtotals = people.map(() => 0);
    let billSubtotal = 0;

    const itemLines = [];
    items.forEach(item => {
      const price = parseFloat(item.price) || 0;
      if (price <= 0 || item.shared.length === 0) return;
      billSubtotal += price;
      const share = price / item.shared.length;
      item.shared.forEach(pIdx => { subtotals[pIdx] += share; });
      const sharedNames = item.shared.map(pIdx => people[pIdx] || T.personDefault(pIdx + 1)).join(', ');
      itemLines.push([csvEscape(item.name || ''), price.toFixed(2), csvEscape(sharedNames)].join(','));
    });

    const tax = billSubtotal * (taxPct / 100);
    const tip = billSubtotal * (tipPct / 100);
    const total = billSubtotal + tax + tip;

    const personLines = people.map((name, idx) => {
      const personSubtotal = subtotals[idx];
      const share = billSubtotal > 0 ? personSubtotal / billSubtotal : 0;
      const owed = personSubtotal + (tax + tip) * share;
      return [csvEscape(name || T.personDefault(idx + 1)), personSubtotal.toFixed(2), owed.toFixed(2)].join(',');
    });

    return [
      T.csv.titleItemized,
      `${T.csv.currency},${csvEscape(symbol)}`,
      '',
      T.csv.itemHeader,
      ...itemLines,
      '',
      `${T.csv.subtotal},${billSubtotal.toFixed(2)}`,
      `${T.csv.taxTip},${(tax + tip).toFixed(2)}`,
      `${T.csv.total},${total.toFixed(2)}`,
      '',
      T.csv.personHeader,
      ...personLines,
    ];
  }

  const downloadBtn = document.getElementById('downloadBtn');
  if (downloadBtn) {
    downloadBtn.addEventListener('click', () => {
      const lines = mode === 'even' ? buildEvenCsv() : buildItemizedCsv();
      downloadCsv(lines, 'bill-split.csv');
    });
  }

  renderPeople();
  renderItems();
})();
