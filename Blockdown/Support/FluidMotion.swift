import CoreMotion
import Foundation
import Observation

/// Drives the "liquid in the ring" effect: a pool of fluid that slides
/// around the ring tube toward whichever edge of the screen points down,
/// with spring-damped slosh (iOS 27 Liquid Glass ties visuals to the
/// motion sensors; this follows that pattern).
///
/// On hardware it integrates CoreMotion gravity + user acceleration.
/// In the simulator (no gyro) it drives itself with a gentle synthetic
/// slosh so the effect is still visible.
@MainActor
@Observable
final class FluidMotion {
    /// Pool center, in view-space radians (0 = right, π/2 = screen bottom).
    private(set) var poolAngle: Double = .pi / 2
    /// 0 (device flat, fluid spreads out) ... 1 (upright, tight pool).
    private(set) var tilt: Double = 1
    /// Angular velocity of the pool — drives the surface wobble so the
    /// slosh reads visually.
    private(set) var velocity: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var phase: Double = 0

    func start() {
        guard timer == nil else { return }
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates()
        }
        let step = 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(dt: step)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        manager.stopDeviceMotionUpdates()
    }

    private func tick(dt: Double) {
        let target: Double

        if let motion = manager.deviceMotion {
            // Device coords: +x right, +y toward top of screen. View space
            // has y down, so the in-plane "down" direction is (gx, -gy).
            let vx = motion.gravity.x
            let vy = -motion.gravity.y
            let planar = min(1.0, (vx * vx + vy * vy).squareRoot())
            tilt = tilt + (planar - tilt) * 0.15
            target = planar > 0.05 ? atan2(vy, vx) : poolAngle

            // A shake sloshes the fluid tangentially.
            let ax = motion.userAcceleration.x
            let ay = -motion.userAcceleration.y
            let tangential = -sin(poolAngle) * ax + cos(poolAngle) * ay
            velocity += tangential * 9.0
        } else {
            // Simulator: synthetic tilt wandering around the bottom, with
            // occasional kicks so the slosh is obvious.
            phase += dt
            target = .pi / 2 + 1.1 * sin(phase * 1.1) + 0.3 * sin(phase * 2.7)
            velocity += 1.6 * sin(phase * 3.9) * dt
            tilt = 1
        }

        // Under-damped spring so the pool overshoots and sloshes.
        let diff = atan2(sin(target - poolAngle), cos(target - poolAngle))
        velocity += diff * 22.0 * dt
        velocity *= (1 - min(1, 3.6 * dt))
        poolAngle += velocity * dt
    }
}
