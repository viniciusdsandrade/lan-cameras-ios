import SwiftUI
import Combine
import CamerasCore
import CamerasSessao

/// Todas as câmeras ao vivo, cada uma com a lente móvel no fluxo leve. Em pé, uma embaixo da outra (ou
/// numa grade de duas colunas, que cabe mais na tela); deitado, num mosaico que cabe na tela sem rolar.
/// O nome e o estado ficam embaixo de cada vídeo (o alto fica livre para a data que a câmera escreve na
/// imagem). Tocar abre a câmera.
struct VisaoGeral: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @Environment(\.verticalSizeClass) private var vertical
    @Binding var mostrandoCameras: Bool
    @Binding var mostrandoAjuda: Bool
    @AppStorage("gradeNaVisaoGeral") private var emGrade = false
    @StateObject private var resumo = ResumoDoMosaico()

    private var deitado: Bool { vertical == .compact }

    var body: some View {
        Group {
            if deitado {
                Mosaico(espaco: 8) { quadros(compactos: true) }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(resumo.texto(cameras: modelo.cameras.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: colunas, spacing: emGrade ? 8 : 12) { quadros(compactos: emGrade) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .refreshable { modelo.reiniciarSessoes() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.fundo.ignoresSafeArea())
        .navigationTitle("Câmeras")
        .onAppear { resumo.acompanhar(Array(modelo.sessoesGerais.values)) }
        .onChange(of: Set(modelo.sessoesGerais.values.map(ObjectIdentifier.init))) { _, _ in
            resumo.acompanhar(Array(modelo.sessoesGerais.values))
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { mostrandoAjuda = true } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("Ajuda")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !deitado {
                    Button { emGrade.toggle() } label: { Image(systemName: emGrade ? "rectangle.grid.1x2" : "square.grid.2x2") }
                        .accessibilityLabel(emGrade ? "Mostrar uma câmera por linha" : "Mostrar em grade")
                }
                Button { modelo.selecionar(.gravacoes) } label: { Image(systemName: "film.stack") }
                    .accessibilityLabel("Gravações")
                Menu {
                    Button(role: .destructive) { modelo.pararTodas() } label: {
                        Label("Parar o movimento de todas", systemImage: "hand.raised")
                    }
                    Button { mostrandoCameras = true } label: {
                        Label("Câmeras: procurar, renomear e ordenar", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mais")
            }
        }
    }

    private func quadros(compactos: Bool) -> some View {
        ForEach(modelo.cameras) { camera in
            QuadroDaCamera(camera: camera, sessao: modelo.sessoesGerais[camera.id], compacto: compactos)
        }
    }

    private var colunas: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: emGrade ? 2 : 1)
    }
}

/// Quantas câmeras estão sem imagem ou conectando, para o resumo em cima ("4 câmeras · 1 sem imagem"):
/// dá para ver de relance que alguma caiu.
@MainActor
final class ResumoDoMosaico: ObservableObject {
    @Published private var estados: [String: FluxoDeVideo.Estado] = [:]
    private var assinaturas: [AnyCancellable] = []

    func acompanhar(_ sessoes: [SessaoDeVideo]) {
        estados = Dictionary(sessoes.map { ($0.camera.id, $0.estado) }, uniquingKeysWith: { a, _ in a })
        assinaturas = sessoes.map { s in
            let id = s.camera.id
            return s.$estado.sink { [weak self] novo in self?.estados[id] = novo }
        }
    }

    func texto(cameras: Int) -> String {
        var partes = [cameras == 1 ? "1 câmera" : "\(cameras) câmeras"]
        let semImagem = estados.values.filter { if case .erro = $0 { return true } else { return false } }.count
        let conectando = estados.values.filter { $0 == .conectando }.count
        if semImagem > 0 { partes.append("\(semImagem) sem imagem") }
        if conectando > 0 { partes.append("\(conectando) conectando") }
        return partes.joined(separator: " · ")
    }
}

/// Uma câmera na visão geral: um botão que a abre. Sem sessão (o app solta as câmeras em segundo plano),
/// um quadro "pausado". O estado da conexão vai no valor de acessibilidade ("Abrir Câmera 1, ao vivo").
private struct QuadroDaCamera: View {
    @EnvironmentObject var modelo: ModeloDoApp
    let camera: CameraConfig
    let sessao: SessaoDeVideo?
    let compacto: Bool

    var body: some View {
        if let sessao {
            QuadroAoVivo(camera: camera, sessao: sessao, compacto: compacto) { modelo.selecionar(.camera(camera.id)) }
        } else {
            Button { modelo.selecionar(.camera(camera.id)) } label: {
                ZStack {
                    Color.black
                    Label("pausado", systemImage: "pause.circle").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .bottom) { FaixaDoNome(nome: camera.nome, cor: .gray, compacta: compacto) }
                .clipShape(RoundedRectangle(cornerRadius: Tema.raioDoVideo, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir \(camera.nome)")
            .accessibilityValue("pausado")
        }
    }
}

private struct QuadroAoVivo: View {
    let camera: CameraConfig
    @ObservedObject var sessao: SessaoDeVideo
    let compacto: Bool
    let abrir: () -> Void
    @StateObject private var semZoom = EstadoDeZoom()

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: Tema.raioDoVideo, style: .continuous)
        Button(action: abrir) {
            LenteAoVivo(distribuidor: sessao.distribuidor, lente: camera.duasLentes ? .movel : .inteira,
                        estado: sessao.estado, zoom: semZoom, compacta: true, tentarAgora: { sessao.tentarAgora() })
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .bottom) { FaixaDoNome(nome: camera.nome, cor: sessao.estado.cor, compacta: compacto) }
                .clipShape(forma)
                .overlay(forma.strokeBorder(Tema.borda))
                .contentShape(forma)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Abrir \(camera.nome)")
        .accessibilityValue(sessao.estado.mensagem ?? "ao vivo")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Tentar agora") { sessao.tentarAgora() }
    }
}

/// O nome e o estado numa faixa escura embaixo do vídeo, legível sobre qualquer imagem.
private struct FaixaDoNome: View {
    let nome: String
    let cor: Color
    let compacta: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(cor).frame(width: 8, height: 8)
            Text(nome).font((compacta ? Font.caption : .subheadline).weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .sobreOVideo()
        .padding(.horizontal, compacta ? 8 : 12)
        .padding(.top, compacta ? 16 : 24)
        .padding(.bottom, compacta ? 6 : 9)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}
