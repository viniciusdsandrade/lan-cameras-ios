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

    /// Texto que cobre o vídeo enquanto não há imagem; nil quando está ao vivo.
    var mensagem: String? {
        switch self {
        case .aoVivo: return nil
        case .conectando: return "conectando…"
        case .parado: return "parado"
        case .erro(let m): return "sem imagem: \(m)"
        }
    }
}

/// Uma lente de uma câmera na tela, com o nome e o estado da conexão por cima.
struct LenteComRotulo: View {
    let rotulo: String
    let distribuidor: DistribuidorDeQuadros
    let lente: LenteExibida
    let estado: FluxoDeVideo.Estado
    @ObservedObject var zoom: EstadoDeZoom
    var zoomHabilitado = false
    var cantos: CGFloat = 10
    var aoTocar: (() -> Void)? = nil

    var body: some View {
        ZStack {
            VistaDaLente(distribuidor: distribuidor, lente: lente, zoom: zoom, zoomHabilitado: zoomHabilitado, aoTocar: aoTocar)
            if let m = estado.mensagem {
                Text(m)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.7))
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Circle().fill(estado.cor).frame(width: 8, height: 8)
                Text(rotulo).font(.caption.weight(.medium)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 9)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(8)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(rotulo), \(estado.mensagem ?? "ao vivo")")
        }
        .overlay(alignment: .bottomTrailing) {
            if zoomHabilitado, zoom.zoom > 1.01 {
                Text(String(format: "%.1f×", zoom.zoom))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cantos))
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
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { aoPressionar(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { aoSoltar() } }
    }
}

/// Uma seta do controle de movimento: quadrada, grande o bastante para o polegar.
struct SetaDeMovimento: View {
    let direcao: Direcao
    @ObservedObject var sessao: SessaoDaCamera
    var lado: CGFloat = 64
    var fundoTranslucido = false

    var body: some View {
        BotaoDePressao(descricao: "Mover para \(direcao.nome)", ativo: sessao.direcoesAtivas.contains(direcao),
                       aoPressionar: { sessao.segurar(direcao) }, aoSoltar: { sessao.soltar(direcao) }) { aceso in
            Image(systemName: direcao.simbolo)
                .font(.system(size: lado * 0.34, weight: .semibold))
                .foregroundStyle(aceso ? .white : .primary)
                .frame(width: lado, height: lado)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(aceso ? AnyShapeStyle(Color.accentColor) : (fundoTranslucido ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(.secondarySystemBackground))))
                )
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
        }
    }
}

/// As quatro setas com o botão de parar no meio.
struct ControleDeMovimento: View {
    @ObservedObject var sessao: SessaoDaCamera
    var lado: CGFloat = 64
    var fundoTranslucido = false

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: lado, height: lado)
                SetaDeMovimento(direcao: .cima, sessao: sessao, lado: lado, fundoTranslucido: fundoTranslucido)
                Color.clear.frame(width: lado, height: lado)
            }
            GridRow {
                SetaDeMovimento(direcao: .esquerda, sessao: sessao, lado: lado, fundoTranslucido: fundoTranslucido)
                Button { sessao.pararMovimento() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: lado * 0.28, weight: .semibold))
                        .frame(width: lado, height: lado)
                        .background(RoundedRectangle(cornerRadius: 14).fill(fundoTranslucido ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(.tertiarySystemBackground))))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Parar a câmera")
                SetaDeMovimento(direcao: .direita, sessao: sessao, lado: lado, fundoTranslucido: fundoTranslucido)
            }
            GridRow {
                Color.clear.frame(width: lado, height: lado)
                SetaDeMovimento(direcao: .baixo, sessao: sessao, lado: lado, fundoTranslucido: fundoTranslucido)
                Color.clear.frame(width: lado, height: lado)
            }
        }
    }
}

/// Os avisos curtos no pé da tela (feito, erro, dica).
struct AvisoView: View {
    @EnvironmentObject var modelo: ModeloDoApp

    var body: some View {
        if let aviso = modelo.aviso {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icone(aviso.tipo)).foregroundStyle(cor(aviso.tipo))
                Text(aviso.texto).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(cor(aviso.tipo).opacity(0.5)))
            .shadow(radius: 8, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(aviso.id)
            .onTapGesture { modelo.aviso = nil }
            .accessibilityAddTraits(.isStaticText)
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

/// Um grupo de controles com título, no estilo dos Ajustes.
struct Secao<Conteudo: View>: View {
    let titulo: String
    let simbolo: String
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titulo, systemImage: simbolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12, content: conteudo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
