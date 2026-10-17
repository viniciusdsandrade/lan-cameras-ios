import SwiftUI
import CamerasCore
import CamerasSessao

/// Uma câmera aberta. Em retrato, o vídeo fica fixo no topo e os controles rolam embaixo; em
/// paisagem, o vídeo ocupa a tela inteira e os controles essenciais ficam por cima.
struct VisaoDaCamera: View {
    let idDaCamera: String
    @EnvironmentObject var modelo: ModeloDoApp
    @Environment(\.verticalSizeClass) private var vertical
    @State private var renomeando = false
    @State private var novoNome = ""

    private var paisagem: Bool { vertical == .compact }

    var body: some View {
        Group {
            if let sessao = modelo.sessaoDaCamera, sessao.camera.id == idDaCamera {
                if paisagem {
                    TelaCheiaDaCamera(sessao: sessao)
                } else {
                    RetratoDaCamera(sessao: sessao)
                }
            } else {
                ProgressView("Abrindo a câmera…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(modelo.camera(id: idDaCamera)?.nome ?? "Câmera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(paisagem ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(paisagem)
        .persistentSystemOverlays(paisagem ? .hidden : .automatic)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    novoNome = modelo.camera(id: idDaCamera)?.nome ?? ""
                    renomeando = true
                } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Renomear a câmera")
            }
        }
        .alert("Renomear a câmera", isPresented: $renomeando) {
            TextField("Nome", text: $novoNome)
            Button("Salvar") { if let c = modelo.camera(id: idDaCamera) { modelo.renomear(c, para: novoNome) } }
            Button("Cancelar", role: .cancel) {}
        }
        // a tela não apaga enquanto alguém está olhando uma câmera
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

// MARK: - Retrato

private struct RetratoDaCamera: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var sessao: SessaoDaCamera
    @ObservedObject private var video: SessaoDeVideo
    @StateObject private var semZoom = EstadoDeZoom()

    init(sessao: SessaoDaCamera) {
        self.sessao = sessao
        self.video = sessao.video
    }

    var body: some View {
        VStack(spacing: 0) {
            LenteComRotulo(rotulo: sessao.camera.duasLentes ? "Lente móvel" : sessao.camera.nome,
                           distribuidor: video.distribuidor, lente: sessao.camera.duasLentes ? .movel : .inteira,
                           estado: video.estado, zoom: sessao.zoom, zoomHabilitado: true, cantos: 0)
                .overlay(alignment: .topTrailing) { informacoes }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if sessao.camera.duasLentes, modelo.mostrarLenteFixa {
                        LenteComRotulo(rotulo: "Lente fixa", distribuidor: video.distribuidor, lente: .fixa,
                                       estado: video.estado, zoom: semZoom)
                    }
                    Controles(sessao: sessao)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder private var informacoes: some View {
        if let sinal = sessao.estado?.sinalDoWiFi {
            Label("\(sinal)%", systemImage: "wifi")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(8)
                .accessibilityLabel("Wi-Fi da câmera: \(sinal) de 100")
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Paisagem (tela cheia)

private struct TelaCheiaDaCamera: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var sessao: SessaoDaCamera
    @ObservedObject private var video: SessaoDeVideo
    @ObservedObject private var zoom: EstadoDeZoom
    @State private var controlesVisiveis = true
    @State private var ocultar: Task<Void, Never>?

    init(sessao: SessaoDaCamera) {
        self.sessao = sessao
        self.video = sessao.video
        self.zoom = sessao.zoom
    }

    /// Nada some enquanto a câmera se mexe ou fala: o dedo está num botão.
    private var emUso: Bool { !sessao.direcoesAtivas.isEmpty || sessao.falandoAoVivo }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LenteComRotulo(rotulo: sessao.camera.nome, distribuidor: video.distribuidor,
                           lente: sessao.camera.duasLentes ? .movel : .inteira, estado: video.estado,
                           zoom: sessao.zoom, zoomHabilitado: true, cantos: 0, aoTocar: alternarControles, mostrarRotulo: false)
                .ignoresSafeArea()
            if controlesVisiveis {
                sobreposicao
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controlesVisiveis)
        .onAppear { agendarOcultar() }
        .onDisappear { ocultar?.cancel() }
        .onChange(of: emUso) { _, usando in if !usando { agendarOcultar() } }
    }

    private var sobreposicao: some View {
        VStack {
            HStack(alignment: .top) {
                Button { modelo.selecionar(.geral) } label: {
                    Image(systemName: "chevron.backward")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Voltar para todas as câmeras")
                HStack(spacing: 6) {
                    Circle().fill(video.estado.cor).frame(width: 8, height: 8)
                    Text(sessao.camera.nome).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(sessao.camera.nome), \(video.estado.mensagem ?? "ao vivo")")
                Spacer()
                HStack(spacing: 10) {
                    botaoRedondo(modelo.qualidadeHD ? "HD" : "Leve", simbolo: nil, rotulo: "Qualidade: \(modelo.qualidadeHD ? "HD" : "leve")") {
                        modelo.qualidadeHD.toggle()
                        modelo.recomecarSessaoDaCamera()
                    }
                    botaoRedondo(nil, simbolo: iconeDaLuz, rotulo: "Luz: \(SessaoDaCamera.nome(da: sessao.luzPedida ?? sessao.estado?.luz ?? .automatico))") {
                        sessao.definirLuz(proximaLuz)
                    }
                    .disabled(sessao.estado?.luz == nil || sessao.ocupadas.contains("luz"))
                    botaoRedondo(nil, simbolo: sessao.ouvindo ? "speaker.wave.2.fill" : "speaker.slash", rotulo: sessao.ouvindo ? "Parar de ouvir" : "Ouvir") {
                        sessao.alternarOuvir()
                    }
                    botaoRedondo(nil, simbolo: "camera.fill", rotulo: "Tirar foto") { sessao.tirarFoto() }
                }
            }
            Spacer()
            HStack(alignment: .bottom) {
                ControleDeMovimento(sessao: sessao, lado: 56, fundoTranslucido: true)
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        botaoRedondo(nil, simbolo: "minus.magnifyingglass", rotulo: "Diminuir o zoom") { zoom.definir(zoom.zoom / 1.25) }
                        botaoRedondo(String(format: "%.1f×", zoom.zoom), simbolo: nil, rotulo: "Voltar o zoom ao normal") { zoom.reiniciar() }
                        botaoRedondo(nil, simbolo: "plus.magnifyingglass", rotulo: "Aumentar o zoom") { zoom.definir(zoom.zoom * 1.25) }
                    }
                    BotaoDeFalar(sessao: sessao, compacto: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .simultaneousGesture(TapGesture().onEnded { agendarOcultar() })
    }

    private func botaoRedondo(_ texto: String?, simbolo: String?, rotulo: String, acao: @escaping () -> Void) -> some View {
        Button {
            acao()
            agendarOcultar()
        } label: {
            Group {
                if let simbolo { Image(systemName: simbolo).font(.body.weight(.semibold)) }
                else { Text(texto ?? "").font(.footnote.weight(.bold).monospacedDigit()) }
            }
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, texto == nil ? 0 : 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel(rotulo)
    }

    private var iconeDaLuz: String {
        switch sessao.luzPedida ?? sessao.estado?.luz ?? .automatico {
        case .automatico: return "lightbulb.max"
        case .ligada: return "lightbulb.fill"
        case .desligada: return "lightbulb.slash"
        }
    }

    private var proximaLuz: ModoDaLuz {
        switch sessao.luzPedida ?? sessao.estado?.luz ?? .automatico {
        case .automatico: return .ligada
        case .ligada: return .desligada
        case .desligada: return .automatico
        }
    }

    private func alternarControles() {
        if controlesVisiveis, !emUso {
            ocultar?.cancel()
            controlesVisiveis = false
        } else {
            controlesVisiveis = true
            agendarOcultar()
        }
    }

    /// Esconde os controles depois de 3 s sem toque (nunca com um botão apertado).
    private func agendarOcultar() {
        ocultar?.cancel()
        ocultar = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if !emUso { controlesVisiveis = false }
        }
    }
}
