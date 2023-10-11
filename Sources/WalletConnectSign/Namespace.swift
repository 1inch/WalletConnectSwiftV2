public enum AutoNamespacesError: Error {
    case requiredChainsNotSatisfied
    case requiredAccountsNotSatisfied
    case requiredMethodsNotSatisfied
    case requiredEventsNotSatisfied
}

public struct ProposalNamespace: Equatable, Codable {

    public let chains: [Blockchain]?
    public let methods: [String]
    public let events: [String]

    public init(chains: [Blockchain]? = nil, methods: [String], events: [String]) {
        self.chains = chains
        self.methods = methods
        self.events = events
    }
}

public struct SessionNamespace: Equatable, Codable {
    public var chains: [Blockchain]?
    public var accounts: [Account]
    public var methods: [String]
    public var events: [String]

    public init(chains: [Blockchain]? = nil, accounts: [Account], methods: [String], events: [String]) {
        self.chains = chains
        self.accounts = accounts
        self.methods = methods
        self.events = events
    }

    static func accountsAreCompliant(_ accounts: [Account], toChains chains: [Blockchain]) -> Bool {
        for chain in chains {
            guard accounts.contains(where: { $0.blockchain == chain }) else {
                return false
            }
        }
        return true
    }
}

enum Namespace {

    static func validate(_ namespaces: [String: ProposalNamespace]) throws {
        for (key, namespace) in namespaces {
            let caip2Namespace = key.components(separatedBy: ":")
            
            if caip2Namespace.count > 1 {
                if let chain = caip2Namespace.last, !chain.isEmpty, namespace.chains != nil {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedChains)
                }
            } else {
                guard let chains = namespace.chains, !chains.isEmpty else {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedChains)
                }
                for chain in chains {
                    if key != chain.namespace {
                        throw WalletConnectError.unsupportedNamespace(.unsupportedChains)
                    }
                }
            }
        }
    }

    static func validate(_ namespaces: [String: SessionNamespace]) throws {
        for (key, namespace) in namespaces {
            if namespace.accounts.isEmpty {
                throw WalletConnectError.unsupportedNamespace(.unsupportedAccounts)
            }
            for account in namespace.accounts {
                if key.components(separatedBy: ":").count > 1 {
                    if key != account.namespace + ":\(account.reference)" {
                        throw WalletConnectError.unsupportedNamespace(.unsupportedAccounts)
                    }
                } else if key != account.namespace {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedAccounts)
                }
            }
        }
    }

    static func validateApproved(
        _ sessionNamespaces: [String: SessionNamespace],
        against proposalNamespaces: [String: ProposalNamespace]
    ) throws {
        var requiredNamespaces = [String: ProposalNamespace]()
        proposalNamespaces.forEach {
            let caip2Namespace = $0.key
            let proposalNamespace = $0.value

            if proposalNamespace.chains != nil {
                requiredNamespaces[caip2Namespace] = proposalNamespace
            } else {
                if let network = $0.key.components(separatedBy: ":").first {
                    let proposalNamespace = ProposalNamespace(chains: [Blockchain($0.key)!], methods: proposalNamespace.methods, events: proposalNamespace.events)
                    if requiredNamespaces[network] == nil {
                        requiredNamespaces[network] = proposalNamespace
                    } else {
                        let unionChains = requiredNamespaces[network]?.chains!.orderedUnion(proposalNamespace.chains ?? [])
                        let unionMethods = requiredNamespaces[network]?.methods.orderedUnion(proposalNamespace.methods)
                        let unionEvents = requiredNamespaces[network]?.events.orderedUnion(proposalNamespace.events)
                        
                        let namespace = ProposalNamespace(chains: unionChains, methods: unionMethods ?? [], events: unionEvents ?? [])
                        requiredNamespaces[network] = namespace
                    }
                }
            }
        }
        
        for (key, proposedNamespace) in requiredNamespaces {
            guard let approvedNamespace = sessionNamespaces[key] else {
                throw WalletConnectError.unsupportedNamespace(.unsupportedNamespaceKey)
            }
            try proposedNamespace.methods.forEach {
                if !approvedNamespace.methods.contains($0) {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedMethods)
                }
            }
            try proposedNamespace.events.forEach {
                if !approvedNamespace.events.contains($0) {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedEvents)
                }
            }
            if let chains = proposedNamespace.chains {
                try chains.forEach { chain in
                    if !approvedNamespace.accounts.contains(where: { $0.blockchain == chain }) {
                        throw WalletConnectError.unsupportedNamespace(.unsupportedAccounts)
                    }
                }
            } else {
                if !approvedNamespace.accounts.contains(where: { $0.blockchain == Blockchain(key) }) {
                    throw WalletConnectError.unsupportedNamespace(.unsupportedChains)
                }
            }
        }
    }
}

enum SessionProperties {
    static func validate(_ sessionProperties: [String: String]) throws {
        if sessionProperties.isEmpty {
            throw WalletConnectError.emptySessionProperties
        }
    }
}

public enum AutoNamespaces {
    
    /// For a wallet to build session proposal structure by provided supported chains, methods, events & accounts.
    /// - Parameters:
    ///   - proposalId: Session Proposal id
    ///   - namespaces: namespaces for given session, needs to contain at least required namespaces proposed by dApp.
    public static func build(
        sessionProposal: Session.Proposal,
        chains: [Blockchain],
        methods: [String],
        events: [String],
        accounts: [Account]
    ) throws -> [String: SessionNamespace] {
        var sessionNamespaces = [String: SessionNamespace]()
        
        let chainsSet = Set(chains)
        let methodsSet = Set(methods)
        let eventsSet = Set(events)
        
        try sessionProposal.requiredNamespaces.forEach {
            try extend(
                sessionNamespaces: &sessionNamespaces,
                with: $0.value,
                caip2Namespace: $0.key,
                isRequired: true,
                chains: chainsSet,
                methods: methodsSet,
                events: eventsSet,
                accounts: accounts
            )
        }
        
        try sessionProposal.optionalNamespaces?.forEach {
            try extend(
                sessionNamespaces: &sessionNamespaces,
                with: $0.value,
                caip2Namespace: $0.key,
                isRequired: false,
                chains: chainsSet,
                methods: methodsSet,
                events: eventsSet,
                accounts: accounts
            )
        }
        
        return sessionNamespaces
    }
    
    private static func extend(
        sessionNamespaces: inout [String: SessionNamespace],
        with proposalNamespace: ProposalNamespace,
        caip2Namespace: String,
        isRequired: Bool,
        chains: Set<Blockchain>,
        methods: Set<String>,
        events: Set<String>,
        accounts: [Account]
    ) throws {
        var pair: (key: String, proposal: ProposalNamespace)? = nil
        
        if proposalNamespace.chains != nil {
            pair = (caip2Namespace, proposalNamespace)
        }
        else {
            if let network = caip2Namespace.components(separatedBy: ":").first,
               let chain = caip2Namespace.components(separatedBy: ":").last,
               let blockchain = Blockchain(namespace: network, reference: chain) {
                let proposal = ProposalNamespace(
                    chains: [blockchain],
                    methods: proposalNamespace.methods,
                    events: proposalNamespace.events
                )
                pair = (network, proposal)
            }
        }
        
        guard
            let pair = pair,
            let sessionNamespace = try createSessionNamespace(
                for: pair.proposal,
                isRequired: isRequired,
                chains: chains,
                methods: methods,
                events: events,
                accounts: accounts
            )
        else {
            return
        }
        
        if var existingNamespace = sessionNamespaces[pair.key] {
            existingNamespace.chains = union(existingNamespace.chains, with: sessionNamespace.chains)
            existingNamespace.accounts = union(existingNamespace.accounts, with: sessionNamespace.accounts)
            existingNamespace.methods = union(existingNamespace.methods, with: sessionNamespace.methods)
            existingNamespace.events = union(existingNamespace.events, with: sessionNamespace.events)
            sessionNamespaces[pair.key] = existingNamespace
        } else {
            sessionNamespaces[pair.key] = sessionNamespace
        }
    }
    
    private static func createSessionNamespace(
        for proposalNamespace: ProposalNamespace,
        isRequired: Bool,
        chains: Set<Blockchain>,
        methods: Set<String>,
        events: Set<String>,
        accounts: [Account]
    ) throws -> SessionNamespace? {
        guard let proposalChains = proposalNamespace.chains else {
            fatalError("Invalid invariant")
        }
        
        let sessionChains = proposalChains.filter { chains.contains($0) }
        guard !sessionChains.isEmpty else {
            if isRequired {
                throw AutoNamespacesError.requiredChainsNotSatisfied
            }
            else {
                return nil
            }
        }
        
        let sessionMethods = proposalNamespace.methods.filter { methods.contains($0) }
        if isRequired {
            guard Set(proposalNamespace.methods).isSubset(of: methods) else {
                throw AutoNamespacesError.requiredMethodsNotSatisfied
            }
        }
        else {
            guard !sessionMethods.isEmpty else {
                return nil
            }
        }
        
        let sessionEvents = proposalNamespace.events.filter { events.contains($0) }
        if isRequired {
            guard Set(proposalNamespace.events).isSubset(of: events) else {
                throw AutoNamespacesError.requiredEventsNotSatisfied
            }
            
            let availableAccountsBlockchains = Set(accounts.map(\.blockchain))
            guard !Set(sessionChains).intersection(availableAccountsBlockchains).isEmpty else {
                throw AutoNamespacesError.requiredAccountsNotSatisfied
            }
        }
        
        let sessionAccounts = accounts.filter { sessionChains.contains($0.blockchain) }
        
        let sessionNamespace = SessionNamespace(
            chains: sessionChains,
            accounts: sessionAccounts,
            methods: sessionMethods,
            events: sessionEvents
        )
        
        return sessionNamespace
    }
    
    private static func union<T: Hashable>(_ existing: [T]?, with new: [T]?) -> [T] {
        existing?.orderedUnion(new ?? []) ?? new ?? []
    }
}

private extension Array where Element: Hashable {
    func orderedUnion(_ other: [Element]) -> [Element] {
        if isEmpty {
            return other
        }
        
        if other.isEmpty {
            return self
        }
        
        var unionArray: [Element] = []
        var existingElements = Set<Element>()
        
        for array in [self, other] {
            for element in array {
                if !existingElements.contains(element) {
                    unionArray.append(element)
                    existingElements.insert(element)
                }
            }
        }
        
        return unionArray
    }
}
