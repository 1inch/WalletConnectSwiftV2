import Foundation
import WalletConnectUtils

protocol CacaoFormatting {
    func format(_ request: AuthRequestParams, _ signature: CacaoSignature, _ didpkh: DIDPKH) -> AuthResponseParams
}

class CacaoFormatter: CacaoFormatting {
    func format(_ request: AuthRequestParams, _ signature: CacaoSignature, _ didpkh: DIDPKH) -> AuthResponseParams {
        let header = CacaoHeader(t: "eip4361")
        let payload = CacaoPayload(params: request.payloadParams, didpkh: didpkh)
        return AuthResponseParams(header: header, payload: payload, signature: signature)
    }
}
