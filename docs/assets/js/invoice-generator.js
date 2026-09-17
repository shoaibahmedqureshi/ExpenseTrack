(function () {
  const T = window.T || {
    yourNameFallback: 'Your Name',
    taxIdPrefix: 'NTN/CNIC: ',
    invoiceNumPrefix: 'Invoice #',
    datePrefix: 'Date: ',
    duePrefix: 'Due: ',
    pkrTemplate: (amount) => `≈ ₨${amount} PKR`,
  };

  const itemRows = document.getElementById('itemRows');
  const whtSelect = document.getElementById('wht');
  const rateError = document.getElementById('rateError');

  let items = [{ desc: '', qty: 1, rate: '' }];
  let pkrRate = null;

  function escapeHtml(str) {
    return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  async function fetchRate() {
    try {
      const res = await fetch('https://open.er-api.com/v6/latest/USD');
      if (!res.ok) throw new Error('rate fetch failed');
      const data = await res.json();
      pkrRate = data.rates && data.rates.PKR;
      if (!pkrRate) throw new Error('rate missing');
      rateError.style.display = 'none';
    } catch (e) {
      pkrRate = null;
      rateError.style.display = 'block';
    }
    update();
  }

  function pkrLine(usdAmount) {
    if (!pkrRate) return '';
    const pkr = usdAmount * pkrRate;
    return T.pkrTemplate(pkr.toLocaleString(undefined, { maximumFractionDigits: 0 }));
  }

  function fmtUsd(n) {
    const sign = n < 0 ? '−' : '';
    return sign + '$' + Math.abs(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function renderRows() {
    itemRows.innerHTML = '';
    items.forEach((item, idx) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><input type="text" class="desc" placeholder="e.g. Website redesign" value="${escapeHtml(item.desc)}"></td>
        <td style="width:70px;"><span class="mobile-label">Qty</span><input type="number" class="qty" min="0" step="1" placeholder="Qty" value="${escapeHtml(item.qty)}"></td>
        <td style="width:110px;"><span class="mobile-label">Rate (USD)</span><input type="number" class="rate" min="0" step="0.01" placeholder="Rate (USD)" value="${escapeHtml(item.rate)}"></td>
        <td class="amount-cell"><span class="amount">$0.00</span></td>
        <td style="width:34px;"><button type="button" class="remove-small" aria-label="Remove item">×</button></td>
      `;
      tr.querySelector('.desc').addEventListener('input', (e) => { item.desc = e.target.value; });
      tr.querySelector('.qty').addEventListener('input', (e) => { item.qty = e.target.value; update(); });
      tr.querySelector('.rate').addEventListener('input', (e) => { item.rate = e.target.value; update(); });
      tr.querySelector('.remove-small').addEventListener('click', () => {
        if (items.length <= 1) return;
        items.splice(idx, 1);
        renderRows();
        update();
      });
      itemRows.appendChild(tr);
    });
    update();
  }

  document.getElementById('addItem').addEventListener('click', () => {
    items.push({ desc: '', qty: 1, rate: '' });
    renderRows();
  });

  function computeTotals() {
    let subtotal = 0;
    const rowAmounts = items.map(item => {
      const qty = parseFloat(item.qty) || 0;
      const rate = parseFloat(item.rate) || 0;
      const amount = qty * rate;
      subtotal += amount;
      return amount;
    });
    const whtPct = parseFloat(whtSelect.value) || 0;
    const wht = subtotal * (whtPct / 100);
    const net = subtotal - wht;
    return { rowAmounts, subtotal, whtPct, wht, net };
  }

  function update() {
    const { rowAmounts, subtotal, whtPct, wht, net } = computeTotals();
    itemRows.querySelectorAll('tr').forEach((tr, idx) => {
      tr.querySelector('.amount').textContent = fmtUsd(rowAmounts[idx] || 0);
    });
    document.getElementById('subtotalUsd').firstChild.textContent = fmtUsd(subtotal);
    document.getElementById('subtotalPkr').textContent = pkrLine(subtotal);

    const whtNoteBox = document.getElementById('whtNoteBox');
    if (whtPct > 0) {
      whtNoteBox.style.display = 'block';
      document.getElementById('whtUsd').firstChild.textContent = '−' + fmtUsd(wht);
      document.getElementById('whtPkr').textContent = pkrLine(wht);
      document.getElementById('netUsd').firstChild.textContent = fmtUsd(net);
      document.getElementById('netPkr').textContent = pkrLine(net);
    } else {
      whtNoteBox.style.display = 'none';
    }
  }

  whtSelect.addEventListener('change', update);

  document.getElementById('downloadBtn').addEventListener('click', () => {
    const { rowAmounts, subtotal, whtPct, wht, net } = computeTotals();

    document.getElementById('pFromName').textContent = document.getElementById('fromName').value || T.yourNameFallback;
    const fromBits = [
      document.getElementById('fromAddress').value,
      document.getElementById('fromTaxId').value ? T.taxIdPrefix + document.getElementById('fromTaxId').value : '',
      document.getElementById('fromEmail').value,
    ].filter(Boolean);
    document.getElementById('pFromDetails').textContent = fromBits.join('\n');

    const toBits = [
      document.getElementById('toName').value,
      document.getElementById('toAddress').value,
    ].filter(Boolean);
    document.getElementById('pToDetails').textContent = toBits.join('\n');

    document.getElementById('pInvoiceNumber').textContent = document.getElementById('invoiceNumber').value ? T.invoiceNumPrefix + document.getElementById('invoiceNumber').value : '';
    document.getElementById('pInvoiceDate').textContent = document.getElementById('invoiceDate').value ? T.datePrefix + document.getElementById('invoiceDate').value : '';
    document.getElementById('pDueDate').textContent = document.getElementById('dueDate').value ? T.duePrefix + document.getElementById('dueDate').value : '';

    const pRows = document.getElementById('pItemRows');
    pRows.innerHTML = '';
    items.forEach((item, idx) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${escapeHtml(item.desc)}</td><td class="num">${escapeHtml(item.qty || 0)}</td><td class="num">${fmtUsd(parseFloat(item.rate) || 0)}</td><td class="num">${fmtUsd(rowAmounts[idx] || 0)}</td>`;
      pRows.appendChild(tr);
    });

    document.getElementById('pAmountDue').textContent = fmtUsd(subtotal);
    const whtNoteWrap = document.getElementById('pWhtNoteWrap');
    if (whtPct > 0) {
      whtNoteWrap.style.display = 'block';
      document.getElementById('pWhtPct').textContent = whtPct;
      document.getElementById('pWhtAmount').textContent = fmtUsd(wht) + (pkrRate ? '  ' + pkrLine(wht) : '');
      document.getElementById('pNetReceipt').textContent = fmtUsd(net) + (pkrRate ? '  ' + pkrLine(net) : '');
    } else {
      whtNoteWrap.style.display = 'none';
    }
    document.getElementById('pNotes').textContent = document.getElementById('notes').value || '';

    window.print();
  });

  const today = new Date().toISOString().slice(0, 10);
  document.getElementById('invoiceDate').value = today;

  renderRows();
  fetchRate();
})();
