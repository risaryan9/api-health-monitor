const API_URL = 'API_GATEWAY_URL_PLACEHOLDER';

let allMonitors = [];
let currentFilter = 'all';

document.addEventListener('DOMContentLoaded', () => {
    loadMonitors();

    document.getElementById('monitorForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await createMonitor();
    });

    document.querySelectorAll('.filter-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            currentFilter = tab.getAttribute('data-filter');
            renderMonitorsList();
        });
    });
});

async function loadMonitors() {
    try {
        const response = await fetch(`${API_URL}/monitors`);
        const data = await response.json();
        allMonitors = data.monitors || [];
        renderMonitorsList();
    } catch (error) {
        console.error('Error loading monitors:', error);
        showNotification('Failed to load monitors', 'error');
    }
}

function getFilteredMonitors() {
    if (currentFilter === 'active') return allMonitors.filter(m => m.isActive === 'true');
    if (currentFilter === 'inactive') return allMonitors.filter(m => m.isActive === 'false');
    return allMonitors;
}

function renderMonitorsList() {
    const monitorsList = document.getElementById('monitorsList');
    const filtered = getFilteredMonitors();

    if (allMonitors.length === 0) {
        monitorsList.innerHTML = '<div class="empty-state">No monitors yet. Create your first one above!</div>';
        return;
    }

    if (filtered.length === 0) {
        const msg = currentFilter === 'all' ? 'No monitors yet.' : `No ${currentFilter} monitors.`;
        monitorsList.innerHTML = `<div class="empty-state">${msg}</div>`;
        return;
    }

    monitorsList.innerHTML = filtered.map(monitor => {
        const isActive = monitor.isActive === 'true';
        const statusLabel = isActive ? 'Active' : 'Inactive';
        const statusColor = isActive ? '#10b981' : '#6b7280';
        const actionButton = isActive
            ? `<button class="btn-danger" onclick="setActiveState('${monitor.monitorId}', false)">Deactivate</button>`
            : `<button class="btn-secondary" onclick="setActiveState('${monitor.monitorId}', true)">Activate</button>`;
        return `
            <div class="monitor-item ${isActive ? '' : 'inactive'}">
                <div class="monitor-header">
                    <div class="monitor-name">${monitor.name}</div>
                    ${actionButton}
                </div>
                <div class="monitor-details">
                    <div><strong>Endpoint:</strong> ${monitor.endpoint}</div>
                    <div><strong>Method:</strong> ${monitor.method} | <strong>Expected Status:</strong> ${monitor.expectedStatus}</div>
                    <div><strong>Check Every:</strong> ${monitor.checkInterval}s | <strong>Timeout:</strong> ${monitor.timeout}ms | <strong>Threshold:</strong> ${monitor.thresholdCount} failures</div>
                    <div><strong>Alert Email:</strong> ${monitor.alertEmail}</div>
                    <div style="margin-top: 8px; color: ${statusColor}; font-weight: 600;">${statusLabel}</div>
                </div>
            </div>
        `;
    }).join('');
}

async function setActiveState(monitorId, active) {
    const isActive = active ? 'true' : 'false';
    const action = active ? 'activate' : 'deactivate';
    try {
        const response = await fetch(`${API_URL}/monitors/${monitorId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ isActive })
        });
        if (response.ok) {
            showNotification(`Monitor ${action}d successfully.`, 'success');
            setTimeout(() => loadMonitors(), 500);
        } else {
            throw new Error(`Failed to ${action} monitor`);
        }
    } catch (error) {
        console.error('Error updating monitor:', error);
        showNotification(`Failed to ${action} monitor`, 'error');
    }
}

async function createMonitor() {
    const monitor = {
        name: document.getElementById('name').value,
        endpoint: document.getElementById('endpoint').value,
        method: document.getElementById('method').value,
        expectedStatus: parseInt(document.getElementById('expectedStatus').value),
        timeout: parseInt(document.getElementById('timeout').value),
        checkInterval: parseInt(document.getElementById('checkInterval').value),
        alertEmail: document.getElementById('alertEmail').value,
        thresholdCount: parseInt(document.getElementById('thresholdCount').value)
    };

    try {
        const response = await fetch(`${API_URL}/monitors`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(monitor)
        });

        if (response.ok) {
            showNotification('Monitor created successfully!', 'success');
            document.getElementById('monitorForm').reset();
            setTimeout(() => loadMonitors(), 500);
        } else {
            throw new Error('Failed to create monitor');
        }
    } catch (error) {
        console.error('Error creating monitor:', error);
        showNotification('Failed to create monitor', 'error');
    }
}

function showNotification(message, type) {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.className = `notification ${type} show`;

    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}
