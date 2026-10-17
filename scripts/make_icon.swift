#!/usr/bin/env swift
// Gera o ícone do app para iOS (o mesmo desenho do app do Mac) por desenho vetorial, sem imagens de partida.
//
//   swift scripts/make_icon.swift [pasta-do-appiconset]   (padrão: Resources/Assets.xcassets/AppIcon.appiconset)
//
// No iOS o ícone é um quadrado de 1024 px opaco e o sistema aplica a forma arredondada: o fundo
// vai até as bordas, sem margem nem sombra, e o desenho do Mac (corpo de 824 px) é ampliado para
// ocupar o quadrado. Saem três versões: clara, escura e para ícones tingidos (tons de cinza).
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Cores

func cor(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let espaco = CGColorSpace(name: CGColorSpace.sRGB)!

func gradiente(_ cores: [CGColor], _ posicoes: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: espaco, colors: cores as CFArray, locations: posicoes)!
}

// MARK: - Formas

/// Superelipse |x|^n + |y|^n = 1: o "squircle" do macOS (curvatura contínua, sem o canto circular de um retângulo).
func squircle(centro: CGPoint, raio: CGFloat, n: Double = 5) -> CGPath {
    let p = CGMutablePath()
    let passos = 720
    for i in 0...passos {
        let t = Double(i) / Double(passos) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / n) * (s < 0 ? -1 : 1)
        let ponto = CGPoint(x: centro.x + CGFloat(x) * raio, y: centro.y + CGFloat(y) * raio)
        if i == 0 { p.move(to: ponto) } else { p.addLine(to: ponto) }
    }
    p.closeSubpath()
    return p
}

func circulo(_ centro: CGPoint, _ raio: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: centro.x - raio, y: centro.y - raio, width: raio * 2, height: raio * 2), transform: nil)
}

func anel(_ centro: CGPoint, externo: CGFloat, interno: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.addPath(circulo(centro, externo))
    p.addPath(circulo(centro, interno))
    return p
}

/// A sombra do Core Graphics é medida em pixels e ignora a escala do contexto: sem converter da grade de
/// 1024, a de 30 px cobriria o ícone de 16 px inteiro (uma caixa cinza em volta dele).
func sombra(_ ctx: CGContext, _ escala: CGFloat, dy: CGFloat, desfoque: CGFloat, alfa: CGFloat) {
    ctx.setShadow(offset: CGSize(width: 0, height: dy * escala), blur: desfoque * escala, color: cor(0x000000, alfa))
}

// MARK: - Desenho (espaço de 1024 x 1024, origem embaixo à esquerda)

enum Variante { case clara, escura }

func desenhar(_ ctx: CGContext, variante: Variante) {
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    let miudo = false
    // o corpo do ícone do Mac tem 824 px; aqui ele vira o quadrado inteiro
    let ampliacao: CGFloat = 1024.0 / 824.0
    let escala = ampliacao

    // Fundo azul-marinho até as bordas (na versão escura, quase preto)
    let fundo = variante == .clara ? [cor(0x45649C), cor(0x213862), cor(0x0B1426)] : [cor(0x1B2843), cor(0x0E1729), cor(0x05080F)]
    ctx.drawLinearGradient(gradiente(fundo, [0, 0.5, 1]), start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
    ctx.drawRadialGradient(gradiente([cor(0x3D7BFF, variante == .clara ? 0.34 : 0.22), cor(0x3D7BFF, 0)], [0, 1]),
                           startCenter: CGPoint(x: 512, y: 535), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 535), endRadius: 584, options: [])
    if variante == .clara {
        ctx.drawLinearGradient(gradiente([cor(0xFFFFFF, 0.14), cor(0xFFFFFF, 0)], [0, 1]),
                               start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 560), options: [])
    }

    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: ampliacao, y: ampliacao)
    ctx.translateBy(x: -512, y: -512)
    // A lente inteira é desenhada em 94% em torno do centro: folga para o LED e para a borda
    let c = CGPoint(x: 512, y: 500)
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.scaleBy(x: 0.94, y: 0.94)
    ctx.translateBy(x: -c.x, y: -c.y)

    // Base da lente: anel escuro que dá profundidade
    ctx.saveGState()
    sombra(ctx, escala, dy: -10, desfoque: 24, alfa: 0.55)
    ctx.addPath(circulo(c, 322))
    ctx.setFillColor(cor(0x0A101C))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(circulo(c, 322))
    ctx.clip()
    ctx.drawLinearGradient(gradiente([cor(0x2B3C5E), cor(0x0A101C)], [0, 1]),
                           start: CGPoint(x: 512, y: 822), end: CGPoint(x: 512, y: 178), options: [])
    ctx.restoreGState()

    // Aro metálico
    ctx.saveGState()
    ctx.addPath(anel(c, externo: 296, interno: 252))
    ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(gradiente([cor(0xF6F9FD), cor(0xA9B5C7), cor(0x5E6C83), cor(0xD3DCE8)], [0, 0.38, 0.66, 1]),
                           start: CGPoint(x: 280, y: 790), end: CGPoint(x: 744, y: 210), options: [])
    ctx.restoreGState()
    if !miudo {
        // fio de sombra entre o aro e o vidro
        ctx.setStrokeColor(cor(0x000000, 0.75))
        ctx.setLineWidth(8)
        ctx.addPath(circulo(c, 250))
        ctx.strokePath()
    }

    // Vidro da lente
    ctx.saveGState()
    ctx.addPath(circulo(c, 246))
    ctx.clip()
    ctx.drawRadialGradient(gradiente([cor(0x22407A), cor(0x0D1B38), cor(0x03070F)], [0, 0.62, 1]),
                           startCenter: CGPoint(x: c.x - 50, y: c.y + 50), startRadius: 0,
                           endCenter: c, endRadius: 250, options: [])
    if !miudo {
        // anéis do conjunto óptico
        for (raio, alfa, largura) in [(196.0, 0.34, 4.0), (150.0, 0.26, 3.0), (108.0, 0.22, 3.0)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.setStrokeColor(cor(0x5E9BFF, alfa))
            ctx.setLineWidth(largura)
            ctx.addPath(circulo(c, raio))
            ctx.strokePath()
        }
        // brilho esverdeado do tratamento antirreflexo
        ctx.drawRadialGradient(gradiente([cor(0x2EE6C8, 0), cor(0x2EE6C8, 0.20), cor(0x2EE6C8, 0)], [0, 0.55, 1]),
                               startCenter: c, startRadius: 120, endCenter: c, endRadius: 232, options: [])
    }
    // pupila
    ctx.drawRadialGradient(gradiente([cor(0x000000, 0.95), cor(0x000000, 0)], [0, 1]),
                           startCenter: c, startRadius: 0, endCenter: c, endRadius: 96, options: [])
    // luz azul que entra por baixo à direita
    ctx.drawRadialGradient(gradiente([cor(0x7FB2FF, 0.42), cor(0x7FB2FF, 0)], [0, 1]),
                           startCenter: CGPoint(x: c.x + 108, y: c.y - 112), startRadius: 0,
                           endCenter: CGPoint(x: c.x + 108, y: c.y - 112), endRadius: 150, options: [])
    // reflexo grande, em cima à esquerda
    ctx.saveGState()
    ctx.translateBy(x: c.x - 82, y: c.y + 112)
    ctx.rotate(by: 0.62)
    ctx.scaleBy(x: 1.55, y: 0.78)
    ctx.drawRadialGradient(gradiente([cor(0xFFFFFF, 0.55), cor(0xFFFFFF, 0.12), cor(0xFFFFFF, 0)], [0, 0.55, 1]),
                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 116, options: [])
    ctx.restoreGState()
    // ponto de luz
    ctx.drawRadialGradient(gradiente([cor(0xFFFFFF, 0.95), cor(0xFFFFFF, 0)], [0, 1]),
                           startCenter: CGPoint(x: c.x - 118, y: c.y + 128), startRadius: 0,
                           endCenter: CGPoint(x: c.x - 118, y: c.y + 128), endRadius: 30, options: [])
    ctx.restoreGState()
    ctx.restoreGState()                // fim da escala da lente

    // LED verde de "ao vivo"
    let led = CGPoint(x: 772, y: 772)
    let raioDoLed: CGFloat = miudo ? 40 : 31
    ctx.drawRadialGradient(gradiente([cor(0x3DFF8C, 0.60), cor(0x3DFF8C, 0)], [0, 1]),
                           startCenter: led, startRadius: 0, endCenter: led, endRadius: miudo ? 100 : 82, options: [])
    ctx.saveGState()
    ctx.addPath(circulo(led, raioDoLed))
    ctx.clip()
    ctx.drawRadialGradient(gradiente([cor(0xC8FFE0), cor(0x2EE57A), cor(0x0E8F45)], [0, 0.45, 1]),
                           startCenter: CGPoint(x: led.x - 8, y: led.y + 9), startRadius: 0,
                           endCenter: led, endRadius: raioDoLed + 6, options: [])
    ctx.restoreGState()
    if !miudo {
        ctx.setStrokeColor(cor(0x06361D, 0.8))
        ctx.setLineWidth(3)
        ctx.addPath(circulo(led, raioDoLed))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// MARK: - Saída

let espacoCinza = CGColorSpaceCreateDeviceGray()

func renderizar(_ variante: Variante) -> CGImage {
    // opaco: o iOS não aceita transparência no ícone
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: espaco, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    desenhar(ctx, variante: variante)
    return ctx.makeImage()!
}

/// Para ícones tingidos o iOS usa só a luminância: a versão escura em tons de cinza.
func emTonsDeCinza(_ img: CGImage) -> CGImage {
    let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: espacoCinza, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    return ctx.makeImage()!
}

func gravarPNG(_ img: CGImage, _ url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}

let saida = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/Assets.xcassets/AppIcon.appiconset",
                isDirectory: true)
try FileManager.default.createDirectory(at: saida, withIntermediateDirectories: true)
let clara = renderizar(.clara)
let escura = renderizar(.escura)
gravarPNG(clara, saida.appendingPathComponent("AppIcon.png"))
gravarPNG(escura, saida.appendingPathComponent("AppIcon-dark.png"))
gravarPNG(emTonsDeCinza(escura), saida.appendingPathComponent("AppIcon-tinted.png"))
print("ícones gerados em \(saida.path)")
