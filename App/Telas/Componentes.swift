import SwiftUI
import CamerasCore
import CamerasSessao

extension FluxoDeVideo.Estado {
    var cor: Color {
        switch self {
        case .aoVivo: return .green
        case .conectando: return .orange
        case .erro: return .red
        case .parado: return .gray
        }
    }

    /// Em poucas palavras, para os selos.
    var rotulo: String {
        switch self {
        case .aoVivo: return "Ao vivo"
        case .conectando: return "Conectando…"
        case .erro: return "Sem imagem"
        case .parado: return "Parado"
        }
    }

    /// O estado para o VoiceOver (e os testes de interface): nil ao vivo, senão o que está acontecendo.
    var mensagem: String? {
        switch self {
        case .aoVivo: return nil
        case .conectando: return "conectando…"
        case .parado: return "parado"
        case .erro(let m): return "sem imagem: \(m)"
        }
    }

    var aoVivo: Bool {
        if case .aoVivo = self { return true }
        return false
    }
}

/// Uma lente ao vivo: o vídeo e, enquanto não há imagem, o que está acontecendo por cima dele
/// (conectando, ou por que não há imagem e como tentar de novo), em vez de um quadro preto mudo. Com
/// zoom, o quanto está ampliado num selo no canto.
struct LenteAoVivo: View {
    let distribuidor: DistribuidorDeQuadros
    let lente: LenteExibida
    let estado: FluxoDeVideo.Estado
    @ObservedObject var zoom: EstadoDeZoom
    var zoomHabilitado = false
    /// Nos cartões da visão geral: textos menores e o motivo em no máximo duas linhas.
    var compacta = false
    var aoTocar: (() -> Void)? = nil
    var tentarAgora: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black
            VistaDaLente(distribuidor: distribuidor, lente: lente, zoom: zoom, zoomHabilitado: zoomHabilitado, aoTocar: aoTocar)
            if !estado.aoVivo {
                SemImagem(estado: estado, compacta: compacta, tentarAgora: tentarAgora)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if zoomHabilitado, zoom.zoom > 1.01 {
                Text(String(format: "%.1f×", zoom.zoom))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Tema.sobreVideo, in: Capsule())
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct SemImagem: View {
    let estado: FluxoDeVideo.Estado
    let compacta: Bool
    let tentarAgora: (() -> Void)?

    var body: some View {
        VStack(spacing: compacta ? 6 : 10) {
            switch estado {
            case .conectando:
                ProgressView().tint(.white)
                Text("Conectando…").font(compacta ? .footnote : .callout).foregroundStyle(.white.opacity(0.85))
            case .erro(let motivo):
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: compacta ? 22 : 30, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Sem imagem").font((compacta ? Font.footnote : .callout).weight(.semibold))
                Text(motivo)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(compacta ? 2 : 3)
                if let tentarAgora {
                    Button("Tentar agora", action: tentarAgora)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.white)
                }
            case .parado, .aoVivo:
                Image(systemName: "pause.circle").font(.system(size: compacta ? 22 : 30)).foregroundStyle(.white.opacity(0.6))
                Text("Parado").font(compacta ? .footnote : .callout).foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(.white)
        .padding(compacta ? 10 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.66))
    }
}

/// Botão que age ENQUANTO está pressionado (setas de movimento, "segure para falar"): chama
/// `aoPressionar` ao encostar e `aoSoltar` ao soltar. O estado é um `GestureState`, que o SwiftUI
/// zera também quando o gesto é cancelado (ligação, notificação, a vista sumindo): o soltar nunca
/// se perde e a câmera nunca fica se mexendo sozinha.
struct BotaoDePressao<Rotulo: View>: View {
    let descricao: String
    var ativo = false
    var corAtiva: Color = .accentColor
    let aoPressionar: () -> Void
    let aoSoltar: () -> Void
    @ViewBuilder let rotulo: (_ aceso: Bool) -> Rotulo
    @GestureState private var pressionado = false

    var body: some View {
        rotulo(ativo || pressionado)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressionado) { _, estado, _ in estado = true }
            )
            .onChange(of: pressionado) { _, agora in
                if agora {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    aoPressionar()
                } else {
                    aoSoltar()
                }
            }
            .onDisappear { if pressionado { aoSoltar() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(descricao)
            .accessibilityValue(ativo || pressionado ? "ativo" : "solto")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { aoPressionar(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { aoSoltar() } }
    }
}

/// O controle de movimento, como nos apps de câmeras PTZ: um anel com as quatro direções e o botão de
/// parar no meio. Cada direção é um `BotaoDePressao` próprio, posto sobre a fatia dela e sem encostar nos
/// outros (quatro fatias do tamanho do anel, empilhadas, disputariam o mesmo toque); o anel em volta é só
/// desenho, que acende a fatia da direção em movimento.
struct ControleDirecional: View {
    let ativas: Set<Direcao>
    let segurar: (Direcao) -> Void
    let soltar: (Direcao) -> Void
    let parar: () -> Void
    var diametro: CGFloat = 196
    /// Por cima do vídeo (na tela cheia): fundo translúcido.
    var translucido = false
    private let raioInterno: CGFloat = 0.38

    var body: some View {
        ZStack {
            if translucido {
                Circle().fill(.clear).fundoDeControles(Circle())
            } else {
                Circle().fill(Tema.cartaoForte)
            }
            Circle().strokeBorder(Tema.borda)
            ForEach(Direcao.allCases, id: \.self) { d in
                Setor(centro: d.angulo, raioInterno: raioInterno)
                    .fill(ativas.contains(d) ? Color.accentColor : Color.clear)
                    .allowsHitTesting(false)
            }
            ForEach(Direcao.allCases, id: \.self) { d in
                BotaoDePressao(descricao: "Mover para \(d.nome)", ativo: ativas.contains(d),
                               aoPressionar: { segurar(d) }, aoSoltar: { soltar(d) }) { aceso in
                    Image(systemName: d.chevron)
                        .font(.system(size: diametro * 0.1, weight: .bold))
                        .foregroundStyle(aceso ? Color.white : Color.primary.opacity(0.9))
                        .frame(width: diametro * 0.3, height: diametro * 0.3)
                }
                .position(centro(de: d))
            }
            Button(action: parar) {
                Image(systemName: "stop.fill")
                    .font(.system(size: diametro * 0.09, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: diametro * 0.32, height: diametro * 0.32)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .overlay(Circle().strokeBorder(Tema.borda))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Parar a câmera")
        }
        .frame(width: diametro, height: diametro)
        .animation(.easeOut(duration: 0.12), value: ativas)
    }

    /// O meio da fatia de uma direção (onde ficam a seta e o alvo do toque).
    private func centro(de d: Direcao) -> CGPoint {
        let raio = diametro / 2 * (1 + raioInterno) / 2
        let a = d.angulo.radians
        return CGPoint(x: diametro / 2 + raio * cos(a), y: diametro / 2 + raio * sin(a))
    }
}

extension Direcao {
    /// O meio da fatia no anel (0° é a direita e o ângulo cresce no sentido horário, como na tela).
    var angulo: Angle {
        switch self {
        case .direita: return .degrees(0)
        case .baixo: return .degrees(90)
        case .esquerda: return .degrees(180)
        case .cima: return .degrees(270)
        }
    }

    var chevron: String {
        switch self {
        case .cima: return "chevron.up"
        case .baixo: return "chevron.down"
        case .esquerda: return "chevron.left"
        case .direita: return "chevron.right"
        }
    }
}

/// Um quarto do anel, com uma folga entre as fatias.
private struct Setor: Shape {
    let centro: Angle
    /// O raio do furo do meio, em fração do raio de fora.
    let raioInterno: CGFloat

    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let fora = min(r.width, r.height) / 2
        let dentro = fora * raioInterno
        let inicio = centro - .degrees(43), fim = centro + .degrees(43)
        var p = Path()
        p.addArc(center: c, radius: fora, startAngle: inicio, endAngle: fim, clockwise: false)
        p.addArc(center: c, radius: dentro, startAngle: fim, endAngle: inicio, clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Os avisos curtos no pé da tela (feito, erro, dica). Um toque fecha.
struct AvisoView: View {
    @EnvironmentObject var modelo: ModeloDoApp

    var body: some View {
        if let aviso = modelo.aviso {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icone(aviso.tipo))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(cor(aviso.tipo))
                Text(aviso.texto).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(cor(aviso.tipo).opacity(0.45)))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(aviso.id)
            .onTapGesture { modelo.aviso = nil }
            // um elemento só, com o texto do aviso: o VoiceOver lê a frase inteira
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(aviso.texto)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("aviso")
        }
    }

    private func icone(_ t: Aviso.Tipo) -> String {
        switch t {
        case .info: return "info.circle.fill"
        case .ok: return "checkmark.circle.fill"
        case .erro: return "exclamationmark.triangle.fill"
        }
    }

    private func cor(_ t: Aviso.Tipo) -> Color {
        switch t {
        case .info: return .blue
        case .ok: return .green
        case .erro: return .red
        }
    }
}

/// Um bloco dos controles: o título pequeno em cima e o conteúdo num cartão.
struct Secao<Conteudo: View>: View {
    let titulo: String
    let simbolo: String
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: simbolo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 12, content: conteudo)
                .cartao()
        }
    }
}

/// Texto de apoio pequeno, embaixo de um controle.
struct Nota: View {
    let texto: String
    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
