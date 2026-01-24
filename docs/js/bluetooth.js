// OpenScale Web Bluetooth API Wrapper

const OpenScaleBLE = {
    // BLE UUIDs (must match firmware)
    SERVICE_UUID: '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
    WEIGHT_CHAR_UUID: 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
    TARE_CHAR_UUID: '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e',
    SAMPLE_RATE_CHAR_UUID: 'a8985fae-51a4-4e28-b0a2-6c1aeede3f3d',
    CALIBRATION_CHAR_UUID: 'd5875408-fa51-4e89-a0f7-3c7e8e8c5e41',
    DEVICE_NAME_CHAR_UUID: '8a2c5f47-b91e-4d36-a6c8-9f0e7d3b1c28',

    // State
    device: null,
    server: null,
    service: null,
    characteristics: {},
    isConnected: false,

    // Callbacks
    onWeightUpdate: null,
    onConnectionChange: null,
    onSampleRateUpdate: null,
    onCalibrationUpdate: null,
    onDeviceNameUpdate: null,

    // Check if Web Bluetooth is supported
    isSupported() {
        return 'bluetooth' in navigator;
    },

    // Check if we're on HTTPS or localhost
    isSecureContext() {
        return window.isSecureContext;
    },

    // Connect to an OpenScale device
    async connect() {
        if (!this.isSupported()) {
            throw new Error('Web Bluetooth is not supported in this browser. Please use Chrome, Edge, or Opera.');
        }

        if (!this.isSecureContext()) {
            throw new Error('Web Bluetooth requires HTTPS or localhost.');
        }

        try {
            // Request device with OpenScale service
            this.device = await navigator.bluetooth.requestDevice({
                filters: [{ services: [this.SERVICE_UUID] }],
                optionalServices: []
            });

            // Set up disconnect listener
            this.device.addEventListener('gattserverdisconnected', () => {
                this.handleDisconnect();
            });

            // Connect to GATT server
            console.log('Connecting to GATT Server...');
            this.server = await this.device.gatt.connect();

            // Get the OpenScale service
            console.log('Getting Service...');
            this.service = await this.server.getPrimaryService(this.SERVICE_UUID);

            // Get characteristics
            console.log('Getting Characteristics...');
            await this.getCharacteristics();

            // Subscribe to weight notifications
            await this.subscribeToWeight();

            // Read initial values
            await this.readSampleRate();
            await this.readCalibration();
            await this.readDeviceName();

            this.isConnected = true;
            if (this.onConnectionChange) {
                this.onConnectionChange(true, this.device.name);
            }

            console.log('Connected to', this.device.name);
            return this.device.name;

        } catch (error) {
            console.error('Connection error:', error);
            this.isConnected = false;
            if (this.onConnectionChange) {
                this.onConnectionChange(false, null);
            }
            throw error;
        }
    },

    // Get all characteristics
    async getCharacteristics() {
        try {
            this.characteristics.weight = await this.service.getCharacteristic(this.WEIGHT_CHAR_UUID);
            this.characteristics.tare = await this.service.getCharacteristic(this.TARE_CHAR_UUID);
            this.characteristics.sampleRate = await this.service.getCharacteristic(this.SAMPLE_RATE_CHAR_UUID);
            this.characteristics.calibration = await this.service.getCharacteristic(this.CALIBRATION_CHAR_UUID);
            this.characteristics.deviceName = await this.service.getCharacteristic(this.DEVICE_NAME_CHAR_UUID);
        } catch (error) {
            console.error('Error getting characteristics:', error);
            throw error;
        }
    },

    // Subscribe to weight notifications
    async subscribeToWeight() {
        try {
            await this.characteristics.weight.startNotifications();
            this.characteristics.weight.addEventListener('characteristicvaluechanged', (event) => {
                const value = event.target.value;
                const weight = value.getFloat32(0, true); // Little-endian
                if (this.onWeightUpdate) {
                    this.onWeightUpdate(weight);
                }
            });
            console.log('Subscribed to weight notifications');
        } catch (error) {
            console.error('Error subscribing to weight:', error);
            throw error;
        }
    },

    // Disconnect
    disconnect() {
        if (this.device && this.device.gatt.connected) {
            this.device.gatt.disconnect();
        }
    },

    // Handle disconnect event
    handleDisconnect() {
        console.log('Device disconnected');
        this.isConnected = false;
        this.device = null;
        this.server = null;
        this.service = null;
        this.characteristics = {};
        if (this.onConnectionChange) {
            this.onConnectionChange(false, null);
        }
    },

    // Send tare command
    async tare() {
        if (!this.isConnected || !this.characteristics.tare) {
            throw new Error('Not connected');
        }
        try {
            const data = new Uint8Array([0x01]);
            await this.characteristics.tare.writeValue(data);
            console.log('Tare command sent');
        } catch (error) {
            console.error('Error sending tare:', error);
            throw error;
        }
    },

    // Read sample rate
    async readSampleRate() {
        if (!this.isConnected || !this.characteristics.sampleRate) {
            return null;
        }
        try {
            const value = await this.characteristics.sampleRate.readValue();
            const rate = value.getUint8(0);
            if (this.onSampleRateUpdate) {
                this.onSampleRateUpdate(rate);
            }
            return rate;
        } catch (error) {
            console.error('Error reading sample rate:', error);
            return null;
        }
    },

    // Set sample rate (1-80 Hz)
    async setSampleRate(rate) {
        if (!this.isConnected || !this.characteristics.sampleRate) {
            throw new Error('Not connected');
        }
        rate = Math.max(1, Math.min(80, rate));
        try {
            const data = new Uint8Array([rate]);
            await this.characteristics.sampleRate.writeValue(data);
            console.log('Sample rate set to', rate, 'Hz');
            if (this.onSampleRateUpdate) {
                this.onSampleRateUpdate(rate);
            }
        } catch (error) {
            console.error('Error setting sample rate:', error);
            throw error;
        }
    },

    // Read calibration factor
    async readCalibration() {
        if (!this.isConnected || !this.characteristics.calibration) {
            return null;
        }
        try {
            const value = await this.characteristics.calibration.readValue();
            const factor = value.getFloat32(0, true); // Little-endian
            if (this.onCalibrationUpdate) {
                this.onCalibrationUpdate(factor);
            }
            return factor;
        } catch (error) {
            console.error('Error reading calibration:', error);
            return null;
        }
    },

    // Set calibration factor
    async setCalibration(factor) {
        if (!this.isConnected || !this.characteristics.calibration) {
            throw new Error('Not connected');
        }
        try {
            const buffer = new ArrayBuffer(4);
            const view = new DataView(buffer);
            view.setFloat32(0, factor, true); // Little-endian
            await this.characteristics.calibration.writeValue(buffer);
            console.log('Calibration factor set to', factor);
            if (this.onCalibrationUpdate) {
                this.onCalibrationUpdate(factor);
            }
        } catch (error) {
            console.error('Error setting calibration:', error);
            throw error;
        }
    },

    // Read device name
    async readDeviceName() {
        if (!this.isConnected || !this.characteristics.deviceName) {
            return null;
        }
        try {
            const value = await this.characteristics.deviceName.readValue();
            const decoder = new TextDecoder('utf-8');
            const name = decoder.decode(value);
            if (this.onDeviceNameUpdate) {
                this.onDeviceNameUpdate(name);
            }
            return name;
        } catch (error) {
            console.error('Error reading device name:', error);
            return null;
        }
    },

    // Set device name (max 20 chars)
    async setDeviceName(name) {
        if (!this.isConnected || !this.characteristics.deviceName) {
            throw new Error('Not connected');
        }
        name = name.substring(0, 20); // Max 20 chars
        try {
            const encoder = new TextEncoder();
            const data = encoder.encode(name);
            await this.characteristics.deviceName.writeValue(data);
            console.log('Device name set to', name);
            if (this.onDeviceNameUpdate) {
                this.onDeviceNameUpdate(name);
            }
        } catch (error) {
            console.error('Error setting device name:', error);
            throw error;
        }
    }
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OpenScaleBLE;
}
