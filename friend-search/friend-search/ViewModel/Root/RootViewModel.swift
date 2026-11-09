import Foundation
import Observation

/// 起動・認証状態・プロフィール有無からルート画面を決める
@MainActor
@Observable
final class RootViewModel {
    enum State: Equatable {
        case launching
        case signedOut(message: String?)
        case needsProfile(avatar: AvatarIdentity?)
        case profileLoadFailed(AppError)
        case ready(PublicProfile)
    }

    private(set) var state: State = .launching

    private let restoreSession: any RestoreSessionUseCase
    private let getProfile: any GetProfileUseCase
    private let signOutUseCase: any SignOutUseCase
    private var started = false

    init(
        restoreSession: any RestoreSessionUseCase = DefaultRestoreSessionUseCase(),
        getProfile: any GetProfileUseCase = DefaultGetProfileUseCase(),
        signOut: any SignOutUseCase = DefaultSignOutUseCase()
    ) {
        self.restoreSession = restoreSession
        self.getProfile = getProfile
        self.signOutUseCase = signOut
    }

    func start() async {
        guard !started else { return }
        started = true
        await refreshSession()
    }

    func didCreateProfile(_ profile: PublicProfile) {
        state = .ready(profile)
    }

    func didUpdateProfile(_ profile: PublicProfile) {
        if case .ready = state { state = .ready(profile) }
    }

    func signOut() async {
        try? await signOutUseCase.execute()
        state = .signedOut(message: nil)
    }

    private func refreshSession() async {
        do {
            if try await restoreSession.execute() {
                await loadProfile()
            } else {
                state = .signedOut(message: nil)
            }
        } catch {
            // 通信障害ではログイン画面へ戻さず、再試行できる画面に留める
            state = AppError(error: error) == .network ? .profileLoadFailed(.network) : .signedOut(message: nil)
        }
    }

    /// サインイン直後・再試行時にプロフィールを読み込み、表示する画面を決める
    func loadProfile() async {
        do {
            switch try await getProfile.execute() {
            case .found(let profile): state = .ready(profile)
            case .notCreated(let avatar): state = .needsProfile(avatar: avatar)
            }
        } catch AppError.unauthorized {
            state = .signedOut(message: AppError.unauthorized.message)
        } catch {
            // 未作成と通信障害を区別する
            state = .profileLoadFailed(AppError(error: error))
        }
    }
}
