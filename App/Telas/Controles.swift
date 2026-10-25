import SwiftUI
import CamerasCore
import CamerasSessao

/// Os cartões de controle de uma câmera em retrato, abaixo da fileira de ouvir, falar e foto: movimento,
/// posições salvas, luz e rastreio, som na câmera e imagem.
struct Controles: View {
    @EnvironmentObject var modelo: ModeloDoApp
    @ObservedObject var sessao: SessaoDaCamera
    @ObservedObject private var zoom: EstadoDeZoom
    @State private var nomeDaPosicao = ""
    @State private var salvandoPosicao = false
    @State private var texto = ""
    @State private var apagando: PresetDaCamera?
    @FocusState private var digitando: Bool

    init(sessao: SessaoDaCamera) {
        self.sessao = sessao
        self.zoom = sessao.zoom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(sessao.estado?.avisos ?? [], id: \.self) { a in
                Label(a, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            movimento
            posicoes
            luzERastreio
            som
            imagem
        }
        .alert("Salvar a posição atual", isPresented: $salvandoPosicao) {
            TextField("Nome (ex.: Vista da rua)", text: $nomeDaPosicao)
            Button("Salvar") { sessao.salvarPosicao(nome: nomeDaPosicao) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A câmera guarda para onde ela está apontando agora.")
        }
        .confirmationDialog("Apagar esta posição?", isPresented: Binding(get: { apagando != nil }, set: { if !$0 { apagando = nil } }),
                            titleVisibility: .visible, presenting: apagando) { p in
            Button("Apagar \"\(p.nome)\"", role: .destructive) { sessao.apagar(p) }
            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: modelo.volume) { _, novo in sessao.volumeMudou(novo) }
    }

    // MARK: - Movimento

    private var movimento: some View {
        Secao(titulo: "Movimento", simbolo: "arrow.up.and.down.and.arrow.left.and.right") {
            HStack {
                Spacer()
                ControleDirecional(ativas: sessao.direcoesAtivas, segurar: { sessao.segurar($0) },
                                   soltar: { sessao.soltar($0) }, parar: { sessao.pararMovimento() })
                Spacer()
            }
            .padding(.vertical, 4)
            Picker("Velocidade", selection: $modelo.velocidade) {
                Text("Lenta").tag(0.2)
                Text("Média").tag(0.4)
                Text("Rápida").tag(0.7)
            }
            .pickerStyle(.segmented)
            Nota("Segure uma seta: a câmera se mexe enquanto você segura e para ao soltar.")
            if sessao.estado?.rastreioLigado == true, let s = sessao.estado?.rastreioVoltaEmSegundos {
                Label("Rastreio ligado: ela volta sozinha ao ponto de vigia depois de \(s) s.", systemImage: "scope")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Posições salvas

    private var posicoes: some View {
        Secao(titulo: "Posições salvas", simbolo: "mappin.and.ellipse") {
            let lista = sessao.estado?.presets ?? []
            if lista.isEmpty {
                Nota(sessao.estado == nil ? "Lendo…" : "Nenhuma posição salva.")
            }
            ForEach(lista, id: \.token) { p in
                HStack(spacing: 10) {
                    Image(systemName: "scope").foregroundStyle(.secondary)
                    Text(p.nome).lineLimit(1)
                    Spacer()
                    if sessao.presetsDoApp.contains(p.token) {
                        Button { apagando = p } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .tint(.red)
                            .accessibilityLabel("Apagar a posição \(p.nome)")
                            .disabled(sessao.ocupadas.contains("apagar-\(p.token)"))
                    } else {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
                            .accessibilityLabel("já vinha na câmera; o app não apaga")
                    }
                    Button("Ir") { sessao.irPara(p) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Ir para a posição \(p.nome)")
                        .disabled(sessao.ocupadas.contains("preset-\(p.token)"))
                }
            }
            Button {
                nomeDaPosicao = ""
                salvandoPosicao = true
            } label: { Label("Salvar a posição atual", systemImage: "plus.circle") }
                .disabled(sessao.ocupadas.contains("salvar-preset"))
            Nota("Só as posições criadas por este app podem ser apagadas aqui.")
        }
    }

    // MARK: - Luz e rastreio

    private var luzERastreio: some View {
        Secao(titulo: "Luz e rastreio", simbolo: "lightbulb") {
            Picker("Luz", selection: Binding(
                get: { sessao.luzPedida ?? sessao.estado?.luz },
                set: { if let m = $0 { sessao.definirLuz(m) } }
            )) {
                Text("Automática").tag(ModoDaLuz?.some(.automatico))
                Text("Ligada").tag(ModoDaLuz?.some(.ligada))
                Text("Desligada").tag(ModoDaLuz?.some(.desligada))
            }
            .pickerStyle(.segmented)
            .disabled(sessao.estado?.luz == nil || sessao.ocupadas.contains("luz"))
            Toggle(isOn: Binding(
                get: { sessao.rastreioPedido ?? sessao.estado?.rastreioLigado ?? false },
                set: { sessao.definirRastreio($0) }
            )) { Text("Rastreio automático") }
                .disabled(sessao.estado?.rastreioLigado == nil || sessao.ocupadas.contains("rastreio"))
            Nota("Com o rastreio ligado a câmera segue o que se mexe e depois volta sozinha ao ponto de vigia: o movimento manual \"se desfaz\".")
        }
    }

    // MARK: - Som

    private var som: some View {
        Secao(titulo: "Som na câmera", simbolo: "speaker.wave.2") {
            if sessao.falandoAoVivo {
                ProgressView(value: Double(sessao.nivelDoMicrofone)).tint(.red)
                Nota("Enquanto você fala, o som da câmera fica mudo para não dar eco.")
            }
            HStack {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $modelo.volume, in: 5...100, step: 5).accessibilityLabel("Volume na câmera")
                Text("\(Int(modelo.volume))%").font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
            }
            Nota("O alto-falante da câmera é alto: 10% já se ouve bem.")
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { botaoDeSom(.campainha, "bell.fill"); botaoDeSom(.bip, "waveform") }
                GridRow { botaoDeSom(.alarme, "exclamationmark.triangle.fill"); botaoDeSom(.sirene, "light.beacon.max.fill") }
            }
            Button(role: .destructive) { sessao.pararSom() } label: {
                Label("Parar o som", systemImage: "stop.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Divider()
            HStack {
                TextField("O que a câmera deve falar", text: $texto)
                    .textFieldStyle(.roundedBorder)
                    .focused($digitando)
                    .submitLabel(.send)
                    .onSubmit(falar)
                Button("Falar", action: falar)
                    .buttonStyle(.bordered)
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty || sessao.ocupadas.contains("texto"))
            }
        }
    }

    private func botaoDeSom(_ som: Som, _ simbolo: String) -> some View {
        Button { sessao.tocar(som) } label: {
            Label(som.rotulo, systemImage: simbolo).frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .disabled(sessao.ocupadas.contains("som"))
        .accessibilityHint("Toca \(som.rotulo.lowercased()) no alto-falante da câmera")
    }

    private func falar() {
        digitando = false
        sessao.falarTexto(texto)
    }

    // MARK: - Imagem

    private var imagem: some View {
        Secao(titulo: "Imagem", simbolo: "photo") {
            Picker("Qualidade", selection: $modelo.qualidadeHD) {
                Text("HD").tag(true)
                Text("Leve").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: modelo.qualidadeHD) { _, _ in modelo.recomecarSessaoDaCamera() }
            HStack(spacing: 12) {
                Button { zoom.definir(zoom.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 30, height: 30) }
                    .accessibilityLabel("Diminuir o zoom")
                Slider(value: Binding(get: { zoom.zoom }, set: { zoom.definir($0) }), in: EstadoDeZoom.minimo...EstadoDeZoom.maximo)
                    .accessibilityLabel("Zoom")
                Button { zoom.definir(zoom.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 30, height: 30) }
                    .accessibilityLabel("Aumentar o zoom")
                Button(String(format: "%.1f×", zoom.zoom)) { zoom.reiniciar() }
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 44)
                    .accessibilityLabel("Voltar o zoom ao normal")
            }
            .buttonStyle(.bordered)
            Nota("O zoom é digital (as câmeras não têm zoom óptico). Pinça ou toque duplo no vídeo também ampliam.")
            if sessao.camera.duasLentes {
                Toggle("Mostrar a lente fixa no canto", isOn: $modelo.mostrarLenteFixa)
            }
        }
    }
}

/// "Segure para falar": o microfone do iPhone vai para o alto-falante da câmera enquanto o
/// dedo estiver no botão.
struct BotaoDeFalar: View {
    @ObservedObject var sessao: SessaoDaCamera
    var compacto = false

    var body: some View {
        BotaoDePressao(descricao: "Segure para falar pela câmera", ativo: sessao.falandoAoVivo, corAtiva: .red,
                       aoPressionar: { sessao.iniciarFalaAoVivo() }, aoSoltar: { sessao.pararFalaAoVivo() }) { aceso in
            Label(aceso ? (sessao.falandoAoVivo ? "Falando…" : "Abrindo…") : (compacto ? "Falar" : "Segure para falar"),
                  systemImage: aceso ? "mic.fill" : "mic")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: compacto ? nil : .infinity, minHeight: 44)
                .padding(.horizontal, compacto ? 16 : 0)
                .background(Capsule().fill(aceso ? Color.red : Color.red.opacity(0.35)))
        }
    }
}
