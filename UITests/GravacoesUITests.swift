import XCTest

/// A tela de gravações com as câmeras de mentira do repositório do Mac (`scripts/camera-falsa.py`):
/// sem câmera de verdade e sem a imagem de nenhuma casa. Só roda com CAMERAS_FALSAS apontando para a
/// pasta do cadastro delas (`TEST_RUNNER_CAMERAS_FALSAS=PASTA` no xcodebuild); no CI fica pulado.
@MainActor
final class GravacoesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        let pasta = ProcessInfo.processInfo.environment["CAMERAS_FALSAS"] ?? ""
        try XCTSkipIf(pasta.isEmpty, "precisa das câmeras falsas: rode scripts/camera-falsa.py e TEST_RUNNER_CAMERAS_FALSAS=PASTA")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["CAMERAS_PASTA"] = pasta
        app.launchArguments = ["--abrir", "gravacoes"]
    }

    override func tearDown() async throws {
        app?.terminate()
    }

    private func guardar(_ nome: String) {
        let anexo = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    func testGaleriaMovimentoEVideoDoCartao() {
        app.launch()
        // os cartões dizem câmera, hora e duração ("Câmera 1, 04:33:49, 4 s"); o filtro é "Câmera e período"
        let movimento = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Câmera ' AND label CONTAINS ', '")).firstMatch
        XCTAssertTrue(movimento.waitForExistence(timeout: 20), "nenhum movimento apareceu nas gravações")
        sleep(2)                                                  // as fotos chegam depois da lista
        guardar("gravacoes-galeria")

        movimento.tap()
        let assistir = app.buttons["Assistir"]
        XCTAssertTrue(assistir.waitForExistence(timeout: 10), "o movimento não abriu em tela cheia")
        guardar("gravacoes-movimento")

        assistir.tap()
        XCTAssertTrue(app.buttons["Compartilhar ou salvar o vídeo"].waitForExistence(timeout: 30), "o vídeo não veio do cartão")
        sleep(1)
        guardar("gravacoes-video")

        app.buttons["Anterior"].tap()
        XCTAssertTrue(assistir.waitForExistence(timeout: 5), "o movimento anterior começa pela foto")
        guardar("gravacoes-anterior")

        app.buttons["Fechar"].tap()
        XCTAssertTrue(movimento.waitForExistence(timeout: 5), "fechar volta para a galeria")
    }
}
