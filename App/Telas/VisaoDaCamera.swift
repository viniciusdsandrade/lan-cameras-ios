import SwiftUI
import CamerasCore
import CamerasSessao

/// Uma câmera aberta. Em pé, o vídeo fica fixo no topo e, embaixo dele, a fileira com o que se usa o
/// tempo todo (ouvir, falar, foto, luz) e os cartões dos controles, que rolam; deitado, o vídeo ocupa a
/// tela inteira e os controles essenciais flutuam por cima.
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
                    .background(Tema.fundo.ignoresSafeArea())
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
            LenteAoVivo(distribuidor: video.distribuidor, lente: sessao.camera.duasLentes ? .movel : .inteira,
                        estado: video.estado, zoom: sessao.zoom, zoomHabilitado: true, tentarAgora: { video.tentarAgora() })
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    if video.estado.aoVivo { SeloAoVivo() }
                }
                .overlay(alignment: .topTrailing) {
                    if sessao.camera.duasLentes, modelo.mostrarLenteFixa, video.estado.aoVivo { lenteFixa }
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BarraDaCamera(sessao: sessao, aoVivo: video.estado.aoVivo)
                    Controles(sessao: sessao)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Tema.fundo.ignoresSafeArea())
    }

    /// A lente fixa, menor, no canto de cima: mostra a cena inteira enquanto a móvel acompanha um ponto.
    private var lenteFixa: some View {
        GeometryReader { g in
            let largura = g.size.width * 0.32
            let forma = RoundedRectangle(cornerRadius: 8, style: .continuous)
            LenteAoVivo(distribuidor: video.distribuidor, lente: .fixa, estado: video.estado, zoom: semZoom, compacta: true)
                .frame(width: largura, height: largura * 9 / 16)
                .clipShape(forma)
                .overlay(forma.strokeBorder(.white.opacity(0.4)))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Lente fixa")
        }
    }
}

/// "● AO VIVO" no canto do vídeo.
private struct SeloAoVivo: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text("AO VIVO").font(.caption2.weight(.bold)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Tema.sobreVideo, in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// O que se usa o tempo todo, logo embaixo do vídeo, em botões redondos com o nome embaixo (como nos
/// controles de câmera do sistema): ouvir, falar (enquanto segura), foto, luz e a lente fixa.
private struct BarraDaCamera: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var sessao: SessaoDaCamera
    let aoVivo: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(sessao.ouvindo ? "Ouvindo" : "Ouvir") {
                Button { sessao.alternarOuvir() } label: {
                    Redondo(simbolo: sessao.ouvindo ? "speaker.wave.2.fill" : "speaker.slash.fill", aceso: sessao.ouvindo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sessao.ouvindo ? "Ouvindo" : "Ouvir")
                .accessibilityValue(sessao.ouvindo ? "ligado" : "desligado")
            }
            item(sessao.falandoAoVivo ? "Falando" : "Falar") {
                BotaoDePressao(descricao: "Segure para falar pela câmera", ativo: sessao.falandoAoVivo, corAtiva: .red,
                               aoPressionar: { sessao.iniciarFalaAoVivo() }, aoSoltar: { sessao.pararFalaAoVivo() }) { aceso in
                    Redondo(simbolo: aceso ? "mic.fill" : "mic", aceso: aceso, cor: .red)
                }
            }
            item("Foto") {
                Button { sessao.tirarFoto() } label: { Redondo(simbolo: "camera.fill") }
                    .buttonStyle(.plain)
                    .disabled(!aoVivo)
                    .accessibilityLabel("Tirar foto")
            }
            item("Luz") {
                Menu {
                    Picker("Luz branca", selection: Binding(
                        get: { sessao.luzPedida ?? sessao.estado?.luz },
                        set: { if let m = $0 { sessao.definirLuz(m) } }
                    )) {
                        Label("Automática", systemImage: "lightbulb.max").tag(ModoDaLuz?.some(.automatico))
                        Label("Ligada", systemImage: "lightbulb.fill").tag(ModoDaLuz?.some(.ligada))
                        Label("Desligada", systemImage: "lightbulb.slash").tag(ModoDaLuz?.some(.desligada))
                    }
                } label: {
                    Redondo(simbolo: iconeDaLuz, aceso: (sessao.luzPedida ?? sessao.estado?.luz) == .ligada, cor: .yellow)
                }
                .disabled(sessao.estado?.luz == nil || sessao.ocupadas.contains("luz"))
                .accessibilityLabel("Luz branca: \(SessaoDaCamera.nome(da: sessao.luzPedida ?? sessao.estado?.luz ?? .automatico))")
            }
            if sessao.camera.duasLentes {
                item("Lente fixa") {
                    Button { modelo.mostrarLenteFixa.toggle() } label: {
                        Redondo(simbolo: "pip", aceso: modelo.mostrarLenteFixa)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(modelo.mostrarLenteFixa ? "Esconder a lente fixa" : "Mostrar a lente fixa")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func item<Botao: View>(_ legenda: String, @ViewBuilder _ botao: () -> Botao) -> some View {
        VStack(spacing: 6) {
            botao()
            Text(legenda).font(.caption2).foregroundStyle(.secondary).lineLimit(1).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var iconeDaLuz: String {
        switch sessao.luzPedida ?? sessao.estado?.luz ?? .automatico {
        case .automatico: return "lightbulb.max"
        case .ligada: return "lightbulb.fill"
        case .desligada: return "lightbulb.slash"
        }
    }
}

/// Um botão redondo da fileira: aceso (som saindo, microfone aberto, luz ligada) ele se pinta inteiro.
private struct Redondo: View {
    let simbolo: String
    var aceso = false
    var cor: Color = .accentColor
    @Environment(\.isEnabled) private var habilitado

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(aceso ? (cor == .yellow ? Color.black : Color.white) : Color.primary)
            .frame(width: 56, height: 56)
            .background(Circle().fill(aceso ? cor : Tema.cartaoForte))
            .overlay(Circle().strokeBorder(Tema.borda))
            .opacity(habilitado ? 1 : 0.4)
            .contentShape(Circle())
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
            LenteAoVivo(distribuidor: video.distribuidor, lente: sessao.camera.duasLentes ? .movel : .inteira,
                        estado: video.estado, zoom: sessao.zoom, zoomHabilitado: true, aoTocar: alternarControles,
                        tentarAgora: { video.tentarAgora() })
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
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .fundoDeControles(Circle())
                }
                .accessibilityLabel("Voltar para todas as câmeras")
                HStack(spacing: 6) {
                    Circle().fill(video.estado.cor).frame(width: 8, height: 8)
                    Text(sessao.camera.nome).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if video.estado.aoVivo {
                        Text("AO VIVO").font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(.white.opacity(0.75))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .fundoDeControles(Capsule())
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
                        .disabled(!video.estado.aoVivo)
                }
            }
            Spacer()
            HStack(alignment: .bottom) {
                ControleDirecional(ativas: sessao.direcoesAtivas, segurar: { sessao.segurar($0) }, soltar: { sessao.soltar($0) },
                                   parar: { sessao.pararMovimento() }, diametro: 164, translucido: true)
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
            .fundoDeControles(Capsule())
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
