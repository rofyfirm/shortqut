import Foundation

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

    // MARK: State machine (hanya diakses dari thread callback trackpad)

    private var gestureActive = false
    private var gestureInvalid = false
    private var gestureStart: TimeInterval = 0
    private var anchorX: Float = 0
    private var anchorY: Float = 0
    private var lastFire: TimeInterval = 0

    // MARK: Lifecycle

    func start() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let lib = dlopen(path, RTLD_NOW),
              let createSym = dlsym(lib, "MTDeviceCreateList"),
              let registerSym = dlsym(lib, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(lib, "MTDeviceStart")
        else {
            NSLog("Shortqut: MultitouchSupport tidak tersedia")
            return
        }

        let createList = unsafeBitCast(createSym, to: CreateListFn.self)
        let register = unsafeBitCast(registerSym, to: RegisterFn.self)
        let startDevice = unsafeBitCast(startSym, to: StartFn.self)

        guard let list = createList()?.takeRetainedValue() else {
            NSLog("Shortqut: tidak ada trackpad yang terdeteksi")
            return
        }

        Self.current = self
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            register(device, Self.contactCallback)
            startDevice(device, 0)
            devices.append(device)
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
