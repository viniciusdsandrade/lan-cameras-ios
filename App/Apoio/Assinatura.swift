import Foundation

/// Quando a assinatura do app vence. Instalado pelo Xcode com uma conta Apple gratuita, o app
/// para de abrir depois de 7 dias; a data está no perfil de provisionamento dentro do pacote.
/// No simulador não há perfil.
enum Assinatura {
    /// O perfil é um plist dentro de uma assinatura CMS; o plist em si vai em texto.
    static func vencimento(doPerfil dados: Data) -> Date? {
        guard let inicio = dados.range(of: Data("<?xml".utf8)),
              let fim = dados.range(of: Data("</plist>".utf8), in: inicio.lowerBound..<dados.endIndex) else { return nil }
        let plist = dados[inicio.lowerBound..<fim.upperBound]
        guard let dic = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any] else { return nil }
        return dic["ExpirationDate"] as? Date
    }

    static var vencimentoDesteApp: Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let dados = try? Data(contentsOf: url) else { return nil }
        return vencimento(doPerfil: dados)
    }

    /// Dias inteiros que faltam (0 no último dia; negativo se já venceu).
    static func diasRestantes(ate vencimento: Date, agora: Date = Date()) -> Int {
        Int((vencimento.timeIntervalSince(agora) / 86_400).rounded(.down))
    }

    /// Frase para a ajuda, ou nil fora de um iPhone com perfil.
    static func descricao(agora: Date = Date(), vencimento: Date? = vencimentoDesteApp) -> String? {
        guard let vencimento else { return nil }
        let dias = diasRestantes(ate: vencimento, agora: agora)
        let quando = vencimento.formatted(date: .abbreviated, time: .shortened)
        switch dias {
        case ..<0: return "A assinatura do app venceu em \(quando). Instale de novo pelo Mac."
        case 0: return "A assinatura do app vence hoje (\(quando)). Instale de novo pelo Mac."
        case 1: return "A assinatura do app vence amanhã (\(quando)). Instale de novo pelo Mac."
        default: return "A assinatura do app vale até \(quando) (faltam \(dias) dias)."
        }
    }

    /// Avisar na abertura a partir de 2 dias do vencimento.
    static func deveAvisar(agora: Date = Date(), vencimento: Date? = vencimentoDesteApp) -> Bool {
        guard let vencimento else { return false }
        return diasRestantes(ate: vencimento, agora: agora) <= 2
    }
}
