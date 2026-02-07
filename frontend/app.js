const API_URL = 'API_GATEWAY_URL_PLACEHOLDER';

// Load monitors on page load
document.addEventListener('DOMContentLoaded', () => {
    loadMonitors();
    
    document.getElementById('monitorForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await createMonitor();
    });
});

async function loadMonitors() {
    try {
        const response = await fetch(`${API_URL}/monitors`);
        const data = await response.json();
        
        const monitorsList = document.getElementById('monitorsList');
        
        if (!data.monitors || data.monitors.length === 0) {
            monitorsList.innerHTML = '<div class="empty-state">No monitors yet. Create your first one above!</div>';
            return;
        }
        
        monitorsList.innerHTML = data.monitors.map(monitor => `
            <div class="monitor-item">
                <div class="monitor-header">
                    <div class="monitor-name">${monitor.name}</div>
                    <button class="btn-danger" onclick="deleteMonitor('${monitor.monitorId}')">Delete</button>
                </div>
                <div class="monitor-details">
                    <div><strong>Endpoint:</strong> ${monitor.endpoint}</div>
                    <div><strong>Method:</strong> ${monitor.method} | <strong>Expected Status:</strong> ${monitor.expectedStatus}</div>
                    <div><strong>Check Every:</strong> ${monitor.checkInterval}s | <strong>Timeout:</strong> ${monitor.timeout}ms | <strong>Threshold:</strong> ${monitor.thresholdCount} failures</div>
                    <div><strong>Alert Email:</strong> ${monitor.alertEmail}</div>
                    <div style="margin-top: 8px; color: #10b981; font-weight: 600;">✓ Active</div>
                </div>
            </div>
        `).join('');
        
    } catch (error) {
        console.error('Error loading monitors:', error);
        showNotification('Failed to load monitors', 'error');
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

async function deleteMonitor(monitorId) {
    if (!confirm('Are you sure you want to delete this monitor?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/monitors/${monitorId}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showNotification('Monitor deleted successfully!', 'success');
            setTimeout(() => loadMonitors(), 500);
        } else {
            throw new Error('Failed to delete monitor');
        }
    } catch (error) {
        console.error('Error deleting monitor:', error);
        showNotification('Failed to delete monitor', 'error');
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
