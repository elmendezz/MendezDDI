import SwiftUI
import UniformTypeIdentifiers

// Changelog
// Version: 1.0.0
// - Vista principal UI con tarjetas interactivas y terminal de logs

struct ContentView: View {
    @StateObject private var pairingStore = PairingStore()
    @StateObject private var ddiManager = DDIManager()
    @StateObject private var vpnManager = LocalVPNManager()
    @StateObject private var diagnostics = Diagnostics()

    @State private var isImporterPresented = false
    @State private var logOutput: String = "MendezDDI listo.\n"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pairing File")
                                .font(.headline)
                            Spacer()
                            Circle()
                                .fill(pairingStore.isValid ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                        }
                        
                        if pairingStore.isValid, let info = pairingStore.pairingInfo {
                            Text("🟢 Pairing file cargado")
                                .foregroundColor(.green)
                                .bold()
                            Text("Device UDID: \(info.udid.prefix(8))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("🔴 No hay pairing válido")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: { isImporterPresented = true }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Importar nuevo pairing")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LocalDevVPN / Red")
                                .font(.headline)
                            Spacer()
                            Circle()
                                .fill(vpnManager.status == .connected ? Color.green : Color.orange)
                                .frame(width: 12, height: 12)
                        }
                        
                        HStack {
                            Text("Estado VPN:")
                            Spacer()
                            Text(vpnManager.status.rawValue)
                                .bold()
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acción DDI")
                            .font(.headline)
                        
                        HStack {
                            Text("Estado DDI:")
                            Spacer()
                            Text(ddiManager.mountState)
                                .bold()
                        }
                        .font(.subheadline)

                        Button(action: {
                            Task {
                                appendLog("Iniciando flujo de montaje DDI...")
                                if let pair = pairingStore.pairingInfo {
                                    await ddiManager.startMountProcess(pairing: pair)
                                } else {
                                    appendLog("ERROR: Importa un pairing file primero.")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "externaldrive.badge.wifi")
                                Text("MONTAR DDI")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pairingStore.isValid ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!pairingStore.isValid || ddiManager.isProcessing)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terminal de Salida")
                            .font(.headline)
                        
                        TextEditor(text: $logOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 180)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("MendezDDI")
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if pairingStore.importPairing(from: url) {
                        appendLog("Pairing file cargado exitosamente.")
                    } else {
                        appendLog("ERROR: El archivo de pairing no es válido.")
                    }
                case .failure(let err):
                    appendLog("Error importando archivo: \(err.localizedDescription)")
                }
            }
            .onReceive(ddiManager.$logMessage) { msg in
                if !msg.isEmpty { appendLog(msg) }
            }
        }
    }

    private func appendLog(_ text: String) {
        logOutput += "[\(Date().formatted(date: .omitted, time: .standard))] \(text)\n"
    }
}