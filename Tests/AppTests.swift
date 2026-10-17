import XCTest
@testable import CamerasDeCasa

/// O vencimento da assinatura (conta Apple gratuita: 7 dias) lido do perfil dentro do pacote.
final class AssinaturaTests: XCTestCase {
    /// Um perfil de mentira: bytes binários em volta de um plist, como o envelope CMS real.
    private func perfil(vencendo data: Date) throws -> Data {
        let plist: [String: Any] = ["ExpirationDate": data, "Name": "perfil de teste"]
        let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        return Data([0x30, 0x82, 0x0B, 0x9A, 0x06, 0x09, 0xFF, 0x00]) + xml + Data([0x00, 0xA0, 0x82, 0x03])
    }

    func testLeOVencimentoDentroDoEnvelope() throws {
        let vence = Date(timeIntervalSince1970: 1_900_000_000)
        let lido = try XCTUnwrap(Assinatura.vencimento(doPerfil: perfil(vencendo: vence)))
        XCTAssertEqual(lido.timeIntervalSince1970, vence.timeIntervalSince1970, accuracy: 1)
    }

    func testPerfilSemPlistNaoTemVencimento() {
        XCTAssertNil(Assinatura.vencimento(doPerfil: Data([0x30, 0x82, 0x00, 0x01])))
        XCTAssertNil(Assinatura.vencimento(doPerfil: Data("<?xml sem fim".utf8)))
    }

    func testDiasEAvisoPertoDoVencimento() {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let dia = 86_400.0
        XCTAssertEqual(Assinatura.diasRestantes(ate: agora.addingTimeInterval(6.5 * dia), agora: agora), 6)
        XCTAssertFalse(Assinatura.deveAvisar(agora: agora, vencimento: agora.addingTimeInterval(5 * dia)))
        XCTAssertTrue(Assinatura.deveAvisar(agora: agora, vencimento: agora.addingTimeInterval(2.5 * dia)))
        XCTAssertTrue(Assinatura.descricao(agora: agora, vencimento: agora.addingTimeInterval(0.5 * dia))!.contains("vence hoje"))
        XCTAssertTrue(Assinatura.descricao(agora: agora, vencimento: agora.addingTimeInterval(-dia))!.contains("venceu"))
        XCTAssertTrue(Assinatura.descricao(agora: agora, vencimento: agora.addingTimeInterval(6.5 * dia))!.contains("faltam 6 dias"))
    }

    func testSemPerfilNaoHaAvisoNemFrase() {
        XCTAssertNil(Assinatura.descricao(vencimento: nil))
        XCTAssertFalse(Assinatura.deveAvisar(vencimento: nil))
    }
}

/// O que vai no pacote do app: permissões com texto, nenhuma exceção de segurança de rede,
/// manifesto de privacidade.
final class ConfiguracaoTests: XCTestCase {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    func testPermissoesTemExplicacaoEmPortugues() {
        for chave in ["NSLocalNetworkUsageDescription", "NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"] {
            let texto = info[chave] as? String ?? ""
            XCTAssertGreaterThan(texto.count, 20, chave)
        }
    }

    func testNenhumaExcecaoDeSegurancaDeRede() {
        // RTSP, ONVIF e DVRIP usam soquetes do próprio app: o ATS não precisa (nem deve) ser afrouxado
        XCTAssertNil(info["NSAppTransportSecurity"])
    }

    func testPedeWiFiENaoRodaEmSegundoPlano() {
        XCTAssertEqual(info["UIRequiresPersistentWiFi"] as? Bool, true)
        XCTAssertNil(info["UIBackgroundModes"], "em segundo plano o app solta as câmeras; não há modo de fundo")
    }

    func testManifestoDePrivacidadeVaiNoPacote() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let dic = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(dic["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((dic["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
    }

    func testGiraParaPaisagemNoIPhone() {
        let orientacoes = info["UISupportedInterfaceOrientations"] as? [String] ?? []
        XCTAssertTrue(orientacoes.contains("UIInterfaceOrientationPortrait"))
        XCTAssertTrue(orientacoes.contains("UIInterfaceOrientationLandscapeLeft"))
        XCTAssertTrue(orientacoes.contains("UIInterfaceOrientationLandscapeRight"))
    }
}
