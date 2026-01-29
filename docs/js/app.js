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
    maxHistoryLength: 36000, // Store up to 1 hour at 10Hz (can be more)
    chart: null,
    // Calibration state
    calibrationInProgress: false,
    calibrationWeightGrams: 4535.92, // Default 10 lbs in grams
    // Graph time range state
    timeRangeMode: 'recent', // 'all', 'recent', 'custom'
    timeRangeSeconds: 300, // Default 5 minutes
    customRangeStart: null,
    customRangeEnd: null,
    isZoomed: false,
    connectionStartTime: null
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
        timeRangeSelect: document.getElementById('timeRangeSelect'),
        resetZoomBtn: document.getElementById('resetZoomBtn'),
        customRangeControls: document.getElementById('customRangeControls'),
        customRangeStart: document.getElementById('customRangeStart'),
        customRangeEnd: document.getElementById('customRangeEnd'),
        applyCustomRangeBtn: document.getElementById('applyCustomRangeBtn'),

        // Settings
        sampleRateSlider: document.getElementById('sampleRateSlider'),
        sampleRateValue: document.getElementById('sampleRateValue'),
        calibrationFactorDisplay: document.getElementById('calibrationFactorDisplay'),
        calibrationNormal: document.getElementById('calibrationNormal'),
        calibrationInProgress: document.getElementById('calibrationInProgress'),
        startCalibrationBtn: document.getElementById('startCalibrationBtn'),
        completeCalibrationBtn: document.getElementById('completeCalibrationBtn'),
        cancelCalibrationBtn: document.getElementById('cancelCalibrationBtn'),
        deviceNameInput: document.getElementById('deviceNameInput'),
        setDeviceNameBtn: document.getElementById('setDeviceNameBtn'),

        // Calibration tabs and panels
        autoCalibrationTab: document.getElementById('autoCalibrationTab'),
        manualCalibrationTab: document.getElementById('manualCalibrationTab'),
        autoCalibrationPanel: document.getElementById('autoCalibrationPanel'),
        manualCalibrationPanel: document.getElementById('manualCalibrationPanel'),
        calibrationWeightInput: document.getElementById('calibrationWeightInput'),
        calibrationWeightUnit: document.getElementById('calibrationWeightUnit'),
        calibrationWeightDisplay: document.getElementById('calibrationWeightDisplay'),
        manualCalibrationInput: document.getElementById('manualCalibrationInput'),
        setCalibrationBtn: document.getElementById('setCalibrationBtn')
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

    // Calibration tab switching
    elements.autoCalibrationTab.addEventListener('click', () => {
        elements.autoCalibrationTab.classList.add('active');
        elements.manualCalibrationTab.classList.remove('active');
        elements.autoCalibrationPanel.style.display = 'block';
        elements.manualCalibrationPanel.style.display = 'none';
    });

    elements.manualCalibrationTab.addEventListener('click', () => {
        elements.manualCalibrationTab.classList.add('active');
        elements.autoCalibrationTab.classList.remove('active');
        elements.manualCalibrationPanel.style.display = 'block';
        elements.autoCalibrationPanel.style.display = 'none';
    });

    // Start Calibration button (Auto calibration)
    elements.startCalibrationBtn.addEventListener('click', async () => {
        try {
            // Get the calibration weight from input
            const weightValue = parseFloat(elements.calibrationWeightInput.value);
            const weightUnit = elements.calibrationWeightUnit.value;

            if (isNaN(weightValue) || weightValue <= 0) {
                alert('Please enter a valid weight greater than 0');
                return;
            }

            // Convert to grams
            if (weightUnit === 'lbs') {
                AppState.calibrationWeightGrams = weightValue * 453.592;
            } else {
                AppState.calibrationWeightGrams = weightValue * 1000; // kg to grams
            }

            // Update the display to show what weight to use
            elements.calibrationWeightDisplay.textContent = weightValue + ' ' + weightUnit;

            // Confirm with user
            if (!confirm('Remove all weight from the scale before starting calibration.\n\nClick OK when the scale is empty.')) {
                return;
            }

            elements.startCalibrationBtn.disabled = true;
            elements.startCalibrationBtn.textContent = 'Starting...';

            await OpenScaleBLE.startCalibration();
            AppState.calibrationInProgress = true;

            // Show calibration in progress UI
            elements.calibrationNormal.style.display = 'none';
            elements.calibrationInProgress.style.display = 'block';

            elements.startCalibrationBtn.disabled = false;
            elements.startCalibrationBtn.textContent = 'Start Calibration';
        } catch (error) {
            console.error('Failed to start calibration:', error);
            alert('Failed to start calibration: ' + error.message);
            elements.startCalibrationBtn.disabled = false;
            elements.startCalibrationBtn.textContent = 'Start Calibration';
        }
    });

    // Complete Calibration button (Auto calibration with custom weight)
    elements.completeCalibrationBtn.addEventListener('click', async () => {
        try {
            elements.completeCalibrationBtn.disabled = true;
            elements.completeCalibrationBtn.textContent = 'Calibrating...';

            // Wait a moment for readings to stabilize
            await new Promise(resolve => setTimeout(resolve, 500));

            // Get current raw reading (scale is set to 1.0 during calibration)
            const rawReading = AppState.currentWeight;

            if (rawReading === 0) {
                alert('Error: No reading from scale. Make sure weight is placed on the scale.');
                elements.completeCalibrationBtn.disabled = false;
                elements.completeCalibrationBtn.textContent = 'Complete Calibration';
                return;
            }

            // Calculate calibration factor using user's custom weight
            const newFactor = rawReading / AppState.calibrationWeightGrams;

            // Send the calculated factor to the device
            await OpenScaleBLE.setCalibration(newFactor);

            AppState.calibrationInProgress = false;

            // Show success and return to normal UI
            alert('Calibration complete!\n\nNew calibration factor: ' + newFactor.toFixed(2));

            elements.calibrationInProgress.style.display = 'none';
            elements.calibrationNormal.style.display = 'block';
            elements.completeCalibrationBtn.disabled = false;
            elements.completeCalibrationBtn.textContent = 'Complete Calibration';
        } catch (error) {
            console.error('Failed to complete calibration:', error);
            alert('Failed to complete calibration: ' + error.message);
            elements.completeCalibrationBtn.disabled = false;
            elements.completeCalibrationBtn.textContent = 'Complete Calibration';
        }
    });

    // Cancel Calibration button
    elements.cancelCalibrationBtn.addEventListener('click', async () => {
        AppState.calibrationInProgress = false;
        elements.calibrationInProgress.style.display = 'none';
        elements.calibrationNormal.style.display = 'block';

        // Re-read calibration to restore proper scale factor on device
        if (OpenScaleBLE.isConnected) {
            await OpenScaleBLE.readCalibration();
        }
    });

    // Manual Calibration - Set Factor button
    elements.setCalibrationBtn.addEventListener('click', async () => {
        const factor = parseFloat(elements.manualCalibrationInput.value);

        if (isNaN(factor) || factor <= 0) {
            alert('Please enter a valid calibration factor greater than 0');
            return;
        }

        try {
            elements.setCalibrationBtn.disabled = true;
            elements.setCalibrationBtn.textContent = 'Setting...';

            await OpenScaleBLE.setCalibration(factor);

            alert('Calibration factor set to ' + factor.toFixed(2));

            elements.setCalibrationBtn.disabled = false;
            elements.setCalibrationBtn.textContent = 'Set Factor';
            elements.manualCalibrationInput.value = '';
        } catch (error) {
            console.error('Failed to set calibration factor:', error);
            alert('Failed to set calibration factor: ' + error.message);
            elements.setCalibrationBtn.disabled = false;
            elements.setCalibrationBtn.textContent = 'Set Factor';
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

    // Time range selector
    elements.timeRangeSelect.addEventListener('change', (e) => {
        const value = e.target.value;

        if (value === 'all') {
            AppState.timeRangeMode = 'all';
            elements.customRangeControls.style.display = 'none';
        } else if (value === 'custom') {
            AppState.timeRangeMode = 'custom';
            elements.customRangeControls.style.display = 'flex';
            // Pre-fill with current visible range
            if (AppState.weightHistory.length > 0 && AppState.connectionStartTime) {
                const totalSeconds = (Date.now() - AppState.connectionStartTime) / 1000;
                elements.customRangeStart.value = Math.max(0, Math.floor(totalSeconds - 300));
                elements.customRangeEnd.value = Math.floor(totalSeconds);
            }
        } else {
            AppState.timeRangeMode = 'recent';
            AppState.timeRangeSeconds = parseInt(value);
            elements.customRangeControls.style.display = 'none';
        }

        // Reset zoom when changing mode
        resetChartZoom();
        updateChart();
    });

    // Apply custom range button
    elements.applyCustomRangeBtn.addEventListener('click', () => {
        const start = parseFloat(elements.customRangeStart.value) || 0;
        const end = parseFloat(elements.customRangeEnd.value) || 300;

        if (start >= end) {
            alert('Start time must be less than end time');
            return;
        }

        AppState.customRangeStart = start;
        AppState.customRangeEnd = end;
        resetChartZoom();
        updateChart();
    });

    // Reset zoom button
    elements.resetZoomBtn.addEventListener('click', () => {
        resetChartZoom();
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
            elements.startCalibrationBtn.disabled = false;
            elements.setCalibrationBtn.disabled = false;
            elements.setDeviceNameBtn.disabled = false;
            elements.sampleRateSlider.disabled = false;
            // Reset calibration UI to normal state
            elements.calibrationInProgress.style.display = 'none';
            elements.calibrationNormal.style.display = 'block';
            AppState.calibrationInProgress = false;
            // Reset graph data and start time for new connection
            AppState.connectionStartTime = Date.now();
            AppState.weightHistory = [];
            AppState.isZoomed = false;
            elements.resetZoomBtn.style.display = 'none';
        } else {
            elements.connectionStatus.textContent = 'Disconnected';
            elements.connectionStatus.className = 'status disconnected';
            elements.deviceNameDisplay.textContent = '--';
            elements.connectBtn.style.display = 'inline-block';
            elements.connectBtn.disabled = false;
            elements.connectBtn.textContent = 'Connect';
            elements.disconnectBtn.style.display = 'none';
            elements.tareBtn.disabled = true;
            elements.startCalibrationBtn.disabled = true;
            elements.setCalibrationBtn.disabled = true;
            elements.setDeviceNameBtn.disabled = true;
            elements.sampleRateSlider.disabled = true;
            // Reset calibration UI and show factor as unknown
            elements.calibrationInProgress.style.display = 'none';
            elements.calibrationNormal.style.display = 'block';
            elements.calibrationFactorDisplay.textContent = '--';
            AppState.calibrationInProgress = false;
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
        // Update max history length based on sample rate (store up to 1 hour)
        AppState.maxHistoryLength = rate * 3600;
    };

    OpenScaleBLE.onCalibrationUpdate = (factor) => {
        AppState.calibrationFactor = factor;
        elements.calibrationFactorDisplay.textContent = factor.toFixed(2);
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

// Initialize Chart.js with zoom plugin
function initChart() {
    const ctx = elements.chartCanvas.getContext('2d');

    AppState.chart = new Chart(ctx, {
        type: 'line',
        data: {
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
            parsing: false,
            normalized: true,
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
                            const value = context.parsed.y;
                            if (unit === Units.grams) {
                                return value.toFixed(0) + ' ' + unit.label;
                            } else if (unit === Units.kg) {
                                return value.toFixed(2) + ' ' + unit.label;
                            } else {
                                return value.toFixed(1) + ' ' + unit.label;
                            }
                        },
                        title: (context) => {
                            if (context.length > 0) {
                                return context[0].parsed.x.toFixed(1) + 's';
                            }
                            return '';
                        }
                    }
                },
                zoom: {
                    pan: {
                        enabled: true,
                        mode: 'x'
                    },
                    zoom: {
                        wheel: {
                            enabled: true
                        },
                        pinch: {
                            enabled: true
                        },
                        drag: {
                            enabled: true,
                            backgroundColor: 'rgba(59, 130, 246, 0.2)',
                            borderColor: '#3b82f6',
                            borderWidth: 1
                        },
                        mode: 'x',
                        onZoomComplete: ({ chart }) => {
                            AppState.isZoomed = true;
                            elements.resetZoomBtn.style.display = 'inline-block';
                        }
                    }
                }
            },
            scales: {
                x: {
                    type: 'linear',
                    display: true,
                    title: {
                        display: true,
                        text: 'Time (s)',
                        color: '#64748b'
                    },
                    ticks: {
                        color: '#64748b',
                        maxTicksLimit: 8,
                        callback: (value) => value.toFixed(0)
                    },
                    grid: {
                        color: 'rgba(100, 116, 139, 0.1)'
                    }
                },
                y: {
                    type: 'linear',
                    display: true,
                    title: {
                        display: true,
                        text: 'Force (lbs)',
                        color: '#64748b'
                    },
                    ticks: {
                        color: '#64748b',
                        callback: (value) => {
                            const unit = Units[AppState.unit];
                            if (unit === Units.grams) {
                                return value.toFixed(0);
                            } else if (unit === Units.kg) {
                                return value.toFixed(1);
                            } else {
                                return value.toFixed(1);
                            }
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

    // Double-click to reset zoom
    elements.chartCanvas.addEventListener('dblclick', () => {
        resetChartZoom();
    });
}

// Update chart with new data
function updateChart() {
    if (!AppState.chart) return;

    const unit = Units[AppState.unit];

    // Update Y-axis title to show current unit
    AppState.chart.options.scales.y.title.text = `Force (${unit.label})`;

    if (AppState.weightHistory.length === 0) {
        AppState.chart.data.datasets[0].data = [];
        AppState.chart.update('none');
        return;
    }

    // Don't update data while zoomed (preserve zoom view)
    if (AppState.isZoomed) {
        AppState.chart.update('none');
        return;
    }

    const connectionStart = AppState.connectionStartTime || AppState.weightHistory[0].time;
    const now = Date.now();

    // Filter data based on time range mode
    let filteredData = AppState.weightHistory;
    let xMin = null;
    let xMax = null;

    if (AppState.timeRangeMode === 'recent') {
        const cutoffTime = now - (AppState.timeRangeSeconds * 1000);
        filteredData = AppState.weightHistory.filter(d => d.time >= cutoffTime);
        // Set x-axis bounds for recent mode
        xMin = (cutoffTime - connectionStart) / 1000;
        xMax = (now - connectionStart) / 1000;
    } else if (AppState.timeRangeMode === 'custom' && AppState.customRangeStart !== null && AppState.customRangeEnd !== null) {
        const startTime = connectionStart + (AppState.customRangeStart * 1000);
        const endTime = connectionStart + (AppState.customRangeEnd * 1000);
        filteredData = AppState.weightHistory.filter(d => d.time >= startTime && d.time <= endTime);
        // Set x-axis bounds for custom mode
        xMin = AppState.customRangeStart;
        xMax = AppState.customRangeEnd;
    }
    // 'all' mode uses all data with auto bounds

    // Convert to chart data with {x, y} format
    const chartData = filteredData.map(d => ({
        x: (d.time - connectionStart) / 1000,
        y: unit.convert(d.weight)
    }));

    AppState.chart.data.datasets[0].data = chartData;

    // Set x-axis bounds
    if (xMin !== null && xMax !== null) {
        AppState.chart.options.scales.x.min = Math.max(0, xMin);
        AppState.chart.options.scales.x.max = xMax;
    } else {
        // Auto scale for 'all' mode
        AppState.chart.options.scales.x.min = undefined;
        AppState.chart.options.scales.x.max = undefined;
    }

    AppState.chart.update('none');
}

// Reset chart zoom
function resetChartZoom() {
    if (AppState.chart) {
        AppState.chart.resetZoom();
        AppState.isZoomed = false;
        elements.resetZoomBtn.style.display = 'none';
    }
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
