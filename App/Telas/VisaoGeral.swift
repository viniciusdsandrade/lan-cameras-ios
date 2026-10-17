import SwiftUI
import CamerasCore
import CamerasSessao

/// As câmeras lado a lado, cada uma com a lente móvel no fluxo leve. Tocar abre a câmera.
struct VisaoGeral: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @Environment(\.verticalSizeClass) private var vertical
    @Binding var mostrandoCameras: Bool
    @Binding var mostrandoAjuda: Bool

    var body: some View {
        ScrollView {
            LazyVGrid(columns: colunas, spacing: 12) {
                ForEach(modelo.cameras) { camera in
                    CartaoDaCamera(camera: camera, sessao: modelo.sessoesGerais[camera.id])
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable { modelo.reiniciarSessoes() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Câmeras")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { mostrandoAjuda = true } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("Ajuda")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive) { modelo.pararTodas() } label: { Image(systemName: "stop.circle") }
                    .accessibilityLabel("Parar o movimento de todas as câmeras")
                Button { mostrandoCameras = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Câmeras: procurar, renomear e ordenar")
            }
        }
    }

    /// Uma coluna em retrato; em paisagem, até três lado a lado.
    private var colunas: [GridItem] {
        let n = vertical == .compact ? min(3, max(1, modelo.cameras.count)) : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: n)
    }
}

/// O cartão é um botão que abre a câmera; o estado da conexão vai no valor de acessibilidade
/// (o VoiceOver diz "Abrir Câmera 1, ao vivo").
private struct CartaoDaCamera: View {
    @EnvironmentObject var modelo: ModeloDoApp
    let camera: CameraConfig
    let sessao: SessaoDeVideo?

    var body: some View {
        if let sessao {
            CartaoAoVivo(camera: camera, sessao: sessao) { modelo.selecionar(.camera(camera.id)) }
        } else {
            Button { modelo.selecionar(.camera(camera.id)) } label: {
                ZStack {
                    Color.black
                    Text("pausado").font(.callout).foregroundStyle(.white.opacity(0.7))
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    Text(camera.nome).font(.caption.weight(.medium)).foregroundStyle(.white)
                        .padding(.vertical, 4).padding(.horizontal, 9)
                        .background(.black.opacity(0.6), in: Capsule()).padding(8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir \(camera.nome)")
            .accessibilityValue("pausado")
        }
    }
}

private struct CartaoAoVivo: View {
    let camera: CameraConfig
    @ObservedObject var sessao: SessaoDeVideo
    let abrir: () -> Void
    @StateObject private var semZoom = EstadoDeZoom()

    var body: some View {
        Button(action: abrir) {
            LenteComRotulo(rotulo: camera.nome, distribuidor: sessao.distribuidor,
                           lente: camera.duasLentes ? .movel : .inteira, estado: sessao.estado, zoom: semZoom)
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrir \(camera.nome)")
        .accessibilityValue(sessao.estado.mensagem ?? "ao vivo")
    }
}
