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
                bloco("arrow.up.and.down.and.arrow.left.and.right", .blue, "Mover a câmera", "Segure uma seta do anel: a câmera se mexe enquanto você segura e para ao soltar. O botão do meio para na hora. A velocidade (lenta, média, rápida) fica logo abaixo do anel.")
                bloco("pip", .teal, "Lentes", "Nas câmeras de duas lentes, a móvel (a única que gira) aparece grande e a fixa, que mostra a cena inteira, num quadro menor no canto do vídeo. O botão Lente fixa, embaixo do vídeo, mostra e esconde.")
                bloco("plus.magnifyingglass", .indigo, "Zoom", "Pinça ou toque duplo no vídeo ampliam; com zoom, arraste para andar pela imagem; toque duplo de novo volta ao normal. O zoom é digital: as câmeras não têm zoom óptico.")
                bloco("rectangle.landscape.rotate", .orange, "Tela cheia", "Gire o iPhone: o vídeo ocupa a tela inteira, com o anel, o zoom e os botões principais por cima. Um toque no vídeo mostra ou esconde os controles. Na visão geral, deitado, todas as câmeras cabem na tela.")
                bloco("square.grid.2x2", .purple, "Visão geral", "O botão de grade, no alto, mostra as câmeras em duas colunas ou uma embaixo da outra. Em cima delas, quantas estão sem imagem; uma câmera sem imagem diz por quê e tem o botão Tentar agora. Puxe para baixo para reabrir todas.")
                bloco("scope", .orange, "Rastreio automático", "Com o rastreio ligado, a câmera segue o movimento e depois volta sozinha ao ponto de vigia. Por isso um movimento manual \"se desfaz\": desligue o rastreio se quiser que ela fique onde você deixou.")
                bloco("mappin.and.ellipse", .pink, "Posições salvas", "\"Salvar a posição atual\" guarda para onde a câmera aponta. O app só apaga as posições que ele mesmo criou; as que já vinham na câmera (com cadeado) ficam intactas.")
                bloco("speaker.wave.2.fill", .green, "Som", "\"Ouvir\", embaixo do vídeo, liga o som da câmera. Segure \"Falar\" para usar o microfone do iPhone, e a câmera repete no alto-falante dela; enquanto você fala o som da câmera fica mudo para não dar eco. Mais abaixo há sons prontos, texto falado e o volume, que começa em 30%: o alto-falante é alto.")
                bloco("film.stack", .purple, "Gravações", "As câmeras gravam sozinhas no cartão de memória quando há movimento, com o som, mesmo com o celular desligado. Em Gravações (o ícone de filme no alto da visão geral), escolha a noite: cada movimento aparece com a foto do instante, e a linha do tempo mostra a noite inteira. Toque num movimento e em ▶ para baixar o vídeo do cartão e assistir; deslize para o lado para passar de um para outro; Ver ao vivo abre a câmera. Compartilhar salva o vídeo no Fotos ou manda para onde quiser.")
                bloco("key.fill", .yellow, "Senha das câmeras", "Você não digita senha: o app pega o usuário e a senha com a própria câmera. Se o app do fabricante (iCSee, XMEye) trocar a senha dela, ou o roteador mudar o endereço, o app percebe e pega os novos sozinho. Se mesmo assim a imagem não voltar, abra Mais > Câmeras, no alto da visão geral, e toque em Procurar câmeras na rede.")
            }
            Section("Permissões") {
                bloco("network", .gray, "Rede local", "Necessária para achar as câmeras e falar com elas. Libere em Ajustes > Privacidade e Segurança > Rede Local.")
                bloco("mic.fill", .red, "Microfone", "Só quando você segura \"Falar\".")
                bloco("photo.on.rectangle", .blue, "Fotos", "Só para adicionar as fotos que você tira e os vídeos que você salva das gravações; o app não vê os outros.")
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

    private func bloco(_ simbolo: String, _ cor: Color, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: simbolo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(cor.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.headline)
                Text(texto).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
