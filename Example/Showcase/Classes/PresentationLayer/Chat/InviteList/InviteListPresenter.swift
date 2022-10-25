import UIKit
import Combine
import WalletConnectChat

final class InviteListPresenter: ObservableObject {

    private let interactor: InviteListInteractor
    private let router: InviteListRouter
    private let account: Account
    private var disposeBag = Set<AnyCancellable>()

    @Published var invites: [InviteViewModel] = []

    init(interactor: InviteListInteractor, router: InviteListRouter, account: Account) {
        self.interactor = interactor
        self.router = router
        self.account = account
    }

    @MainActor
    func setupInitialState() async {
        await loadInvites(account: account)

        for await _ in interactor.invitesSubscription() {
            await loadInvites(account: account)
        }
    }

    func didPressAccept(invite: InviteViewModel) {
        Task(priority: .userInitiated) {
            await interactor.accept(invite: invite.invite)
            await dismiss()
        }
    }

    func didPressReject(invite: InviteViewModel) {
        Task(priority: .userInitiated) {
            await interactor.reject(invite: invite.invite)
            await dismiss()
        }
    }
}

// MARK: SceneViewModel

extension InviteListPresenter: SceneViewModel {

    var sceneTitle: String? {
        return "Chat Requests"
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .always
    }
}

// MARK: Privates

private extension InviteListPresenter {

    @MainActor
    func loadInvites(account: Account) async {
        let invites = await interactor.getInvites(account: account)
        self.invites = invites.sorted(by: { $0.publicKey < $1.publicKey })
            .map { InviteViewModel(invite: $0) }
    }

    @MainActor
    func dismiss() {
        router.dismiss()
    }
}
