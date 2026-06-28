'use strict';

// グローバル変数（onclickから参照できるようにグローバルに置く）
let listings = [];
let pendingPlate = null;
let pendingMods = null;
let pendingPurchasePlate = null;
let pendingPurchasePrice = 0;
let pendingId = 0;

let shopListings = [];
let selectedShopIndex = -1;

function openPriceModal(plate, model, modsB64, buyAmount, id) {
  pendingPlate = plate;
  pendingId = id;
  pendingMods = JSON.parse(atob(modsB64));
  document.getElementById('priceLabel').textContent = `[${plate}] ${model}`;
  document.getElementById('priceBuyAmount').textContent = `仕入額: $${Number(buyAmount || 0).toLocaleString()}`;
  document.getElementById('priceInput').value = '';
  document.getElementById('priceModal').classList.remove('hidden');
  document.getElementById('priceInput').focus();
}

function unlist(plate, id) {
  fetch('https://akr-useddealer/unlist', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ plate, id }),
  });
  const entry = listings.find(l => l.plate === plate);
  if (entry) { entry.listed = 0; }
  renderAll();
}

function renderAll() {
  renderStock();
  renderListed();
}

function renderStock() {
  const tbody = document.getElementById('stockBody');
  const rows = listings.filter(l => l.listed == 0);
  if (!rows.length) {
    tbody.innerHTML = '<tr class="empty-row"><td colspan="4">在庫なし</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(l => `
    <tr>
      <td>${escHtml(l.plate)}</td>
      <td>${escHtml(l.label || l.model)}</td>
      <td style="color:#e08a3c;font-weight:700">${l.price > 0 ? '$' + Number(l.price).toLocaleString() : '未設定'}</td>
      <td>
        <button class="btn btn-primary" onclick="openPriceModal('${escHtml(l.plate)}','${escHtml(l.label || l.model)}','${btoa(l.mods || '{}')}',${l.buy_amount || 0},${l.id || 0})">
          出品する
        </button>
      </td>
    </tr>
  `).join('');
}

function renderListed() {
  const tbody = document.getElementById('listedBody');
  const rows = listings.filter(l => l.listed == 1);
  if (!rows.length) {
    tbody.innerHTML = '<tr class="empty-row"><td colspan="4">出品中の車両なし</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(l => `
    <tr>
      <td>${escHtml(l.plate)}</td>
      <td>${escHtml(l.label || l.model)}</td>
      <td style="color:#e08a3c;font-weight:700">$${Number(l.price).toLocaleString()}</td>
      <td>
        <button class="btn btn-danger" onclick="unlist('${escHtml(l.plate)}',${l.id || 0})">
          取り下げ
        </button>
      </td>
    </tr>
  `).join('');
}

function renderHistory(historyRows) {
  const tbody = document.getElementById('historyBody');
  if (!historyRows || !historyRows.length) {
    tbody.innerHTML = '<tr class="empty-row"><td colspan="5">販売履歴なし</td></tr>';
    return;
  }
  tbody.innerHTML = historyRows.map(l => `
    <tr>
      <td>${escHtml(l.plate)}</td>
      <td>${escHtml(l.label || l.model)}</td>
      <td>${escHtml(l.seller_name || '')}</td>
      <td style="color:#e08a3c;font-weight:700">$${Number(l.price).toLocaleString()}</td>
      <td>${escHtml(l.sold_at || '')}</td>
    </tr>
  `).join('');
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function switchTab(name) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
  document.querySelector(`.tab[data-tab="${name}"]`).classList.add('active');
  document.getElementById(`tab-${name}`).classList.remove('hidden');
}

// ============================================================
//  ショールーム（購入UI）
// ============================================================
function renderShopList() {
  const list = document.getElementById('shopList');
  if (!shopListings.length) {
    list.innerHTML = '<div class="showroom-empty">出品中の車両なし</div>';
    document.getElementById('showroomDetail').classList.add('hidden');
    return;
  }
  list.innerHTML = shopListings.map((l, i) => `
    <div class="showroom-item ${i === selectedShopIndex ? 'active' : ''}" onclick="selectShopItem(${i})">
      <div class="showroom-item-name">${escHtml(l.label || l.model)}</div>
      <div class="showroom-item-price">$${Number(l.price).toLocaleString()}</div>
    </div>
  `).join('');
}

function selectShopItem(index) {
  selectedShopIndex = index;
  const l = shopListings[index];
  if (!l) return;

  renderShopList();

  document.getElementById('detailName').textContent = l.label || l.model;
  document.getElementById('detailPlate').textContent = l.plate;
  document.getElementById('detailPrice').textContent = '$' + Number(l.price).toLocaleString();
  document.getElementById('showroomDetail').classList.remove('hidden');

  fetch('https://akr-useddealer/previewVehicle', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ index }),
  });
}

function renderShop(rows) {
  shopListings = rows || [];
  selectedShopIndex = shopListings.length ? 0 : -1;
  renderShopList();
  if (selectedShopIndex >= 0) {
    const l = shopListings[0];
    document.getElementById('detailName').textContent = l.label || l.model;
    document.getElementById('detailPlate').textContent = l.plate;
    document.getElementById('detailPrice').textContent = '$' + Number(l.price).toLocaleString();
    document.getElementById('showroomDetail').classList.remove('hidden');
  }
}

function openPaymentModal() {
  if (selectedShopIndex < 0) return;
  const l = shopListings[selectedShopIndex];
  pendingPurchasePlate = l.plate;
  pendingPurchasePrice = l.price;
  document.getElementById('paymentLabel').textContent = `[${l.plate}] ${l.label || l.model} — $${Number(l.price).toLocaleString()}`;
  document.getElementById('paymentModal').classList.remove('hidden');
}

window.addEventListener('message', (e) => {
  const { action } = e.data;
  if (action === 'openManage') {
    listings = e.data.listings || [];
    renderAll();
    renderHistory(e.data.history || []);
    document.getElementById('app').classList.remove('hidden');
  }
  if (action === 'closeManage') {
    document.getElementById('app').classList.add('hidden');
  }
  if (action === 'openShop') {
    document.getElementById('shopApp').classList.remove('hidden');
    renderShop(e.data.listings || []);
  }
  if (action === 'closeShop') {
    document.getElementById('shopApp').classList.add('hidden');
  }
  if (action === 'purchaseFailed') {
    document.getElementById('paymentModal').classList.add('hidden');
  }
});

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btnPriceConfirm').addEventListener('click', () => {
    const price = parseInt(document.getElementById('priceInput').value, 10);
    if (!price || price < 1) {
      document.getElementById('priceInput').style.border = '1px solid red';
      return;
    }
    document.getElementById('priceInput').style.border = '';
    fetch('https://akr-useddealer/setListing', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plate: pendingPlate, price, mods: pendingMods, id: pendingId }),
    }).then(() => {
      const entry = listings.find(l => l.plate === pendingPlate);
      if (entry) { entry.listed = 1; entry.price = price; }
      document.getElementById('priceModal').classList.add('hidden');
      renderAll();
      switchTab('listed');
    });
  });

  document.getElementById('btnPriceCancel').addEventListener('click', () => {
    document.getElementById('priceModal').classList.add('hidden');
  });

  document.getElementById('btnClose').addEventListener('click', () => {
    document.getElementById('app').classList.add('hidden');
    fetch('https://akr-useddealer/closeUI', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
  });

  document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // ショールーム退出
  document.getElementById('btnShopClose').addEventListener('click', () => {
    document.getElementById('shopApp').classList.add('hidden');
    fetch('https://akr-useddealer/closeShop', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
  });

  // 購入ボタン（詳細パネル内）
  document.getElementById('btnPurchaseOpen').addEventListener('click', () => {
    openPaymentModal();
  });

  document.getElementById('btnPayCash').addEventListener('click', () => {
    document.getElementById('paymentModal').classList.add('hidden');
    fetch('https://akr-useddealer/purchaseVehicle', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plate: pendingPurchasePlate, paymentType: 'cash' }),
    });
  });

  document.getElementById('btnPayBank').addEventListener('click', () => {
    document.getElementById('paymentModal').classList.add('hidden');
    fetch('https://akr-useddealer/purchaseVehicle', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plate: pendingPurchasePlate, paymentType: 'bank' }),
    });
  });

  document.getElementById('btnPayCancel').addEventListener('click', () => {
    document.getElementById('paymentModal').classList.add('hidden');
  });
});