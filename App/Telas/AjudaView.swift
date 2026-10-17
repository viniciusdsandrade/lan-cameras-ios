import SwiftUI
import CamerasSessao

struct AjudaView: View {
    @Environment(\.dismiss) private var fechar

    var body: some View {
        List {
            if let assinatura = Assinatura.descricao() {
                Section("Este app") {
                    Label(assinatura, systemImage: Assinatura.deveAvisar() ? "exclamationmark.triangle.fill" : "checkmark.seal")
                        .foregroundStyle(Assinatura.deveAvisar() ? .orange : .primary)
                }
            }
            Section("Como usar") {
                bloco("Mover a câmera", "Segure uma seta: a câmera se mexe enquanto você segura e para ao soltar. O quadrado do meio para na hora. A velocidade (lenta, média, rápida) fica logo abaixo das setas.")
                bloco("Lentes", "Cada câmera tem duas lentes no mesmo quadro: a fixa (em cima) e a móvel (embaixo). Só a móvel gira. A lente fixa aparece abaixo do vídeo quando você liga \"Mostrar a lente fixa\".")
                bloco("Zoom", "Pinça ou toque duplo no vídeo ampliam; com zoom, arraste para andar pela imagem; toque duplo de novo volta ao normal. O zoom é digital: as câmeras não têm zoom óptico.")
                bloco("Tela cheia", "Gire o iPhone: o vídeo ocupa a tela inteira, com as setas, o zoom e os botões principais por cima. Um toque no vídeo mostra ou esconde os controles.")
                bloco("Rastreio automático", "Com o rastreio ligado, a câmera segue o movimento e depois volta sozinha ao ponto de vigia. Por isso um movimento manual \"se desfaz\": desligue o rastreio se quiser que ela fique onde você deixou.")
                bloco("Posições salvas", "\"Salvar a posição atual\" guarda para onde a câmera aponta. O app só apaga as posições que ele mesmo criou; as que já vinham na câmera (com cadeado) ficam intactas.")
                bloco("Som", "\"Ouvir\" liga o som da câmera. \"Segure para falar\" usa o microfone do iPhone enquanto o dedo estiver no botão, e a câmera repete no alto-falante dela; enquanto você fala o som da câmera fica mudo para não dar eco. Há também sons prontos e texto falado. O volume começa em 30%: o alto-falante é alto.")
            }
            Section("Permissões") {
                bloco("Rede local", "Necessária para achar as câmeras e falar com elas. Libere em Ajustes > Privacidade e Segurança > Rede Local.")
                bloco("Microfone", "Só quando você segura \"Falar\".")
                bloco("Fotos", "Só para adicionar as fotos que você tira; o app não vê as outras.")
            }
            Section("Privacidade") {
                Text("Usuário e senha das câmeras ficam só neste iPhone, dentro do app, fora do backup do iCloud. O app não abre nenhuma porta e só fala com as câmeras do seu Wi-Fi; nada vai para a internet. Em segundo plano ele solta as câmeras na hora e as reabre quando você volta.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ajuda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fechar() } } }
    }

    private func bloco(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.headline)
            Text(texto).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
