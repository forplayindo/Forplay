/* ==========================================
   Economy Dashboard - JavaScript
   ========================================== */

// State
let currentTab = 'overview';
let dashboardData = null;
let charts = {};
let resourceName = 'economy_dashboard'; // Default, will be set by Lua

// Helper for NUI callbacks
function nuiCallback(endpoint, data = {}) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(err => {
        // Silently handle - NUI callbacks may fail when dashboard is closing
    });
}

// ==========================================
// NUI Message Handler
// ==========================================

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'open':
            if (data.resourceName) {
                resourceName = data.resourceName;
            }
            openDashboard(data.tab);
            break;
        case 'close':
            closeDashboard();
            break;
        case 'updateDashboard':
            updateDashboardData(data.data);
            break;
        case 'updateFaucets':
            updateFaucetData(data.data);
            break;
        case 'updateSinks':
            updateSinkData(data.data);
            break;
        case 'updateAnalytics':
            updateAnalyticsData(data.data);
            break;
        case 'updateInflationBasket':
            populatePriceInputs(data.data);
            break;
        case 'pricesLogged':
            showToast(data.message, data.success ? 'success' : 'error');
            if (data.success) {
                document.getElementById('priceUpdateModal').classList.add('hidden');
            }
            break;
        case 'updatePlayerSearch':
            updatePlayerSearch(data.data);
            break;
        case 'updatePlayerProfile':
            updatePlayerProfile(data.data);
            break;
        case 'updateAlerts':
            updateAlerts(data.data);
            break;
        case 'updateAlertCounts':
            updateAlertBadge(data.data);
            break;
        case 'alertStatusUpdated':
            showToast('Alert status updated', 'success');
            break;
        case 'adminResult':
            showToast(data.message, data.success ? 'success' : 'error');
            break;
        case 'updateAdminSearch':
            updateAdminPlayerResults(data.data);
            break;
        case 'updateAuditLog':
            updateAuditLog(data.data);
            break;
        case 'newAlert':
            showToast('New Alert: ' + data.alert.title, 'warning');
            updateAlertBadge({ new: parseInt(document.getElementById('alertBadge').textContent || 0) + 1 });
            break;
        case 'exportComplete':
            handleExport(data.data);
            break;
    }
});

// ==========================================
// Dashboard Control
// ==========================================

function openDashboard(tab) {
    document.getElementById('app').classList.remove('hidden');
    
    // Clear potentially stale data
    document.getElementById('alertsList').innerHTML = '<p class="loading">Loading alerts...</p>';
    
    if (tab) switchTab(tab);
}

function closeDashboard() {
    document.getElementById('app').classList.add('hidden');
}

function close() {
    nuiCallback('close');
}

// ==========================================
// Tab Navigation
// ==========================================

function switchTab(tabId) {
    currentTab = tabId;
    
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabId);
    });
    
    // Update tab panels
    document.querySelectorAll('.tab-panel').forEach(panel => {
        panel.classList.toggle('active', panel.id === tabId);
    });
    
    // Clear stale data when switching to alerts tab
    if (tabId === 'alerts') {
        document.getElementById('alertsList').innerHTML = '<p class="loading">Loading alerts...</p>';
    }
    
    // Notify server of tab change
    nuiCallback('changeTab', { tab: tabId });
}

// ==========================================
// Data Updates
// ==========================================

function updateDashboardData(data) {
    if (!data) return;
    dashboardData = data;
    
    // Update framework badge
    document.getElementById('frameworkBadge').textContent = data.serverName || 'Server';
    
    // Update totals
    document.getElementById('totalCash').textContent = formatMoney(data.totals?.cash || 0);
    document.getElementById('totalBank').textContent = formatMoney(data.totals?.bank || 0);
    document.getElementById('totalDirty').textContent = formatMoney(data.totals?.dirty || 0);
    document.getElementById('totalWealth').textContent = formatMoney(data.totals?.totalWealth || 0);
    
    // Update today's stats
    document.getElementById('todayFaucets').textContent = formatMoney(data.today?.faucets || 0);
    document.getElementById('todaySinks').textContent = formatMoney(data.today?.sinks || 0);
    
    const netFlow = (data.today?.netFlow || 0);
    const netFlowEl = document.getElementById('todayNetFlow');
    netFlowEl.textContent = (netFlow >= 0 ? '+' : '') + formatMoney(netFlow);
    
    const netFlowCard = document.getElementById('netFlowCard');
    netFlowCard.classList.remove('positive', 'negative');
    netFlowCard.classList.add(netFlow >= 0 ? 'positive' : 'negative');
    
    // Update player counts
    document.getElementById('totalPlayers').textContent = formatNumber(data.totals?.totalPlayers || 0);
    document.getElementById('onlinePlayers').textContent = formatNumber(data.totals?.onlinePlayers || 0);
    
    // Update charts
    if (data.snapshots && data.snapshots.length > 0) {
        updateFlowChart(data.snapshots);
    }
    
    // Update wealth distribution chart
    if (data.wealthBrackets && data.wealthBrackets.length > 0) {
        updateDistributionChart(data.wealthBrackets);
    }
    
    // Update alert badge
    if (data.alerts) {
        updateAlertBadge({ new: data.alerts.length });
    }
    
    // Update Economy Health Score
    if (data.economyScore) {
        updateHealthScore(data.economyScore);
    }
    
    // Update Time Comparison / Trends
    if (data.timeComparison) {
        updateTrends(data.timeComparison);
    }
}

function updateHealthScore(scoreData) {
    const score = scoreData.score || 0;
    const status = scoreData.status || 'unknown';
    
    // Update score number
    document.getElementById('healthScore').textContent = score;
    
    // Update status text
    const statusText = {
        'excellent': '🌟 Excellent - Economy is thriving!',
        'good': 'Good - Economy is healthy',
        'fair': 'Fair - Some concerns',
        'poor': '🚨 Poor - Needs attention'
    };
    document.getElementById('healthStatus').textContent = statusText[status] || 'Calculating...';
    
    // Update color based on status
    const colors = {
        'excellent': '#4ade80',
        'good': '#22d3ee',
        'fair': '#fbbf24',
        'poor': '#f87171'
    };
    const color = colors[status] || '#00d4ff';
    document.getElementById('healthScore').style.color = color;
    
    // Update score circle gradient
    const degrees = (score / 100) * 360;
    document.getElementById('scoreCircle').style.background = 
        `conic-gradient(${color} ${degrees}deg, var(--bg-darker) ${degrees}deg)`;
    
    // Update breakdown scores
    if (scoreData.breakdown) {
        document.getElementById('flowScoreVal').textContent = scoreData.breakdown.flow || '--';
        document.getElementById('giniScoreVal').textContent = scoreData.breakdown.gini || '--';
        document.getElementById('velocityScoreVal').textContent = scoreData.breakdown.velocity || '--';
        document.getElementById('activityScoreVal').textContent = scoreData.breakdown.activity || '--';
    }
}

function updateTrends(comparison) {
    // Faucet trend
    const faucetChange = comparison.faucets?.change || 0;
    const faucetTrend = document.getElementById('faucetTrend').querySelector('.trend-value');
    faucetTrend.textContent = formatTrend(faucetChange);
    faucetTrend.style.color = faucetChange >= 0 ? '#4ade80' : '#f87171';
    
    // Sink trend
    const sinkChange = comparison.sinks?.change || 0;
    const sinkTrend = document.getElementById('sinkTrend').querySelector('.trend-value');
    sinkTrend.textContent = formatTrend(sinkChange);
    sinkTrend.style.color = sinkChange >= 0 ? '#f87171' : '#4ade80'; // Inverted - more sinks can be good
}

function formatTrend(percent) {
    const arrow = percent >= 0 ? '↑' : '↓';
    return `${arrow} ${Math.abs(percent).toFixed(1)}%`;
}

function updateFaucetData(data) {
    if (!data) return;
    
    // Update category filter dropdown
    const categorySelect = document.getElementById('faucetCategoryFilter');
    const currentCategory = categorySelect.value;
    if (data.categories && data.categories.length > 0) {
        categorySelect.innerHTML = '<option value="">All Categories</option>' + 
            data.categories.map(cat => `<option value="${escapeHtml(cat)}">${escapeHtml(cat)}</option>`).join('');
        categorySelect.value = currentCategory; // Preserve selection
    }
    
    // Update table
    const tbody = document.getElementById('faucetTableBody');
    if (data.topFaucets && data.topFaucets.length > 0) {
        tbody.innerHTML = data.topFaucets.map(row => `
            <tr>
                <td>${escapeHtml(row.category || 'Unknown')}</td>
                <td>${escapeHtml(row.subcategory || '-')}</td>
                <td class="positive">${formatMoney(row.total_amount || 0)}</td>
                <td>${formatNumber(row.transaction_count || 0)}</td>
                <td>${formatMoney(row.avg_amount || 0)}</td>
            </tr>
        `).join('');
        // Update pie chart with data
        updateFaucetPieChart(data.topFaucets);
    } else {
        tbody.innerHTML = '<tr><td colspan="5" class="loading">No faucet data available</td></tr>';
        // Clear pie chart when no data
        clearFaucetPieChart();
    }
}

function updateSinkData(data) {
    if (!data) return;
    
    // Update category filter dropdown
    const categorySelect = document.getElementById('sinkCategoryFilter');
    const currentCategory = categorySelect.value;
    if (data.categories && data.categories.length > 0) {
        categorySelect.innerHTML = '<option value="">All Categories</option>' + 
            data.categories.map(cat => `<option value="${escapeHtml(cat)}">${escapeHtml(cat)}</option>`).join('');
        categorySelect.value = currentCategory; // Preserve selection
    }
    
    // Update table
    const tbody = document.getElementById('sinkTableBody');
    if (data.topSinks && data.topSinks.length > 0) {
        tbody.innerHTML = data.topSinks.map(row => `
            <tr>
                <td>${escapeHtml(row.category || 'Unknown')}</td>
                <td>${escapeHtml(row.subcategory || '-')}</td>
                <td class="negative">${formatMoney(row.total_amount || 0)}</td>
                <td>${formatNumber(row.transaction_count || 0)}</td>
                <td>${formatMoney(row.avg_amount || 0)}</td>
            </tr>
        `).join('');
        // Update pie chart with data
        updateSinkPieChart(data.topSinks);
    } else {
        tbody.innerHTML = '<tr><td colspan="5" class="loading">No sink data available</td></tr>';
        // Clear pie chart when no data
        clearSinkPieChart();
    }
}

// ==========================================
// Analytics Data
// ==========================================

let wealthBracketsChart = null;

function updateAnalyticsData(data) {
    if (!data) return;
    
    // Update Gini coefficient
    if (data.gini !== null && data.gini !== undefined) {
        const giniValue = parseFloat(data.gini).toFixed(3);
        document.getElementById('giniValue').textContent = giniValue;
        
        // Interpret Gini
        let interpretation;
        if (data.gini < 0.3) {
            interpretation = 'Very Equal - Most players have similar wealth';
        } else if (data.gini < 0.4) {
            interpretation = 'Moderate - Healthy wealth distribution';
        } else if (data.gini < 0.5) {
            interpretation = 'Unequal - Some wealth concentration';
        } else if (data.gini < 0.6) {
            interpretation = 'High Inequality - Top players dominate';
        } else {
            interpretation = 'Extreme Inequality - Wealth highly concentrated';
        }
        document.getElementById('giniInterpretation').textContent = interpretation;
    }
    
    // Update wealth distribution percentiles
    if (data.wealthDistribution) {
        document.getElementById('top1Percent').textContent = 
            data.wealthDistribution.top1Percent?.toFixed(1) + '%' || '--';
        document.getElementById('top10Percent').textContent = 
            data.wealthDistribution.top10Percent?.toFixed(1) + '%' || '--';
        document.getElementById('top50Percent').textContent = 
            data.wealthDistribution.top50Percent?.toFixed(1) + '%' || '--';
    }
    
    // Update wealth brackets chart
    if (data.wealthBrackets && data.wealthBrackets.length > 0) {
        updateWealthBracketsChart(data.wealthBrackets);
    }
    
    // Update leaderboards
    if (data.topRichest) {
        updateLeaderboard('topRichestList', data.topRichest, 'total_wealth', '🥇');
    }
    if (data.topEarners) {
        updateLeaderboard('topEarnersList', data.topEarners, 'total_earned', '<i class="fa-solid fa-arrow-trend-up"></i>');
    }
    if (data.topSpenders) {
        updateLeaderboard('topSpendersList', data.topSpenders, 'total_spent', '📉');
    }
    
    // Update inflation data
    if (data.inflation) {
        updateInflationDisplay(data.inflation, data.inflationMode, data.recentPriceChanges);
    }
}

function updateInflationDisplay(inflation, mode, recentChanges) {
    // Hide entire inflation section if disabled
    const inflationSection = document.querySelector('#analytics .section-header:last-of-type');
    const inflationGrid = inflationSection?.nextElementSibling;
    
    if (mode === 'disabled') {
        if (inflationSection) inflationSection.style.display = 'none';
        if (inflationGrid) inflationGrid.style.display = 'none';
        return;
    } else {
        if (inflationSection) inflationSection.style.display = '';
        if (inflationGrid) inflationGrid.style.display = '';
    }
    
    // Show/hide manual update button based on mode
    const updateBtn = document.getElementById('updatePricesBtn');
    if (updateBtn) {
        if (mode === 'automatic') {
            updateBtn.style.display = 'none';
        } else {
            updateBtn.style.display = '';
        }
    }
    
    // Update CPI value
    const cpiEl = document.getElementById('cpiValue');
    if (cpiEl) {
        cpiEl.textContent = inflation.cpi?.toFixed(1) || '100';
        
        // Color based on inflation level
        if (inflation.cpi > 110) {
            cpiEl.style.color = '#f87171'; // High inflation - red
        } else if (inflation.cpi > 105) {
            cpiEl.style.color = '#fbbf24'; // Moderate - yellow
        } else if (inflation.cpi < 95) {
            cpiEl.style.color = '#60a5fa'; // Deflation - blue
        } else {
            cpiEl.style.color = 'var(--accent-gold)'; // Normal
        }
    }
    
    // Update inflation rate
    const rateEl = document.getElementById('inflationRateValue');
    if (rateEl) {
        const rate = inflation.rate || 0;
        const arrow = rate > 0 ? '↑' : rate < 0 ? '↓' : '';
        rateEl.textContent = `${arrow} ${Math.abs(rate).toFixed(1)}%`;
        rateEl.style.color = rate > 2 ? '#f87171' : rate < -2 ? '#60a5fa' : '#4ade80';
    }
    
    // Update price basket list with source info
    const basketEl = document.getElementById('priceBasketList');
    if (basketEl && inflation.items && inflation.items.length > 0) {
        basketEl.innerHTML = inflation.items.map(item => {
            const changeColor = item.change > 0 ? '#f87171' : item.change < 0 ? '#4ade80' : 'var(--text-muted)';
            const changeArrow = item.change > 0 ? '↑' : item.change < 0 ? '↓' : '';
            return `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid var(--border-color);">
                    <span style="color: var(--text-primary); text-transform: capitalize;">${escapeHtml(item.name.replace(/_/g, ' '))}</span>
                    <div style="text-align: right;">
                        <span style="color: var(--accent-cyan); font-weight: 600;">Rp ${formatNumber(item.currentPrice)}</span>
                        <span style="color: ${changeColor}; font-size: 0.75rem; margin-left: 8px;">${changeArrow} ${Math.abs(item.change).toFixed(1)}%</span>
                    </div>
                </div>
            `;
        }).join('');
    } else if (basketEl) {
        const msg = mode === 'automatic' 
            ? 'Waiting for price data from business scripts...' 
            : 'No price data logged yet. Click "Update Prices" to log current prices.';
        basketEl.innerHTML = `<p style="color: var(--text-muted); text-align: center; padding: 20px;">${msg}</p>`;
    }
    
    // Update recent price changes
    const historyEl = document.getElementById('priceHistoryList');
    if (historyEl && recentChanges && recentChanges.length > 0) {
        historyEl.innerHTML = recentChanges.map(change => {
            const date = new Date(change.created_at);
            const timeStr = date.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
            return `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; border-bottom: 1px solid var(--border-color); font-size: 0.85rem;">
                    <div>
                        <span style="color: var(--text-primary); text-transform: capitalize;">${escapeHtml(change.item_name.replace(/_/g, ' '))}</span>
                        <span style="color: var(--text-muted); margin-left: 8px;">→ Rp ${formatNumber(change.price)}</span>
                    </div>
                    <div style="text-align: right;">
                        <span style="color: var(--accent-cyan); font-size: 0.75rem;">${escapeHtml(change.source || 'manual')}</span>
                        <span style="color: var(--text-muted); font-size: 0.7rem; margin-left: 6px;">${timeStr}</span>
                    </div>
                </div>
            `;
        }).join('');
    } else if (historyEl) {
        historyEl.innerHTML = '<p style="color: var(--text-muted); text-align: center; padding: 15px; font-size: 0.85rem;">No price changes recorded yet</p>';
    }
}

// Store current basket for price input modal
let currentBasket = [];

function populatePriceInputs(basket) {
    currentBasket = basket;
    const container = document.getElementById('priceInputList');
    if (!container || !basket || basket.length === 0) return;
    
    container.innerHTML = basket.map((item, index) => `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid var(--border-color);">
            <label style="color: var(--text-primary); text-transform: capitalize; flex: 1;">${escapeHtml(item.item.replace(/_/g, ' '))}</label>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span style="color: var(--text-muted); font-size: 0.8rem;">Base: Rp ${item.basePrice}</span>
                <input type="number" class="price-input" data-item="${escapeHtml(item.item)}" 
                    value="${item.basePrice}" min="0" 
                    style="width: 100px; padding: 6px 10px; background: var(--bg-darker); border: 1px solid var(--border-color); color: var(--text-primary); border-radius: 4px;">
            </div>
        </div>
    `).join('');
}

function savePrices() {
    const inputs = document.querySelectorAll('.price-input');
    const prices = [];
    
    inputs.forEach(input => {
        const itemName = input.dataset.item;
        const price = parseInt(input.value) || 0;
        if (itemName && price >= 0) {
            prices.push({ name: itemName, price: price });
        }
    });
    
    if (prices.length > 0) {
        nuiCallback('logPrices', { prices: prices });
    }
}

function updateWealthBracketsChart(brackets) {
    const ctx = document.getElementById('wealthBracketsChart');
    if (!ctx) return;
    
    const labels = brackets.map(b => b.name);
    const counts = brackets.map(b => b.count);
    const colors = [
        '#ef4444', // Broke - red
        '#f97316', // Poor - orange
        '#eab308', // Working Class - yellow
        '#22c55e', // Middle Class - green
        '#14b8a6', // Upper Middle - teal
        '#3b82f6', // Wealthy - blue
        '#8b5cf6', // Rich - purple
        '#ec4899', // Ultra Rich - pink
    ];
    
    if (wealthBracketsChart) {
        wealthBracketsChart.destroy();
    }
    
    wealthBracketsChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Players',
                data: counts,
                backgroundColor: colors,
                borderColor: colors.map(c => c),
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        color: '#9ca3af'
                    },
                    grid: {
                        color: 'rgba(255, 255, 255, 0.1)'
                    }
                },
                x: {
                    ticks: {
                        color: '#9ca3af',
                        maxRotation: 45,
                        minRotation: 45
                    },
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

function updateLeaderboard(containerId, players, valueKey, icon) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    if (!players || players.length === 0) {
        container.innerHTML = '<p class="hint-text" style="color: var(--text-muted);">No data available</p>';
        return;
    }
    
    container.innerHTML = players.map((player, index) => {
        const name = player.name || player.firstname && player.lastname 
            ? `${player.firstname || ''} ${player.lastname || ''}`.trim() 
            : player.citizenid?.substring(0, 8) || 'Unknown';
        const value = player[valueKey] || 0;
        const rank = index + 1;
        const rankIcon = rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : `#${rank}`;
        
        return `
            <div class="leaderboard-item" style="display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid var(--border-color);" onclick="viewPlayerProfile('${escapeHtml(player.citizenid || '')}')">
                <span style="color: var(--text-secondary);">
                    <span style="margin-right: 8px;">${rankIcon}</span>
                    ${escapeHtml(name)}
                </span>
                <span style="color: var(--accent-gold); font-weight: 600;">${formatMoney(value)}</span>
            </div>
        `;
    }).join('');
}

function updatePlayerSearch(data) {
    const container = document.getElementById('playerSearchResults');
    
    if (!data.players || data.players.length === 0) {
        container.innerHTML = '<p class="hint-text">No players found matching your search.</p>';
        return;
    }
    
    container.innerHTML = data.players.map(player => `
        <div class="player-item" onclick="viewPlayerProfile('${escapeHtml(player.citizenid)}')">
            <div class="player-info">
                <span class="player-name">${escapeHtml(player.player_name || 'Unknown')}</span>
                <span class="player-id">${escapeHtml(player.citizenid)}</span>
            </div>
            <div class="player-stats">
                <div class="earned">Earned: ${formatMoney(player.total_earned || 0)}</div>
                <div class="spent">Spent: ${formatMoney(player.total_spent || 0)}</div>
            </div>
        </div>
    `).join('');
}

function updatePlayerProfile(data) {
    const panel = document.getElementById('playerProfilePanel');
    panel.classList.remove('hidden');
    
    if (!data.profile) {
        document.getElementById('profileName').textContent = 'Player Not Found';
        return;
    }
    
    const profile = data.profile;
    document.getElementById('profileName').textContent = profile.player_name || 'Unknown';
    document.getElementById('profileCitizenId').textContent = profile.citizenid;
    document.getElementById('profileEarned').textContent = formatMoney(profile.total_earned || 0);
    document.getElementById('profileSpent').textContent = formatMoney(profile.total_spent || 0);
    document.getElementById('profileIncome').textContent = profile.primary_income_source || 'N/A';
    document.getElementById('profileExpense').textContent = profile.primary_expense_sink || 'N/A';
    document.getElementById('profileFlag').textContent = profile.flag_status || 'none';
    
    // Update current balance section
    const balanceSection = document.getElementById('profileBalanceSection');
    if (data.currentBalance) {
        balanceSection.style.display = 'block';
        const bal = data.currentBalance;
        document.getElementById('profileCash').textContent = formatMoney(bal.cash || 0);
        document.getElementById('profileBank').textContent = formatMoney(bal.bank || 0);
        document.getElementById('profileDirty').textContent = formatMoney(bal.dirty || 0);
        document.getElementById('profileTotalWealth').textContent = formatMoney((bal.cash || 0) + (bal.bank || 0) + (bal.dirty || 0));
        document.getElementById('profileOnlineStatus').textContent = bal.online ? '🟢 Currently Online' : '⚫ Offline (showing last known balance)';
        document.getElementById('profileOnlineStatus').style.color = bal.online ? '#4ade80' : 'var(--text-muted)';
    } else {
        balanceSection.style.display = 'none';
    }
    
    // Update transactions
    const txContainer = document.getElementById('profileTransactions');
    if (data.transactions && data.transactions.length > 0) {
        txContainer.innerHTML = data.transactions.map(tx => `
            <div class="transaction-item">
                <div>
                    <span class="type">${tx.transaction_type}</span>
                    <span class="category">(${escapeHtml(tx.category || 'other')})</span>
                </div>
                <span class="amount ${tx.transaction_type}">${formatMoney(tx.amount || 0)}</span>
            </div>
        `).join('');
    } else {
        txContainer.innerHTML = '<p class="hint-text">No transactions found.</p>';
    }
}

function updateAlerts(data) {
    const container = document.getElementById('alertsList');
    
    if (!data.alerts || data.alerts.length === 0) {
        container.innerHTML = '<p class="hint-text">No alerts found.</p>';
        return;
    }
    
    container.innerHTML = data.alerts.map(alert => `
        <div class="alert-item ${alert.severity}">
            <div class="alert-header">
                <span class="alert-title">${escapeHtml(alert.title)}</span>
                <span class="alert-severity ${alert.severity}">${alert.severity}</span>
            </div>
            <p class="alert-description">${escapeHtml(alert.description || '')}</p>
            <div class="alert-meta">
                <span>${alert.player_name ? 'Player: ' + escapeHtml(alert.player_name) : ''} • ${formatDate(alert.created_at)}</span>
                <div class="alert-actions">
                    <button class="btn btn-success" onclick="updateAlertStatus(${alert.id}, 'resolved')">Resolve</button>
                    <button class="btn btn-secondary" onclick="updateAlertStatus(${alert.id}, 'dismissed')">Dismiss</button>
                </div>
            </div>
        </div>
    `).join('');
}

function updateAlertBadge(counts) {
    const badge = document.getElementById('alertBadge');
    const newCount = counts.new || 0;
    
    badge.textContent = newCount;
    badge.classList.toggle('hidden', newCount === 0);
}

function updateAuditLog(logs) {
    const tbody = document.getElementById('auditLogBody');
    
    if (!logs || logs.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="loading">No admin actions logged</td></tr>';
        return;
    }
    
    tbody.innerHTML = logs.map(log => `
        <tr>
            <td>${formatDate(log.created_at)}</td>
            <td>${escapeHtml(log.admin_name || log.admin_id)}</td>
            <td>${escapeHtml(log.action)}</td>
            <td>${escapeHtml(log.target_name || log.target_player || '-')}</td>
            <td>${log.amount ? formatMoney(log.amount) : '-'}</td>
            <td>${escapeHtml(log.reason || '-')}</td>
        </tr>
    `).join('');
}

// ==========================================
// Charts
// ==========================================

function updateFlowChart(snapshots) {
    const ctx = document.getElementById('flowChart');
    if (!ctx) return;
    
    const labels = snapshots.map(s => formatDateShort(s.snapshot_date));
    const faucets = snapshots.map(s => s.total_faucets || 0);
    const sinks = snapshots.map(s => s.total_sinks || 0);
    
    if (charts.flowChart) {
        charts.flowChart.destroy();
    }
    
    charts.flowChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Faucets (Money In)',
                    data: faucets,
                    borderColor: '#ff8c00',
                    backgroundColor: 'rgba(255, 140, 0, 0.15)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 3
                },
                {
                    label: 'Sinks (Money Out)',
                    data: sinks,
                    borderColor: '#1e90ff',
                    backgroundColor: 'rgba(30, 144, 255, 0.15)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 3
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: { color: '#8ba3c7', font: { size: 12 } }
                }
            },
            scales: {
                x: {
                    ticks: { color: '#5a7a9a' },
                    grid: { color: '#1e4976' }
                },
                y: {
                    ticks: { 
                        color: '#5a7a9a',
                        callback: value => formatMoneyShort(value)
                    },
                    grid: { color: '#1e4976' }
                }
            }
        }
    });
}

function updateDistributionChart(brackets) {
    const ctx = document.getElementById('distributionChart');
    if (!ctx) return;
    
    // Filter out brackets with 0 players for cleaner chart
    const filteredBrackets = brackets.filter(b => b.count > 0);
    
    if (filteredBrackets.length === 0) {
        // Show placeholder if no data
        if (charts.distribution) {
            charts.distribution.destroy();
        }
        return;
    }
    
    const labels = filteredBrackets.map(b => b.name);
    const counts = filteredBrackets.map(b => b.count);
    
    const colors = {
        'Broke': '#ef4444',
        'Poor': '#f97316',
        'Working Class': '#eab308',
        'Middle Class': '#22c55e',
        'Upper Middle': '#14b8a6',
        'Wealthy': '#3b82f6',
        'Rich': '#8b5cf6',
        'Ultra Rich': '#ec4899',
    };
    
    const bgColors = filteredBrackets.map(b => colors[b.name] || '#6b7280');
    
    if (charts.distribution) {
        charts.distribution.destroy();
    }
    
    charts.distribution = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: counts,
                backgroundColor: bgColors,
                borderColor: '#0a1628',
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                    labels: { 
                        color: '#8ba3c7', 
                        font: { size: 11 },
                        padding: 10,
                        usePointStyle: true,
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            const total = context.dataset.data.reduce((a, b) => a + b, 0);
                            const percentage = ((context.raw / total) * 100).toFixed(1);
                            return `${context.label}: ${context.raw} players (${percentage}%)`;
                        }
                    }
                }
            }
        }
    });
}

function updateFaucetPieChart(data) {
    const ctx = document.getElementById('faucetPieChart');
    if (!ctx) return;
    
    const labels = data.slice(0, 8).map(d => d.category || 'Other');
    const values = data.slice(0, 8).map(d => d.total_amount || 0);
    
    if (charts.faucetPie) {
        charts.faucetPie.destroy();
    }
    
    charts.faucetPie = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: values,
                backgroundColor: [
                    '#ff8c00', '#ffa500', '#ffb732', '#1e90ff',
                    '#00bfff', '#00d68f', '#ff6b00', '#87ceeb'
                ],
                borderColor: '#0a1628',
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                    labels: { color: '#8ba3c7', font: { size: 11 } }
                }
            }
        }
    });
}

function updateSinkPieChart(data) {
    const ctx = document.getElementById('sinkPieChart');
    if (!ctx) return;
    
    const labels = data.slice(0, 8).map(d => d.category || 'Other');
    const values = data.slice(0, 8).map(d => d.total_amount || 0);
    
    if (charts.sinkPie) {
        charts.sinkPie.destroy();
    }
    
    charts.sinkPie = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: values,
                backgroundColor: [
                    '#1e90ff', '#00bfff', '#ff8c00', '#ffa500',
                    '#00d68f', '#ff3d71', '#87ceeb', '#ffb732'
                ],
                borderColor: '#0a1628',
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                    labels: { color: '#8ba3c7', font: { size: 11 } }
                }
            }
        }
    });
}

function clearFaucetPieChart() {
    if (charts.faucetPie) {
        charts.faucetPie.destroy();
        charts.faucetPie = null;
    }
    const ctx = document.getElementById('faucetPieChart');
    if (ctx) {
        const context = ctx.getContext('2d');
        context.clearRect(0, 0, ctx.width, ctx.height);
    }
}

function clearSinkPieChart() {
    if (charts.sinkPie) {
        charts.sinkPie.destroy();
        charts.sinkPie = null;
    }
    const ctx = document.getElementById('sinkPieChart');
    if (ctx) {
        const context = ctx.getContext('2d');
        context.clearRect(0, 0, ctx.width, ctx.height);
    }
}

// ==========================================
// Actions
// ==========================================

function viewPlayerProfile(citizenid) {
    nuiCallback('getPlayerProfile', { citizenid: citizenid });
}

function updateAlertStatus(alertId, status, notes = '') {
    nuiCallback('updateAlertStatus', { alertId: alertId, status: status, notes: notes });
    
    // Remove the alert from the current view immediately
    const alertItem = document.querySelector(`.alert-item button[onclick*="${alertId}"]`);
    if (alertItem) {
        const alertCard = alertItem.closest('.alert-item');
        if (alertCard) {
            alertCard.style.opacity = '0.5';
            setTimeout(() => alertCard.remove(), 300);
        }
    }
    
    showToast(`Alert ${status}`, 'success');
}

function searchPlayers() {
    const query = document.getElementById('playerSearchInput').value;
    if (query.length < 2) {
        showToast('Enter at least 2 characters to search', 'warning');
        return;
    }
    
    nuiCallback('searchPlayers', { query: query });
}

function adminSearchPlayers() {
    const query = document.getElementById('adminPlayerSearch').value;
    if (query.length < 2) {
        showToast('Enter at least 2 characters to search', 'warning');
        return;
    }
    
    nuiCallback('adminSearchPlayers', { query: query });
}

function updateAdminPlayerResults(data) {
    const container = document.getElementById('adminPlayerResults');
    
    if (!data.players || data.players.length === 0) {
        container.style.display = 'none';
        showToast('No players found', 'warning');
        return;
    }
    
    container.style.display = 'block';
    container.innerHTML = data.players.map(player => `
        <div class="admin-player-item" onclick="selectAdminPlayer('${escapeHtml(player.citizenid)}', '${escapeHtml(player.player_name || 'Unknown')}')" style="padding: 10px 12px; cursor: pointer; border-bottom: 1px solid var(--border-color);">
            <span style="color: var(--accent-gold);">${escapeHtml(player.player_name || 'Unknown')}</span>
            <span style="color: var(--text-muted); font-size: 0.8rem; margin-left: 10px;">${escapeHtml(player.citizenid)}</span>
        </div>
    `).join('');
}

function selectAdminPlayer(citizenid, name) {
    document.getElementById('adminCitizenId').value = citizenid;
    document.getElementById('adminPlayerResults').style.display = 'none';
    document.getElementById('adminPlayerSearch').value = name;
    showToast(`Selected: ${name}`, 'success');
}

function adminAction(action) {
    const citizenid = document.getElementById('adminCitizenId').value;
    const moneyType = document.getElementById('adminMoneyType').value;
    const amount = document.getElementById('adminAmount').value;
    const reason = document.getElementById('adminReason').value;
    
    if (!citizenid || !amount) {
        showToast('Please fill in Citizen ID and Amount', 'error');
        return;
    }
    
    nuiCallback(`admin${action}Money`, {
        citizenid: citizenid,
        moneyType: moneyType,
        amount: parseInt(amount),
        reason: reason
    });
}

function handleExport(data) {
    if (!data || data.length === 0) {
        showToast('No data to export', 'error');
        return;
    }
    
    // Create CSV
    const headers = ['Citizen ID', 'Name', 'Cash', 'Bank', 'Dirty', 'Total'];
    const rows = data.map(p => [
        p.citizenid,
        (p.firstname || '') + ' ' + (p.lastname || p.name || ''),
        p.cash || 0,
        p.bank || 0,
        p.dirty || 0,
        (parseInt(p.cash) || 0) + (parseInt(p.bank) || 0) + (parseInt(p.dirty) || 0)
    ]);
    
    let csv = headers.join(',') + '\n';
    rows.forEach(row => {
        csv += row.map(cell => `"${cell}"`).join(',') + '\n';
    });
    
    // FiveM NUI blocks clipboard API, so use modal directly
    showExportModal(csv, data.length);
}

function showExportModal(csv, count) {
    // Create modal overlay
    const modal = document.createElement('div');
    modal.id = 'exportModal';
    modal.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.8); display: flex; align-items: center; justify-content: center; z-index: 9999;';
    
    modal.innerHTML = `
        <div style="background: var(--bg-secondary); border: 1px solid var(--accent-cyan); border-radius: 8px; padding: 20px; max-width: 600px; width: 90%; max-height: 80vh; display: flex; flex-direction: column;">
            <h3 style="color: var(--accent-cyan); margin-bottom: 15px;"><i class="fa-solid fa-file-export"></i> Export Data (${count} players)</h3>
            <p style="color: var(--text-secondary); margin-bottom: 10px; font-size: 0.9rem;">Press <strong>Ctrl+A</strong> to select all, then <strong>Ctrl+C</strong> to copy. Paste into Excel or save as .csv file:</p>
            <textarea id="exportTextarea" style="flex: 1; min-height: 300px; background: var(--bg-darker); border: 1px solid var(--border-color); color: var(--text-primary); padding: 10px; font-family: monospace; font-size: 0.8rem; resize: none;" readonly>${csv}</textarea>
            <div style="display: flex; gap: 10px; margin-top: 15px;">
                <button onclick="document.getElementById('exportTextarea').select(); document.getElementById('exportTextarea').focus();" style="flex: 1; padding: 10px 20px; background: var(--accent-gold); border: none; color: #000; cursor: pointer; border-radius: 4px; font-weight: 600;">Select All</button>
                <button onclick="document.getElementById('exportModal').remove()" style="flex: 1; padding: 10px 20px; background: var(--accent-cyan); border: none; color: #000; cursor: pointer; border-radius: 4px; font-weight: 600;">Close</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Select the text automatically
    const textarea = modal.querySelector('textarea');
    textarea.focus();
    textarea.select();
    
    showToast(`Export ready - ${count} players. Select all and copy!`, 'success');
}

// ==========================================
// Utility Functions
// ==========================================

function formatMoney(amount) {
    if (amount == null) return 'Rp 0';
    amount = Math.floor(amount);
    return 'Rp ' + amount.toLocaleString();
}

function formatMoneyShort(amount) {
    if (amount >= 1000000000) return 'Rp ' + (amount / 1000000000).toFixed(1) + 'B';
    if (amount >= 1000000) return 'Rp ' + (amount / 1000000).toFixed(1) + 'M';
    if (amount >= 1000) return 'Rp ' + (amount / 1000).toFixed(1) + 'K';
    return 'Rp ' + amount;
}

function formatNumber(num) {
    return (num || 0).toLocaleString();
}

function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatDateShort(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return (date.getMonth() + 1) + '/' + date.getDate();
}

function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = 'toast ' + type;
    toast.textContent = message;
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 4000);
}

// ==========================================
// Event Listeners
// ==========================================

document.addEventListener('DOMContentLoaded', function() {
    // Close button
    document.getElementById('closeBtn').addEventListener('click', close);
    
    // Tab navigation - auto-refresh data on tab switch
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const tab = this.dataset.tab;
            switchTab(tab);
            // Auto-refresh data for the new tab
            if (tab === 'alerts') {
                // Get currently active filter, default to 'new'
                const activeFilter = document.querySelector('.btn-filter.active');
                const status = activeFilter ? activeFilter.dataset.status : 'new';
                nuiCallback('refreshData', { tab: tab, status: status });
            } else {
                nuiCallback('refreshData', { tab: tab });
            }
        });
    });
    
    // Player search
    document.getElementById('playerSearchBtn').addEventListener('click', searchPlayers);
    document.getElementById('playerSearchInput').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') searchPlayers();
    });
    
    // Close player profile
    document.getElementById('closeProfileBtn').addEventListener('click', function() {
        document.getElementById('playerProfilePanel').classList.add('hidden');
    });
    
    // Alert filter buttons
    document.querySelectorAll('.btn-filter').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.btn-filter').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            nuiCallback('refreshData', { tab: 'alerts', status: this.dataset.status });
        });
    });
    
    // Faucet filter
    document.getElementById('filterFaucetsBtn').addEventListener('click', function() {
        const startDate = document.getElementById('faucetStartDate').value;
        const endDate = document.getElementById('faucetEndDate').value;
        const category = document.getElementById('faucetCategoryFilter').value;
        
        nuiCallback('refreshData', { tab: 'faucets', startDate: startDate, endDate: endDate, category: category });
    });
    
    // Auto-refresh on faucet category change
    document.getElementById('faucetCategoryFilter').addEventListener('change', function() {
        const startDate = document.getElementById('faucetStartDate').value;
        const endDate = document.getElementById('faucetEndDate').value;
        const category = this.value;
        
        nuiCallback('refreshData', { tab: 'faucets', startDate: startDate, endDate: endDate, category: category });
    });
    
    // Sink filter
    document.getElementById('filterSinksBtn').addEventListener('click', function() {
        const startDate = document.getElementById('sinkStartDate').value;
        const endDate = document.getElementById('sinkEndDate').value;
        const category = document.getElementById('sinkCategoryFilter').value;
        
        nuiCallback('refreshData', { tab: 'sinks', startDate: startDate, endDate: endDate, category: category });
    });
    
    // Auto-refresh on sink category change
    document.getElementById('sinkCategoryFilter').addEventListener('change', function() {
        const startDate = document.getElementById('sinkStartDate').value;
        const endDate = document.getElementById('sinkEndDate').value;
        const category = this.value;
        
        nuiCallback('refreshData', { tab: 'sinks', startDate: startDate, endDate: endDate, category: category });
    });
    
    // Admin player search
    document.getElementById('adminSearchBtn').addEventListener('click', adminSearchPlayers);
    document.getElementById('adminPlayerSearch').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') adminSearchPlayers();
    });
    
    // Admin buttons
    document.getElementById('adminAddBtn').addEventListener('click', () => adminAction('Add'));
    document.getElementById('adminRemoveBtn').addEventListener('click', () => adminAction('Remove'));
    document.getElementById('adminSetBtn').addEventListener('click', () => adminAction('Set'));
    
    // Export button
    document.getElementById('exportPlayersBtn').addEventListener('click', function() {
        nuiCallback('exportData');
    });
    
    // Test webhook
    document.getElementById('testWebhookBtn').addEventListener('click', function() {
        nuiCallback('testDiscordWebhook', { webhookType: 'alert' });
    });
    
    // Bulk wipe dirty - requires double click
    let bulkWipeClickCount = 0;
    let bulkWipeTimer = null;
    document.getElementById('bulkWipeDirtyBtn').addEventListener('click', function() {
        const btn = this;
        
        bulkWipeClickCount++;
        
        if (bulkWipeClickCount === 1) {
            btn.textContent = 'Click again to confirm!';
            btn.style.background = '#dc2626';
            
            // Reset after 3 seconds
            bulkWipeTimer = setTimeout(() => {
                bulkWipeClickCount = 0;
                btn.textContent = 'Wipe All Dirty Money (Online)';
                btn.style.background = '';
            }, 3000);
        } else if (bulkWipeClickCount >= 2) {
            clearTimeout(bulkWipeTimer);
            bulkWipeClickCount = 0;
            
            btn.textContent = 'Processing...';
            btn.disabled = true;
            
            nuiCallback('adminBulkWipeDirty', { reason: 'Admin bulk wipe' });
            
            // Re-enable after 5 seconds
            setTimeout(() => {
                btn.textContent = 'Wipe All Dirty Money (Online)';
                btn.style.background = '';
                btn.disabled = false;
            }, 5000);
        }
    });
    
    // Inflation price update buttons
    document.getElementById('updatePricesBtn')?.addEventListener('click', function() {
        // Request basket data and show modal
        nuiCallback('getInflationBasket');
        document.getElementById('priceUpdateModal').classList.remove('hidden');
    });
    
    document.getElementById('cancelPricesBtn')?.addEventListener('click', function() {
        document.getElementById('priceUpdateModal').classList.add('hidden');
    });
    
    document.getElementById('savePricesBtn')?.addEventListener('click', function() {
        savePrices();
    });
    
    // Close modal when clicking outside
    document.getElementById('priceUpdateModal')?.addEventListener('click', function(e) {
        if (e.target === this) {
            this.classList.add('hidden');
        }
    });
    
    // Set default dates
    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    document.getElementById('faucetStartDate').value = weekAgo;
    document.getElementById('faucetEndDate').value = today;
    document.getElementById('sinkStartDate').value = weekAgo;
    document.getElementById('sinkEndDate').value = today;
});

// Keyboard shortcuts
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        close();
    }
});
