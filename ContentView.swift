// ContentView.swift
// MendezDDI - Version: 1.2.0
// Changelog:
// v1.2.0 - Integración con DeviceCommunicator y paso de UDID.
// v1.0.0 - Interfaz de usuario en SwiftUI respetando la consola y componentes estáticos.

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var ddiManager = DDIManager()
    @State private var isPairingValid: Bool = false
    @State private var showFileImporter: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("MendezDDI")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Tarjeta de Dispositivo
            VStack(alignment: .leading, spacing: 8) {
                Text("Device")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(ddiManager.deviceInfo)
                            .font(.headline)
                        Text("iOS \(ddiManager.iosVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(isPairingValid ? "🟢 Pairing válido" : "🔴 Sin Pairing")
                        .font(.caption)
                        .padding(6)
                        .background(isPairingValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .cornerRadius(12)
            .padding(.horizontal)

            // Estado de DDI
            VStack(alignment: .leading, spacing: 8) {
                Text("DDI Status")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text("Developer Mode:")
                    Spacer()
                    Text(ddiManager.isDeveloperModeEnabled ? "🟢 Activo" : "🔴 Inactivo")
                }
                .font(.subheadline)

                HStack {
                    Text("DDI Status:")
                    Spacer()
                    switch ddiManager.ddiStatus {
                    case .mounted:
                        Text("🟢 DDI montado").bold()
                    case .notMounted:
                        Text("🟡 DDI no montado").bold()
                    case .unknown:
                        Text("⚪ Estado desconocido")
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .cornerRadius(12)
            .padding(.horizontal)

            // Botones de Acción
            HStack(spacing: 12) {
                Button(action: { showFileImporter = true }) {
                    Label("Importar Pairing", systemImage: "doc.badge.plus")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    Task {
                        await ddiManager.mountDDI()
                    }
                }) {
                    Label("Montar DDI", systemImage: "play.fill")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!isPairingValid)
            }
        .padding(.horizontal)
        
        // Barra de Progreso (visible solo durante el montaje)
        if ddiManager.isMounting {
            ProgressView("Montando DDI...", value: ddiManager.mountProgress, total: 1.0)
                .padding(.horizontal)
        }

            .padding(.horizontal)

            Button(action: {
                Task {
                    await ddiManager.detectDevice()
                    await loadExistingPairing()
                    _ = await ddiManager.checkDDIMounted()
                }
            }) {
                Label("Verificar Dispositivo", systemImage: "arrow.clockwise")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            // Consola de Logs (Texto estático/scrollable sin animaciones no deseadas)
            VStack(alignment: .leading, spacing: 4) {
                Text("Logs")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(ddiManager.logs) { logEntry in
                            Text("[\(logEntry.timestamp)] \(logEntry.message)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(colorForLog(type: logEntry.type))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(8)
                .background(Color.black)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                guard let selectedFile = files.first else { return }
                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: selectedFile) {
                        do {
                            let record = try PairingManager.shared.processPairingData(data)
                            if record.isValid {
                                self.isPairingValid = true
                                ddiManager.log("Pairing cargado con éxito para UDID: \(record.udid)", type: .success)
                            } else {
                                self.isPairingValid = false
                                ddiManager.log("El registro de pairing no es válido.", type: .error)
                            }
                        } catch {
                            ddiManager.log("Error al procesar el pairing: \(error.localizedDescription)", type: .error)
                        }
                    }
                }
            case .failure(let error):
                ddiManager.log("Error al seleccionar archivo: \(error.localizedDescription)", type: .error)
            }
        }
        .onAppear {
            // Al iniciar la app, verificamos automáticamente el dispositivo y su pairing.
            Task {
                await ddiManager.detectDevice()
                await loadExistingPairing()
                _ = await ddiManager.checkDDIMounted()
            }
        }
    }

    private func colorForLog(type: LogType) -> Color {
        switch type {
        case .info: return .white
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        }
    }

    private func loadExistingPairing() async {
        guard let udid = ddiManager.detectedDevice?.udid, !udid.isEmpty else {
            ddiManager.log("No se ha detectado un UDID para buscar el pairing.", type: .warning)
            self.isPairingValid = false
            return
        }

        self.isPairingValid = false // Reseteamos el estado antes de buscar
        ddiManager.log("Buscando pairing existente para UDID: \(udid)...", type: .info)
        do {
            // Intentamos cargar el pairing y procesarlo para validar su contenido
            let pairingData = try PairingManager.shared.loadPairingRecord(for: udid)
            let record = try PairingManager.shared.processPairingData(pairingData)
            self.isPairingValid = record.isValid
            ddiManager.log("Pairing válido encontrado y cargado desde el Keychain.", type: .success)
        } catch let error as PairingError where error.localizedDescription == PairingError.itemNotFound.localizedDescription {
            // Este es un caso esperado, no un error crítico.
            self.isPairingValid = false
            ddiManager.log("No se encontró un pairing para este dispositivo.", type: .warning)
        } catch {
            self.isPairingValid = false
            ddiManager.log("Error al cargar el pairing: \(error.localizedDescription)", type: .error)
        }
    }
}
