import XCTest
import CoreGraphics
import ImageIO

/// Testes de ponta a ponta com câmeras de verdade, no simulador (que usa a rede do Mac).
/// Só rodam com CAMERAS_REAIS=1 (`TEST_RUNNER_CAMERAS_REAIS=1` no xcodebuild); no CI ficam pulados.
///
/// - `CAMERA_DE_TESTE`: posição (1, 2, 3…) na visão geral da câmera que pode ser mexida. O teste de
///   movimento guarda uma posição antes de mexer, volta a ela no fim e a apaga (o rastreio da câmera
///   não desfaz um movimento manual sozinho).
/// - Os testes leem e devolvem o estado que mudam (luz, rastreio, posições).
/// Nenhum nome de câmera aparece aqui: elas são "Câmera 1", "Câmera 2"… como o app as cadastra.
@MainActor
final class CamerasReaisUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAMERAS_REAIS"] == "1",
                          "precisa das câmeras de verdade: rode com TEST_RUNNER_CAMERAS_REAIS=1")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["CAMERAS_DEPURAR"] = "1"
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
    }

    private var indiceDeTeste: Int { Int(ProcessInfo.processInfo.environment["CAMERA_DE_TESTE"] ?? "") ?? 2 }

    private func guardar(_ nome: String) {
        let anexo = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    /// Espera o botão de uma câmera da visão geral ficar "ao vivo" (a primeira abertura procura as câmeras).
    @discardableResult
    private func esperarAoVivo(_ indice: Int, ate segundos: TimeInterval = 40) -> XCUIElement {
        let cartao = app.buttons["Abrir Câmera \(indice)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: segundos), "a Câmera \(indice) não apareceu na visão geral")
        let aoVivo = expectation(for: NSPredicate(format: "value == 'ao vivo'"), evaluatedWith: cartao)
        wait(for: [aoVivo], timeout: segundos)
        return cartao
    }

    private func abrirCameraDeTeste() {
        app.launch()
        esperarAoVivo(indiceDeTeste).tap()
        XCTAssertTrue(app.buttons["Mover para cima"].waitForExistence(timeout: 15), "a tela da câmera não abriu")
    }

    private var video: XCUIElement { app.images.matching(NSPredicate(format: "label BEGINSWITH 'Vídeo'")).firstMatch }

    // MARK: - Vídeo, lentes e orientação

    func testVisaoGeralMostraTodasAsCamerasAoVivo() {
        app.launch()
        for i in 1...3 { esperarAoVivo(i) }
        guardar("visao-geral-retrato")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        guardar("visao-geral-paisagem")
    }

    func testCameraEmRetratoEEmTelaCheiaDeitada() {
        abrirCameraDeTeste()
        sleep(3)
        guardar("camera-retrato")
        XCUIDevice.shared.orientation = .landscapeLeft
        let voltar = app.buttons["Voltar para todas as câmeras"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 5), "a tela cheia não mostrou os controles")
        guardar("camera-tela-cheia")
        // sem toque, os controles somem em 3 s; um toque no vídeo os traz de volta
        sleep(5)
        XCTAssertFalse(voltar.exists, "os controles deveriam ter sumido")
        guardar("camera-tela-cheia-sem-controles")
        video.tap()
        XCTAssertTrue(voltar.waitForExistence(timeout: 3))
        voltar.tap()
        XCTAssertTrue(app.buttons["Abrir Câmera 1"].waitForExistence(timeout: 10), "voltar deveria levar à visão geral")
    }

    func testZoomPorPincaEVoltaComToqueDuplo() {
        abrirCameraDeTeste()
        let v = video
        XCTAssertTrue(v.waitForExistence(timeout: 5))
        v.pinch(withScale: 3, velocity: 4)
        let comZoom = expectation(for: NSPredicate(format: "label CONTAINS 'zoom'"), evaluatedWith: v)
        wait(for: [comZoom], timeout: 5)
        guardar("zoom")
        v.doubleTap()
        let semZoom = expectation(for: NSPredicate(format: "label == 'Vídeo'"), evaluatedWith: v)
        wait(for: [semZoom], timeout: 5)
    }

    // MARK: - Movimento

    func testMovimentoParaAoSoltarMedidoNoVideo() throws {
        abrirCameraDeTeste()
        let marca = "Volta do teste"                                  // curto: a câmera corta nomes longos
        salvarPosicao(marca)                                           // para voltar exatamente aqui no fim
        sleep(3)                                                       // imagem estável antes de mexer
        let seta = app.buttons["Mover para esquerda"]
        trazerParaAVista(seta)
        XCTAssertEqual(seta.value as? String, "solto")
        let antes = try quadroDoVideo()
        defer { voltarEApagar(marca, conferindoCom: antes) }
        seta.press(forDuration: 1.5)
        let logoDepois = try quadroDoVideo()
        XCTAssertEqual(seta.value as? String, "solto", "ao soltar, o app deveria parar de mandar movimento")
        Thread.sleep(forTimeInterval: 1.0)
        let parado1 = try quadroDoVideo()
        Thread.sleep(forTimeInterval: 0.8)
        let parado2 = try quadroDoVideo()
        let mexeu = diferenca(antes, logoDepois)
        let depois = diferenca(parado1, parado2)
        let anexo = XCTAttachment(string: String(format: "diferença durante o movimento: %.2f; parado 1 s depois de soltar: %.2f", mexeu, depois))
        anexo.name = "medida-do-movimento"
        anexo.lifetime = .keepAlways
        add(anexo)
        XCTAssertGreaterThan(mexeu, depois * 3, "a imagem deveria mudar bem mais enquanto a câmera gira")
        XCTAssertLessThan(depois, 0.35, "1 s depois de soltar a imagem deveria estar parada")
    }

    private func salvarPosicao(_ nome: String) {
        let salvar = app.buttons["Salvar a posição atual"]
        XCTAssertTrue(salvar.waitForExistence(timeout: 10))
        salvar.tap()
        let campo = app.alerts.textFields.firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.typeText(nome)
        app.alerts.buttons["Salvar"].tap()
        XCTAssertTrue(botao("Ir para a posição \(nome)").waitForExistence(timeout: 20), "a posição de volta não foi salva")
    }

    /// Pelo começo do rótulo: a câmera pode cortar o nome da posição.
    private func botao(_ comeco: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", comeco)).firstMatch
    }

    /// Leva a câmera de volta à posição guardada no começo e a apaga.
    /// Leva a câmera de volta à posição guardada no começo, confere pela imagem que ela chegou e só
    /// então apaga a posição.
    private func voltarEApagar(_ nome: String, conferindoCom referencia: [UInt8]) {
        let ir = botao("Ir para a posição \(nome)")
        guard ir.waitForExistence(timeout: 10) else { return XCTFail("não achei a posição de volta: devolva a câmera à mão") }
        trazerParaAVista(ir)
        ir.tap()
        let voltou = esperarLeitura(ate: 25) { () -> Bool? in
            guard let q = try? quadroDoVideo() else { return nil }
            return diferenca(referencia, q) < 0.3 ? true : nil
        }
        XCTAssertEqual(voltou, true, "a câmera não voltou à posição de antes do teste: confira e devolva à mão")
        apagarPosicao(comecando: nome)
    }

    private func apagarPosicao(comecando nome: String) {
        let apagar = botao("Apagar a posição \(nome)")
        guard apagar.waitForExistence(timeout: 10) else { return }
        apagar.tap()
        let confirmar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Apagar \"\(nome)")).firstMatch
        if confirmar.waitForExistence(timeout: 5) { confirmar.tap() }
        _ = esperarLeitura(ate: 20) { apagar.exists ? nil : true }
    }

    /// Se um teste cair no meio, a posição que ele criou fica na câmera: este apaga as que sobraram.
    func testZZApagaPosicoesDeTesteQueSobraram() {
        abrirCameraDeTeste()
        XCTAssertTrue(app.buttons["Salvar a posição atual"].waitForExistence(timeout: 10))
        sleep(2)
        for nome in ["Antes do teste", "Volta do teste", "Teste do iPhone"] {
            while botao("Apagar a posição \(nome)").exists { apagarPosicao(comecando: nome) }
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Apagar a posição Antes do teste' OR label BEGINSWITH 'Apagar a posição Volta do teste'")).firstMatch.exists)
    }

    /// O vídeo da tela, reduzido a 64 x 36 tons de cinza (ruído e compressão somem; movimento não).
    private func quadroDoVideo() throws -> [UInt8] {
        let v = video
        let tela = XCUIScreen.main.screenshot()
        let img = try XCTUnwrap(CGImageSourceCreateWithData(tela.pngRepresentation as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        let escala = CGFloat(img.width) / app.frame.width
        let r = v.frame
        let recorte = try XCTUnwrap(img.cropping(to: CGRect(x: r.minX * escala, y: r.minY * escala, width: r.width * escala, height: r.height * escala)))
        var px = [UInt8](repeating: 0, count: 64 * 36)
        let ctx = try XCTUnwrap(CGContext(data: &px, width: 64, height: 36, bitsPerComponent: 8, bytesPerRow: 64,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.interpolationQuality = .medium
        ctx.draw(recorte, in: CGRect(x: 0, y: 0, width: 64, height: 36))
        return px
    }

    /// Diferença média entre dois quadros em desvios-padrão: cada quadro é normalizado pela sua
    /// média e espalhamento, para a exposição automática (que muda o brilho ao girar) não contar.
    private func diferenca(_ a: [UInt8], _ b: [UInt8]) -> Double {
        func normalizado(_ q: [UInt8]) -> [Double] {
            let v = q.map(Double.init)
            let media = v.reduce(0, +) / Double(v.count)
            let desvio = max(1, (v.reduce(0) { $0 + ($1 - media) * ($1 - media) } / Double(v.count)).squareRoot())
            return v.map { ($0 - media) / desvio }
        }
        let x = normalizado(a), y = normalizado(b)
        return zip(x, y).reduce(0) { $0 + abs($1.0 - $1.1) } / Double(x.count)
    }

    // MARK: - Posições, luz e rastreio (cada um devolve o que mudou)

    func testPosicaoSalvaPeloAppPodeSerApagadaEAsDaCameraNao() {
        abrirCameraDeTeste()
        let salvar = app.buttons["Salvar a posição atual"]
        XCTAssertTrue(salvar.waitForExistence(timeout: 10))
        let apagaveisAntes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Apagar a posição'")).count
        salvar.tap()
        let campo = app.alerts.textFields.firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.typeText("Teste do iPhone")
        app.alerts.buttons["Salvar"].tap()
        let apagar = app.buttons["Apagar a posição Teste do iPhone"]
        XCTAssertTrue(apagar.waitForExistence(timeout: 20), "a posição nova deveria aparecer com a lixeira")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Apagar a posição'")).count, apagaveisAntes + 1,
                       "só a posição criada pelo app ganha lixeira")
        guardar("posicao-salva")
        apagar.tap()
        let confirmar = app.buttons["Apagar \"Teste do iPhone\""]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5))
        confirmar.tap()
        let sumiu = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: apagar)
        wait(for: [sumiu], timeout: 20)
    }

    func testLuzMudaEVoltaAoQueEra() {
        abrirCameraDeTeste()
        let opcoes = ["Automática", "Ligada", "Desligada"]
        let original = esperarLeitura { opcoes.first { app.buttons[$0].isSelected } }
        XCTAssertNotNil(original, "a luz não foi lida")
        guard let original else { return }
        // o modo automático só acende com movimento à noite: é a troca que menos incomoda
        let outro = original == "Automática" ? "Desligada" : "Automática"
        app.buttons[outro].tap()
        XCTAssertEqual(esperarLeitura(ate: 20) { app.buttons[outro].isSelected && app.buttons[outro].isEnabled ? outro : nil }, outro)
        app.buttons[original].tap()
        XCTAssertEqual(esperarLeitura(ate: 20) { app.buttons[original].isSelected && app.buttons[original].isEnabled ? original : nil }, original,
                       "a luz deveria voltar ao modo original")
    }

    func testRastreioDesligaELigaDeVolta() {
        abrirCameraDeTeste()
        let chave = app.switches["Rastreio automático"]
        XCTAssertTrue(chave.waitForExistence(timeout: 10))
        let original = esperarLeitura { chave.isEnabled ? (chave.value as? String) : nil }
        XCTAssertNotNil(original)
        guard let original else { return }
        alternar(chave)
        XCTAssertEqual(esperarLeitura(ate: 20) { chave.isEnabled && (chave.value as? String) != original ? "mudou" : nil }, "mudou")
        alternar(chave)
        XCTAssertEqual(esperarLeitura(ate: 20) { chave.isEnabled && (chave.value as? String) == original ? "voltou" : nil }, "voltou",
                       "o rastreio deveria voltar ao que era")
        sleep(6)                                                       // volta ao ponto de vigia, se tiver saído
    }

    func testFotoVaiParaOAppFotos() {
        abrirCameraDeTeste()
        sleep(3)
        let foto = app.buttons["Tirar foto"]
        XCTAssertTrue(foto.waitForExistence(timeout: 5))
        foto.tap()
        // o aviso dura poucos segundos: procura por ele enquanto atende o pedido de permissão do
        // Fotos (só aparece na primeira foto), no mesmo laço
        let sistema = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permitir = sistema.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Permitir' OR label BEGINSWITH 'Allow'")).firstMatch
        let aviso = app.descendants(matching: .any).matching(identifier: "aviso").firstMatch
        let texto = esperarLeitura(ate: 15) { () -> String? in
            if permitir.exists { permitir.tap() }
            guard aviso.exists else { return nil }
            let l = aviso.label
            return l.hasPrefix("Foto salva") || l.hasPrefix("Não consegui") ? l : nil
        }
        XCTAssertEqual(texto, "Foto salva em Fotos")
    }

    // MARK: - Som na câmera (só com CAMERAS_SOM=1: quem estiver perto da câmera ouve)

    private func exigirSom() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAMERAS_SOM"] == "1",
                          "toca som na câmera: rode com TEST_RUNNER_CAMERAS_SOM=1 e volume baixo")
    }

    /// Volume no mínimo (5%): o alto-falante da câmera é alto.
    private func volumeMinimo() {
        let volume = app.sliders["Volume na câmera"]
        XCTAssertTrue(volume.waitForExistence(timeout: 10))
        // o adjust não rola a tela: com o controle fora da vista ele não muda nada (e o som sairia a 30%)
        trazerParaAVista(volume)
        volume.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(app.staticTexts["5%"].waitForExistence(timeout: 3), "o volume deveria estar no mínimo (5%) antes de tocar")
    }

    func testBipEmVolumeBaixoTocaNaCamera() throws {
        try exigirSom()
        abrirCameraDeTeste()
        volumeMinimo()
        let bip = app.buttons["Bip"]
        XCTAssertTrue(bip.waitForExistence(timeout: 5))
        bip.tap()
        XCTAssertEqual(esperarAviso(ate: 20) { $0.contains("tocando") || $0.contains("não") || $0.contains("Não") },
                       "Bip tocando em Câmera \(indiceDeTeste)", "a câmera deveria aceitar o som")
    }

    func testTextoFaladoNaCamera() throws {
        try exigirSom()
        abrirCameraDeTeste()
        volumeMinimo()
        let campo = app.textFields["O que a câmera deve falar"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        campo.typeText("Teste do aplicativo")
        app.buttons["Falar"].tap()
        XCTAssertEqual(esperarAviso(ate: 30) { $0.hasPrefix("Falando") || $0.contains("não") || $0.contains("Não") },
                       "Falando em Câmera \(indiceDeTeste)", "a câmera deveria falar o texto")
    }

    func testFalarSegurandoSilenciaOOuvirEDepoisVolta() throws {
        try exigirSom()
        abrirCameraDeTeste()
        volumeMinimo()
        let ouvir = app.buttons["Ouvir"]
        XCTAssertTrue(ouvir.waitForExistence(timeout: 5))
        ouvir.tap()
        XCTAssertTrue(app.buttons["Ouvindo"].waitForExistence(timeout: 5), "o som da câmera deveria ligar")
        let falar = app.buttons["Segure para falar pela câmera"]
        falar.press(forDuration: 3)
        // ao soltar, a fala para e o som da câmera volta sozinho
        XCTAssertEqual(esperarLeitura(ate: 10) { falar.value as? String == "solto" && app.buttons["Ouvindo"].exists ? "voltou" : nil }, "voltou",
                       "depois de falar, o som da câmera deveria voltar")
        app.buttons["Ouvindo"].tap()
    }

    /// Um toque no meio de um Toggle do SwiftUI cai no rótulo e não alterna: toca na chave, à direita.
    private func alternar(_ chave: XCUIElement) {
        // o Toggle tem por dentro a chave de verdade, sem rótulo; o tap() nela rola a tela até ela
        let interna = chave.switches.firstMatch
        if interna.exists {
            interna.tap()
        } else {
            trazerParaAVista(chave)
            chave.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
    }

    /// Rola até o elemento caber inteiro na janela (o isHittable diz sim também fora da vista, dentro
    /// de uma rolagem; e adjust e toques por coordenada não rolam sozinhos).
    private func trazerParaAVista(_ e: XCUIElement) {
        let janela = app.windows.firstMatch.frame
        // arrasta pela margem esquerda, abaixo do vídeo: no meio da tela ficam as setas de movimento,
        // que reagem ao primeiro toque (um swipe ali mexeria a câmera em vez de rolar)
        let embaixo = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.85))
        let emcima = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.45))
        for _ in 0..<10 where !janela.insetBy(dx: 0, dy: 60).contains(e.frame) {
            if e.frame.minY > janela.midY { embaixo.press(forDuration: 0.05, thenDragTo: emcima) }
            else { emcima.press(forDuration: 0.05, thenDragTo: embaixo) }
        }
    }

    /// O texto do primeiro aviso que passar pelo filtro (os avisos somem sozinhos em alguns segundos).
    private func esperarAviso(ate segundos: TimeInterval = 15, _ filtro: (String) -> Bool) -> String? {
        let aviso = app.descendants(matching: .any).matching(identifier: "aviso").firstMatch
        return esperarLeitura(ate: segundos) { aviso.exists && filtro(aviso.label) ? aviso.label : nil }
    }

    /// Repete a leitura até ela devolver algo (a câmera responde em alguns segundos).
    private func esperarLeitura<T>(ate segundos: TimeInterval = 20, _ ler: () -> T?) -> T? {
        let limite = Date().addingTimeInterval(segundos)
        while Date() < limite {
            if let v = ler() { return v }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }
}
