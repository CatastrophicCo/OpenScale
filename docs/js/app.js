// OpenScale Web App - Main Application Logic

// App State
const AppState = {
    currentWeight: 0,
    maxWeight: 0,
    unit: 'lbs',
    sampleRate: 10,
    calibrationFactor: 420.0,
    deviceName: '',
    weightHistory: [],
    maxHistoryLength: 300, // 30 seconds at 10Hz
    chart: null
};

// Unit conversion
const Units = {
    grams: {
        label: 'g',
        convert: (grams) => grams,
        format: (grams) => grams.toFixed(0)
    },
    kg: {
        label: 'kg',
        convert: (grams) => grams / 1000,
        format: (grams) => (grams / 1000).toFixed(2)
    },
    lbs: {
        label: 'lbs',
        convert: (grams) => grams / 453.592,
        format: (grams) => (grams / 453.592).toFixed(1)
    }
};

// DOM Elements
let elements = {};

// Initialize the app
function initApp() {
    // Get DOM elements
    elements = {
        // Connection
        connectBtn: document.getElementById('connectBtn'),
        disconnectBtn: document.getElementById('disconnectBtn'),
        connectionStatus: document.getElementById('connectionStatus'),
        deviceNameDisplay: document.getElementById('deviceNameDisplay'),
        browserWarning: document.getElementById('browserWarning'),

        // Weight display
        weightValue: document.getElementById('weightValue'),
        weightUnit: document.getElementById('weightUnit'),
        maxWeight: document.getElementById('maxWeight'),
        resetMaxBtn: document.getElementById('resetMaxBtn'),

        // Controls
        tareBtn: document.getElementById('tareBtn'),
        unitSelect: document.getElementById('unitSelect'),

        // Graph
        chartCanvas: document.getElementById('forceChart'),

        // Settings
        sampleRateSlider: document.getElementById('sampleRateSlider'),
        sampleRateValue: document.getElementById('sampleRateValue'),
        calibrationInput: document.getElementById('calibrationInput'),
        setCalibrationBtn: document.getElementById('setCalibrationBtn'),
        deviceNameInput: document.getElementById('deviceNameInput'),
        setDeviceNameBtn: document.getElementById('setDeviceNameBtn')
    };

    // Check browser support
    checkBrowserSupport();

    // Set up event listeners
    setupEventListeners();

    // Set up BLE callbacks
    setupBLECallbacks();

    // Initialize chart
    initChart();

    // Load saved preferences
    loadPreferences();
}

// Check browser support for Web Bluetooth
function checkBrowserSupport() {
    if (!OpenScaleBLE.isSupported()) {
        elements.browserWarning.style.display = 'block';
        elements.connectBtn.disabled = true;
    }
}

// Set up event listeners
function setupEventListeners() {
    // Connect button
    elements.connectBtn.addEventListener('click', async () => {
        try {
            elements.connectBtn.disabled = true;
            elements.connectBtn.textContent = 'Connecting...';
            await OpenScaleBLE.connect();
        } catch (error) {
            console.error('Connection failed:', error);
            alert('Connection failed: ' + error.message);
            elements.connectBtn.disabled = false;
            elements.connectBtn.textContent = 'Connect';
        }
    });

    // Disconnect button
    elements.disconnectBtn.addEventListener('click', () => {
        OpenScaleBLE.disconnect();
    });

    // Tare button
    elements.tareBtn.addEventListener('click', async () => {
        try {
            await OpenScaleBLE.tare();
            AppState.maxWeight = 0;
            updateMaxWeightDisplay();
        } catch (error) {
            console.error('Tare failed:', error);
        }
    });

    // Reset max button
    elements.resetMaxBtn.addEventListener('click', () => {
        AppState.maxWeight = 0;
        updateMaxWeightDisplay();
    });

    // Unit selector
    elements.unitSelect.addEventListener('change', (e) => {
        AppState.unit = e.target.value;
        localStorage.setItem('openscale_unit', AppState.unit);
        updateWeightDisplay();
        updateMaxWeightDisplay();
        updateChart();
    });

    // Sample rate slider
    elements.sampleRateSlider.addEventListener('input', (e) => {
        elements.sampleRateValue.textContent = e.target.value + ' Hz';
    });

    elements.sampleRateSlider.addEventListener('change', async (e) => {
        const rate = parseInt(e.target.value);
        try {
            await OpenScaleBLE.setSampleRate(rate);
        } catch (error) {
            console.error('Failed to set sample rate:', error);
        }
    });

    // Calibration button
    elements.setCalibrationBtn.addEventListener('click', async () => {
        const factor = parseFloat(elements.calibrationInput.value);
        if (isNaN(factor)) {
            alert('Please enter a valid calibration factor');
            return;
        }
        try {
            await OpenScaleBLE.setCalibration(factor);
        } catch (error) {
            console.error('Failed to set calibration:', error);
        }
    });

    // Device name button
    elements.setDeviceNameBtn.addEventListener('click', async () => {
        const name = elements.deviceNameInput.value.trim();
        if (!name) {
            alert('Please enter a device name');
            return;
        }
        if (name.length > 20) {
            alert('Device name must be 20 characters or less');
            return;
        }
        try {
            await OpenScaleBLE.setDeviceName(name);
            alert('Device name updated. Restart the device for the new name to appear in Bluetooth scanning.');
        } catch (error) {
            console.error('Failed to set device name:', error);
        }
    });
}

// Set up BLE callbacks
function setupBLECallbacks() {
    OpenScaleBLE.onConnectionChange = (connected, deviceName) => {
        if (connected) {
            elements.connectionStatus.textContent = 'Connected';
            elements.connectionStatus.className = 'status connected';
            elements.deviceNameDisplay.textContent = deviceName || 'OpenScale';
            elements.connectBtn.style.display = 'none';
            elements.disconnectBtn.style.display = 'inline-block';
            elements.tareBtn.disabled = false;
            elements.setCalibrationBtn.disabled = false;
            elements.setDeviceNameBtn.disabled = false;
            elements.sampleRateSlider.disabled = false;
        } else {
            elements.connectionStatus.textContent = 'Disconnected';
            elements.connectionStatus.className = 'status disconnected';
            elements.deviceNameDisplay.textContent = '--';
            elements.connectBtn.style.display = 'inline-block';
            elements.connectBtn.disabled = false;
            elements.connectBtn.textContent = 'Connect';
            elements.disconnectBtn.style.display = 'none';
            elements.tareBtn.disabled = true;
            elements.setCalibrationBtn.disabled = true;
            elements.setDeviceNameBtn.disabled = true;
            elements.sampleRateSlider.disabled = true;
        }
    };

    OpenScaleBLE.onWeightUpdate = (weight) => {
        AppState.currentWeight = weight;
        if (weight > AppState.maxWeight) {
            AppState.maxWeight = weight;
            updateMaxWeightDisplay();
        }
        updateWeightDisplay();
        addWeightToHistory(weight);
    };

    OpenScaleBLE.onSampleRateUpdate = (rate) => {
        AppState.sampleRate = rate;
        elements.sampleRateSlider.value = rate;
        elements.sampleRateValue.textContent = rate + ' Hz';
        // Update max history length based on sample rate
        AppState.maxHistoryLength = rate * 30; // 30 seconds
    };

    OpenScaleBLE.onCalibrationUpdate = (factor) => {
        AppState.calibrationFactor = factor;
        elements.calibrationInput.value = factor.toFixed(1);
    };

    OpenScaleBLE.onDeviceNameUpdate = (name) => {
        AppState.deviceName = name;
        elements.deviceNameInput.value = name;
    };
}

// Update weight display
function updateWeightDisplay() {
    const unit = Units[AppState.unit];
    elements.weightValue.textContent = unit.format(AppState.currentWeight);
    elements.weightUnit.textContent = unit.label;
}

// Update max weight display
function updateMaxWeightDisplay() {
    const unit = Units[AppState.unit];
    elements.maxWeight.textContent = unit.format(AppState.maxWeight) + ' ' + unit.label;
}

// Add weight to history for graphing
function addWeightToHistory(weight) {
    const now = Date.now();
    AppState.weightHistory.push({ time: now, weight: weight });

    // Trim old data
    while (AppState.weightHistory.length > AppState.maxHistoryLength) {
        AppState.weightHistory.shift();
    }

    // Update chart
    updateChart();
}

// Initialize Chart.js
function initChart() {
    const ctx = elements.chartCanvas.getContext('2d');

    AppState.chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Force',
                data: [],
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.2,
                pointRadius: 0,
                pointHoverRadius: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: {
                duration: 0
            },
            interaction: {
                intersect: false,
                mode: 'index'
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: (context) => {
                            const unit = Units[AppState.unit];
                            return unit.format(context.raw) + ' ' + unit.label;
                        }
                    }
                }
            },
            scales: {
                x: {
                    display: true,
                    title: {
                        display: true,
                        text: 'Time (s)',
                        color: '#64748b'
                    },
                    ticks: {
                        color: '#64748b',
                        maxTicksLimit: 6
                    },
                    grid: {
                        color: 'rgba(100, 116, 139, 0.1)'
                    }
                },
                y: {
                    display: true,
                    title: {
                        display: true,
                        text: 'Force',
                        color: '#64748b'
                    },
                    ticks: {
                        color: '#64748b',
                        callback: (value) => {
                            const unit = Units[AppState.unit];
                            return unit.format(value);
                        }
                    },
                    grid: {
                        color: 'rgba(100, 116, 139, 0.1)'
                    },
                    beginAtZero: true
                }
            }
        }
    });
}

// Update chart with new data
function updateChart() {
    if (!AppState.chart || AppState.weightHistory.length === 0) return;

    const unit = Units[AppState.unit];
    const startTime = AppState.weightHistory[0].time;

    // Convert to chart data
    const labels = AppState.weightHistory.map(d => ((d.time - startTime) / 1000).toFixed(1));
    const data = AppState.weightHistory.map(d => unit.convert(d.weight));

    AppState.chart.data.labels = labels;
    AppState.chart.data.datasets[0].data = data;
    AppState.chart.update('none');
}

// Load saved preferences
function loadPreferences() {
    const savedUnit = localStorage.getItem('openscale_unit');
    if (savedUnit && Units[savedUnit]) {
        AppState.unit = savedUnit;
        elements.unitSelect.value = savedUnit;
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initApp);
