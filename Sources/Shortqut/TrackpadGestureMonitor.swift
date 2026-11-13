import AppKit

/// Mendeteksi ketukan 4 jari di trackpad.
///
/// Memakai framework privat MultitouchSupport (dimuat dengan dlopen).
/// Ini tidak didukung resmi oleh Apple dan membuat app tidak bisa masuk Mac App Store.
final class TrackpadGestureMonitor {
    var onFourFingerTap: (() -> Void)?

    // MARK: Tuning

    private let requiredFingers = 4
    /// Durasi maksimal dari jari pertama menyentuh sampai semua terangkat
    private let maxTapDuration: TimeInterval = 0.45
    /// Pergeseran maksimal pusat jari (skala 0...1 pada permukaan trackpad)
    private let maxDrift: Float = 0.08
    /// Jeda minimal antar pemicu agar tidak terpanggil dua kali
    private let cooldown: TimeInterval = 0.6

    // MARK: Bridge ke MultitouchSupport

    private typealias MTDeviceRef = UnsafeMutableRawPointer
    private typealias MTContactCallback = @convention(c) (
        MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32
    ) -> Int32
    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterFn = @convention(c) (MTDeviceRef, MTContactCallback) -> Void
    private typealias StartFn = @convention(c) (MTDeviceRef, Int32) -> Void
    private typealias StopFn = @convention(c) (MTDeviceRef) -> Void
    private typealias UnregisterFn = @convention(c) (MTDeviceRef, MTContactCallback) -> Void

    private struct MTPoint {
        var x: Float
        var y: Float
    }

    private struct MTVector {
        var position: MTPoint
        var velocity: MTPoint
    }

    /// Layout MTTouch (96 byte) hasil reverse engineering. Hanya field yang dipakai yang penting.
    private struct MTTouch {
        var frame: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32
        var fingerID: Int32
        var handID: Int32
        var normalized: MTVector
        var size: Float
        var pressure: Int32
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var absolute: MTVector
        var unknown1: Int32
        var unknown2: Int32
        var density: Float
    }

    private static var current: TrackpadGestureMonitor?

    private static let contactCallback: MTContactCallback = { _, touches, count, _, _ in
        TrackpadGestureMonitor.current?.handle(touches: touches, count: Int(count))
        return 0
    }

    private var devices: [MTDeviceRef] = []

    private var createList: CreateListFn?
    private var registerCallback: RegisterFn?
    private var unregisterCallback: UnregisterFn?
    private var startDevice: StartFn?
    private var stopDevice: StopFn?
    private var wakeObservers: [NSObjectProtocol] = []
    private var restartWork: DispatchWorkItem?

    // MARK: State machine (hanya diakses dari thread callback trackpad)

    private var gestureActive = false
    private var gestureInvalid = false
    private var gestureStart: TimeInterval = 0
    private var anchorX: Float = 0
    private var anchorY: Float = 0
    private var lastFire: TimeInterval = 0

    // MARK: Lifecycle

    func start() {
        guard loadFunctions() else { return }
        _ = startDevices()
        observeWake()
    }

    private func loadFunctions() -> Bool {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let lib = dlopen(path, RTLD_NOW),
              let createSym = dlsym(lib, "MTDeviceCreateList"),
              let registerSym = dlsym(lib, "MTRegisterContactFrameCallback"),
              let unregisterSym = dlsym(lib, "MTUnregisterContactFrameCallback"),
              let startSym = dlsym(lib, "MTDeviceStart"),
              let stopSym = dlsym(lib, "MTDeviceStop")
        else {
            NSLog("Shortqut: MultitouchSupport tidak tersedia")
            return false
        }

        createList = unsafeBitCast(createSym, to: CreateListFn.self)
        registerCallback = unsafeBitCast(registerSym, to: RegisterFn.self)
        unregisterCallback = unsafeBitCast(unregisterSym, to: UnregisterFn.self)
        startDevice = unsafeBitCast(startSym, to: StartFn.self)
        stopDevice = unsafeBitCast(stopSym, to: StopFn.self)
        return true
    }

    /// Mendaftarkan dan menjalankan semua trackpad. Mengembalikan jumlah perangkat yang berhasil.
    @discardableResult
    private func startDevices() -> Int {
        guard let createList, let registerCallback, let startDevice else { return 0 }
        guard let list = createList()?.takeRetainedValue() else {
            NSLog("Shortqut: tidak ada trackpad yang terdeteksi")
            return 0
        }

        Self.current = self
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            registerCallback(device, Self.contactCallback)
            startDevice(device, 0)
            devices.append(device)
        }
        return devices.count
    }

    private func stopDevices() {
        for device in devices {
            unregisterCallback?(device, Self.contactCallback)
            stopDevice?(device)
        }
        devices.removeAll()

        // Callback sudah dilepas, jadi aman mereset status gesture
        gestureActive = false
        gestureInvalid = false
    }

    // MARK: Sleep / wake

    /// Setelah Mac bangun dari sleep, perangkat trackpad sering berhenti mengirim frame sentuhan.
    /// Karena itu semua perangkat didaftar ulang setiap kali Mac atau layar bangun.
    private func observeWake() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRestart(attempt: 0)
            }
            wakeObservers.append(token)
        }
    }

    /// Jeda singkat agar trackpad siap dulu. Jika belum ada perangkat, dicoba ulang.
    private func scheduleRestart(attempt: Int) {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restartDevices(attempt: attempt)
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func restartDevices(attempt: Int) {
        stopDevices()
        let count = startDevices()
        NSLog("Shortqut: trackpad didaftarkan ulang (\(count) perangkat, percobaan \(attempt + 1))")

        if count == 0, attempt < 5 {
            scheduleRestart(attempt: attempt + 1)
        }
    }

    // MARK: Gesture logic

    private func handle(touches: UnsafeMutableRawPointer?, count: Int) {
        let now = ProcessInfo.processInfo.systemUptime

        var fingers = 0
        var sumX: Float = 0
        var sumY: Float = 0

        if let touches, count > 0 {
            let base = touches.assumingMemoryBound(to: MTTouch.self)
            for index in 0..<count {
                let touch = base[index]
                // 3 = MakeTouch, 4 = Touching: jari sedang menyentuh permukaan
                guard touch.state == 3 || touch.state == 4 else { continue }
                fingers += 1
                sumX += touch.normalized.position.x
                sumY += touch.normalized.position.y
            }
        }

        let centerX = fingers > 0 ? sumX / Float(fingers) : 0
        let centerY = fingers > 0 ? sumY / Float(fingers) : 0

        if !gestureActive {
            // Gesture dimulai tepat ketika jumlah jari menjadi 4
            if fingers == requiredFingers {
                gestureActive = true
                gestureInvalid = false
                gestureStart = now
                anchorX = centerX
                anchorY = centerY
            }
            return
        }

        // Gesture berlangsung: batalkan jika terlalu banyak jari, terlalu lama, atau jari bergeser
        if fingers > requiredFingers {
            gestureInvalid = true
        }
        if now - gestureStart > maxTapDuration {
            gestureInvalid = true
        }
        if fingers == requiredFingers,
           abs(centerX - anchorX) > maxDrift || abs(centerY - anchorY) > maxDrift {
            gestureInvalid = true
        }

        // Semua jari terangkat: ini adalah ketukan jika tidak dibatalkan
        if fingers == 0 {
            let shouldFire = !gestureInvalid && now - lastFire > cooldown
            gestureActive = false

            if shouldFire {
                lastFire = now
                DispatchQueue.main.async { [weak self] in
                    self?.onFourFingerTap?()
                }
            }
        }
    }
}
