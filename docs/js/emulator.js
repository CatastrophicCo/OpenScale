// OpenScale Device Emulator
// Simulates an OpenScale device for testing without physical hardware

const OpenScaleEmulator = {
    // Emulator state
    isRunning: false,
    isConnected: false,

    // Simulated device values
    deviceName: 'OpenScale-EMU',
    sampleRate: 10,
    calibrationFactor: 420.0,
    currentWeight: 0.0,
    tareOffset: 0.0,

    // Simulation settings
    simulationMode: 'pulls', // 'noise', 'pulls', 'hold', 'ramp', 'manual'
    manualWeight: 0.0,
    noiseLevel: 50.0, // grams of noise

    // Callbacks (same as OpenScaleBLE)
    onWeightUpdate: null,
    onConnectionChange: null,
    onSampleRateUpdate: null,
    onCalibrationUpdate: null,
    onDeviceNameUpdate: null,

    // Internal state
    _intervalId: null,
    _simulationState: {
        phase: 'rest',
        phaseTime: 0,
        targetWeight: 0,
        pullCount: 0
    },

    // Check if emulator is available (always true)
    isSupported() {
        return true;
    },

    isSecureContext() {
        return true;
    },

    // Connect to emulated device
    async connect() {
        console.log('[Emulator] Connecting...');
        return new Promise((resolve) => {
            // Simulate connection delay
            setTimeout(() => {
                this.isConnected = true;
                this.isRunning = true;
                this._startSimulation();

                console.log('[Emulator] Connected, calling callbacks...');
                console.log('[Emulator] onConnectionChange exists:', !!this.onConnectionChange);

                if (this.onConnectionChange) {
                    this.onConnectionChange(true, this.deviceName);
                }
                if (this.onSampleRateUpdate) {
                    this.onSampleRateUpdate(this.sampleRate);
                }
                if (this.onCalibrationUpdate) {
                    this.onCalibrationUpdate(this.calibrationFactor);
                }
                if (this.onDeviceNameUpdate) {
                    this.onDeviceNameUpdate(this.deviceName);
                }

                console.log('[Emulator] Connected to', this.deviceName, 'with mode:', this.simulationMode);
                resolve(this.deviceName);
            }, 500);
        });
    },

    // Disconnect
    disconnect() {
        this._stopSimulation();
        this.isConnected = false;
        this.isRunning = false;

        if (this.onConnectionChange) {
            this.onConnectionChange(false, null);
        }

        console.log('[Emulator] Disconnected');
    },

    // Tare the scale
    async tare() {
        this.tareOffset = this.currentWeight + this.tareOffset;
        console.log('[Emulator] Tared, offset:', this.tareOffset);
    },

    // Read sample rate
    async readSampleRate() {
        if (this.onSampleRateUpdate) {
            this.onSampleRateUpdate(this.sampleRate);
        }
        return this.sampleRate;
    },

    // Set sample rate
    async setSampleRate(rate) {
        this.sampleRate = Math.max(1, Math.min(80, rate));
        this._restartSimulation();
        if (this.onSampleRateUpdate) {
            this.onSampleRateUpdate(this.sampleRate);
        }
        console.log('[Emulator] Sample rate set to', this.sampleRate, 'Hz');
    },

    // Read calibration
    async readCalibration() {
        if (this.onCalibrationUpdate) {
            this.onCalibrationUpdate(this.calibrationFactor);
        }
        return this.calibrationFactor;
    },

    // Set calibration
    async setCalibration(factor) {
        this.calibrationFactor = factor;
        if (this.onCalibrationUpdate) {
            this.onCalibrationUpdate(this.calibrationFactor);
        }
        console.log('[Emulator] Calibration set to', factor);
    },

    // Start calibration (emulated)
    async startCalibration() {
        console.log('[Emulator] Calibration started - place weight on scale');
        // In emulation, we just set scale to raw mode (factor = 1)
        this.calibrationFactor = 1.0;
    },

    // Complete calibration (emulated)
    async completeCalibration() {
        // Simulate calculating a new factor
        this.calibrationFactor = 420.0;
        if (this.onCalibrationUpdate) {
            this.onCalibrationUpdate(this.calibrationFactor);
        }
        console.log('[Emulator] Calibration complete, factor:', this.calibrationFactor);
        return this.calibrationFactor;
    },

    // Read device name
    async readDeviceName() {
        if (this.onDeviceNameUpdate) {
            this.onDeviceNameUpdate(this.deviceName);
        }
        return this.deviceName;
    },

    // Set device name
    async setDeviceName(name) {
        this.deviceName = name.substring(0, 20);
        if (this.onDeviceNameUpdate) {
            this.onDeviceNameUpdate(this.deviceName);
        }
        console.log('[Emulator] Device name set to', this.deviceName);
    },

    // =========================================================================
    // Emulator-specific methods
    // =========================================================================

    // Set simulation mode
    setSimulationMode(mode) {
        this.simulationMode = mode;
        this._simulationState = {
            phase: 'rest',
            phaseTime: 0,
            targetWeight: 0,
            pullCount: 0
        };
        console.log('[Emulator] Simulation mode:', mode);
    },

    // Set manual weight (for manual mode)
    setManualWeight(weightGrams) {
        this.manualWeight = weightGrams;
    },

    // Set noise level
    setNoiseLevel(level) {
        this.noiseLevel = level;
    },

    // =========================================================================
    // Internal simulation methods
    // =========================================================================

    _startSimulation() {
        const interval = 1000 / this.sampleRate;
        this._intervalId = setInterval(() => this._simulationTick(), interval);
    },

    _stopSimulation() {
        if (this._intervalId) {
            clearInterval(this._intervalId);
            this._intervalId = null;
        }
    },

    _restartSimulation() {
        this._stopSimulation();
        if (this.isRunning) {
            this._startSimulation();
        }
    },

    _simulationTick() {
        let weight = 0;

        switch (this.simulationMode) {
            case 'noise':
                weight = this._generateNoise();
                break;
            case 'pulls':
                weight = this._generatePulls();
                break;
            case 'hold':
                weight = this._generateHold();
                break;
            case 'ramp':
                weight = this._generateRamp();
                break;
            case 'manual':
                weight = this.manualWeight + this._addNoise(0, this.noiseLevel * 0.1);
                break;
            default:
                weight = this._generateNoise();
        }

        // Apply tare offset
        this.currentWeight = weight - this.tareOffset;

        // Send update
        if (this.onWeightUpdate) {
            this.onWeightUpdate(this.currentWeight);
        }
    },

    // Generate random noise around zero
    _generateNoise() {
        return this._addNoise(0, this.noiseLevel);
    },

    // Generate realistic climbing pull patterns
    _generatePulls() {
        const state = this._simulationState;
        const ticksPerSecond = this.sampleRate;

        state.phaseTime++;

        switch (state.phase) {
            case 'rest':
                // Rest for 2-5 seconds
                if (state.phaseTime > ticksPerSecond * (2 + Math.random() * 3)) {
                    state.phase = 'loading';
                    state.phaseTime = 0;
                    state.targetWeight = 15000 + Math.random() * 25000; // 15-40 kg in grams
                }
                return this._addNoise(0, this.noiseLevel);

            case 'loading':
                // Quick ramp up (0.3-0.5 seconds)
                const loadDuration = ticksPerSecond * (0.3 + Math.random() * 0.2);
                const loadProgress = Math.min(1, state.phaseTime / loadDuration);
                const loadWeight = state.targetWeight * this._easeOutQuad(loadProgress);

                if (loadProgress >= 1) {
                    state.phase = 'holding';
                    state.phaseTime = 0;
                }
                return this._addNoise(loadWeight, this.noiseLevel);

            case 'holding':
                // Hold for 3-10 seconds
                if (state.phaseTime > ticksPerSecond * (3 + Math.random() * 7)) {
                    state.phase = 'releasing';
                    state.phaseTime = 0;
                }
                // Add some fatigue variation
                const fatigue = 1 - (state.phaseTime / (ticksPerSecond * 15)) * 0.1;
                return this._addNoise(state.targetWeight * fatigue, this.noiseLevel);

            case 'releasing':
                // Quick release (0.2-0.4 seconds)
                const releaseDuration = ticksPerSecond * (0.2 + Math.random() * 0.2);
                const releaseProgress = Math.min(1, state.phaseTime / releaseDuration);
                const releaseWeight = state.targetWeight * (1 - this._easeInQuad(releaseProgress));

                if (releaseProgress >= 1) {
                    state.phase = 'rest';
                    state.phaseTime = 0;
                    state.pullCount++;
                }
                return this._addNoise(releaseWeight, this.noiseLevel);
        }

        return 0;
    },

    // Generate a sustained hold
    _generateHold() {
        const state = this._simulationState;
        const ticksPerSecond = this.sampleRate;

        state.phaseTime++;

        if (state.phase === 'rest') {
            // Start loading after 2 seconds
            if (state.phaseTime > ticksPerSecond * 2) {
                state.phase = 'loading';
                state.phaseTime = 0;
                state.targetWeight = 20000; // 20 kg
            }
            return this._addNoise(0, this.noiseLevel);
        } else if (state.phase === 'loading') {
            const loadDuration = ticksPerSecond * 0.5;
            const progress = Math.min(1, state.phaseTime / loadDuration);
            if (progress >= 1) {
                state.phase = 'holding';
            }
            return this._addNoise(state.targetWeight * this._easeOutQuad(progress), this.noiseLevel);
        } else {
            // Sustained hold with gradual fatigue
            const fatigue = 1 - (state.phaseTime / (ticksPerSecond * 60)) * 0.15;
            return this._addNoise(state.targetWeight * Math.max(0.7, fatigue), this.noiseLevel);
        }
    },

    // Generate a slow ramp up/down
    _generateRamp() {
        const state = this._simulationState;
        const ticksPerSecond = this.sampleRate;
        const cycleLength = ticksPerSecond * 10; // 10 second cycles

        state.phaseTime++;

        const cyclePosition = (state.phaseTime % (cycleLength * 2)) / cycleLength;
        let weight;

        if (cyclePosition < 1) {
            // Ramping up
            weight = 30000 * cyclePosition; // 0 to 30 kg
        } else {
            // Ramping down
            weight = 30000 * (2 - cyclePosition); // 30 kg to 0
        }

        return this._addNoise(weight, this.noiseLevel);
    },

    // Add gaussian-like noise
    _addNoise(value, amplitude) {
        // Box-Muller transform for gaussian noise
        const u1 = Math.random();
        const u2 = Math.random();
        const gaussian = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
        return value + gaussian * amplitude * 0.5;
    },

    // Easing functions
    _easeOutQuad(t) {
        return 1 - (1 - t) * (1 - t);
    },

    _easeInQuad(t) {
        return t * t;
    }
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OpenScaleEmulator;
}
