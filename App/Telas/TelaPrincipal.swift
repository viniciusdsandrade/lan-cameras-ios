import SwiftUI
import CamerasCore
import CamerasSessao

/// A raiz do app: o cadastro enquanto não há câmeras; depois, a visão geral com a câmera aberta
/// por cima (a pilha de navegação segue a seleção do modelo, que decide quais sessões ficam abertas).
struct TelaPrincipal: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @State private var mostrandoCameras = false
    @State private var mostrandoAjuda = false

    var body: some View {
        Group {
            if modelo.cameras.isEmpty {
                NavigationStack { TelaDeCadastro() }
            } else {
                NavigationStack(path: caminho) {
                    VisaoGeral(mostrandoCameras: $mostrandoCameras, mostrandoAjuda: $mostrandoAjuda)
                        .navigationDestination(for: String.self) { id in VisaoDaCamera(idDaCamera: id) }
                }
            }
        }
        .overlay(alignment: .bottom) { AvisoView() }
        .animation(.easeInOut(duration: 0.2), value: modelo.aviso)
        .sheet(isPresented: $mostrandoCameras) { NavigationStack { TelaDeCameras() } }
        .sheet(isPresented: $mostrandoAjuda) { NavigationStack { AjudaView() } }
        .task {
            // com a conta Apple gratuita o app para de abrir em 7 dias: avisa antes
            if Assinatura.deveAvisar(), let texto = Assinatura.descricao() { modelo.avisar(texto, .erro) }
        }
    }

    private var caminho: Binding<[String]> {
        Binding(
            get: {
                if case .camera(let id) = modelo.selecao { return [id] }
                return []
            },
            set: { novo in modelo.selecionar(novo.last.map { .camera($0) } ?? .geral) }
        )
    }
}
