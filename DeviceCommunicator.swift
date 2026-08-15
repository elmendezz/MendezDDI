// DeviceCommunicator.swift
// MendezDDI - Version: 1.3.0
// Changelog:
// v1.2.0 - Clase para abstraer la comunicación real con el dispositivo.

import Foundation

/// Errores específicos de la comunicación con el dispositivo.
enum DeviceCommunicationError: Error, LocalizedError {
    case serviceConnectionFailed(serviceName: String)
    case deviceNotDetected
    case queryFailed(details: String)
    case mountFailed(details: String)
    case ddiFilesNotFound(version: String)

    var errorDescription: String? {
        switch self {
        case .serviceConnectionFailed(let serviceName):
            return "No se pudo conectar al servicio del dispositivo: \(serviceName)."
        case .deviceNotDetected:
            return "No se detectó ningún dispositivo conectado."
        case .queryFailed(let details):
            return "La consulta al dispositivo falló: \(details)."
        case .mountFailed(let details):
            return "El montaje de la imagen DDI falló: \(details)."
        case .ddiFilesNotFound(let version):
            return "No se encontraron los archivos DDI para la versión \(version) en la ruta de Xcode."
        }
    }
}

// Importamos el módulo que nos da acceso a las funciones de C de libimobiledevice.
import libimobiledevice

// Helper para convertir un `plist_t` de C a un diccionario de Swift [String: Any].
// Esta función es necesaria porque libimobiledevice devuelve los datos en su propio formato de Plist.
private func convertPlistToDictionary(_ plist: plist_t) -> [String: Any]? {
    var dict: [String: Any] = [:]
    var iterator: plist_dict_iter?
    plist_dict_new_iter(plist, &iterator)

    var key: UnsafeMutablePointer<CChar>?
    var value: plist_t?

    while true {
        plist_dict_next_item(plist, iterator, &key, &value)
        guard let currentKey = key, let currentValue = value else { break }
        
        let keyString = String(cString: currentKey)
        free(currentKey)

        switch plist_get_node_type(currentValue) {
        case .STRING:
            var val: UnsafeMutablePointer<CChar>?
            plist_get_string_val(currentValue, &val)
            if let cStr = val {
                dict[keyString] = String(cString: cStr)
                free(cStr)
            }
        case .UINT:
            var val: UInt64 = 0
            plist_get_uint_val(currentValue, &val)
            dict[keyString] = val
        case .BOOLEAN:
            var val: UInt8 = 0
            plist_get_bool_val(currentValue, &val)
            dict[keyString] = (val != 0)
        default:
            // Para otros tipos (Array, Data, etc.), se necesitaría más lógica de conversión.
            // Por ahora, nos centramos en los que necesitamos para la información del dispositivo.
            break
        }
    }
    
    free(iterator)
    return dict.isEmpty ? nil : dict
}

/// Protocolo que define la interfaz para un dispositivo.
protocol Device {
    var udid: String { get }
    func getProperties() async throws -> [String: Any]
    func isDDIMounted() async throws -> Bool
    func mountDDI(path: String, signature: Data, progressHandler: ((Double) -> Void)?) async throws
}

/// Implementación real de un dispositivo que utiliza `libimobiledevice` para la comunicación.
class RealDevice: Device {
    let udid: String

    init(udid: String) {
        self.udid = udid
    }
    
    /// Obtiene las propiedades del dispositivo conectándose al servicio `lockdownd`.
    func getProperties() async throws -> [String: Any] {
        var client: lockdownd_client_t? = nil
        var device: idevice_t? = nil

        // 1. Obtener el objeto del dispositivo a partir de su UDID.
        guard idevice_new(&device, udid) == IDEVICE_E_SUCCESS else {
            throw DeviceCommunicationError.deviceNotDetected
        }
        defer { idevice_free(device) }

        // 2. Conectar con el servicio `lockdownd` en el dispositivo.
        guard lockdownd_client_new_with_handshake(device, &client, "MendezDDI") == LOCKDOWN_E_SUCCESS else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: "lockdownd")
        }
        defer { lockdownd_client_free(client) }

        // 3. Solicitar todas las propiedades del dispositivo.
        var propertiesPlist: plist_t? = nil
        guard lockdownd_get_value(client, nil, nil, &propertiesPlist) == LOCKDOWN_E_SUCCESS, let properties = propertiesPlist else {
            throw DeviceCommunicationError.queryFailed(details: "No se pudieron obtener las propiedades del dispositivo.")
        }
        defer { plist_free(properties) }

        // 4. Convertir el plist de C a un diccionario de Swift y devolverlo.
        guard let propertiesDict = convertPlistToDictionary(properties) else {
            throw DeviceCommunicationError.queryFailed(details: "No se pudo convertir el plist de propiedades a diccionario.")
        }
        
        return propertiesDict
    }

    // NOTA: La implementación de `isDDIMounted` y `mountDDI` es compleja y requiere
    // una comunicación de bajo nivel con el servicio `mobile_image_mounter`.
    // Se deja como una simulación avanzada por ahora, ya que el código para manejar
    // el protocolo de montaje es extenso. La detección y obtención de propiedades ya son reales.
    func isDDIMounted() async throws -> Bool {
        var device: idevice_t? = nil
        var lockdown: lockdownd_client_t? = nil
        var service: lockdownd_service_descriptor_t? = nil
        var mim: mobile_image_mounter_client_t? = nil

        // 1. Obtener el objeto del dispositivo a partir de su UDID.
        guard idevice_new(&device, udid) == IDEVICE_E_SUCCESS else {
            throw DeviceCommunicationError.deviceNotDetected
        }
        defer { idevice_free(device) }

        // 2. Conectar con `lockdownd` para poder iniciar otros servicios.
        guard lockdownd_client_new_with_handshake(device, &lockdown, "MendezDDI") == LOCKDOWN_E_SUCCESS else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: "lockdownd")
        }
        defer { lockdownd_client_free(lockdown) }

        // 3. Iniciar el servicio `mobile_image_mounter` y obtener su puerto.
        let serviceName = "com.apple.mobile.mobile_image_mounter"
        guard lockdownd_start_service(lockdown, serviceName, &service) == LOCKDOWN_E_SUCCESS, let serviceDesc = service else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: serviceName)
        }
        defer { lockdownd_service_descriptor_free(serviceDesc) }

        // 4. Crear un cliente para el servicio `mobile_image_mounter`.
        guard mobile_image_mounter_new(device, serviceDesc, &mim) == MOBILE_IMAGE_MOUNTER_E_SUCCESS else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: serviceName)
        }
        defer { mobile_image_mounter_free(mim) }

        // 5. Enviar el comando "LookupImage" para el tipo de imagen "Developer".
        var resultPlist: plist_t? = nil
        guard mobile_image_mounter_lookup_image(mim, "Developer", &resultPlist) == MOBILE_IMAGE_MOUNTER_E_SUCCESS, let result = resultPlist else {
            throw DeviceCommunicationError.queryFailed(details: "No se pudo consultar el estado de la imagen DDI.")
        }
        defer { plist_free(result) }

        // 6. Analizar la respuesta. Si contiene la clave "ImageSignature", la imagen ya está montada.
        if let signatureNode = plist_dict_get_item(result, "ImageSignature") {
            plist_free(signatureNode) // Liberamos el nodo obtenido
            return true // La imagen está montada.
        }

        return false // La imagen no está montada.
    }

    func mountDDI(path: String, signature: Data, progressHandler: ((Double) -> Void)? = nil) async throws {
        var device: idevice_t? = nil
        var lockdown: lockdownd_client_t? = nil
        var service: lockdownd_service_descriptor_t? = nil
        var mim: mobile_image_mounter_client_t? = nil

        // 1. Obtener el objeto del dispositivo a partir de su UDID.
        guard idevice_new(&device, udid) == IDEVICE_E_SUCCESS else {
            throw DeviceCommunicationError.deviceNotDetected
        }
        defer { idevice_free(device) }

        // 2. Conectar con `lockdownd` para poder iniciar otros servicios.
        guard lockdownd_client_new_with_handshake(device, &lockdown, "MendezDDI") == LOCKDOWN_E_SUCCESS else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: "lockdownd")
        }
        defer { lockdownd_client_free(lockdown) }

        // 3. Iniciar el servicio `mobile_image_mounter` y obtener su puerto.
        let serviceName = "com.apple.mobile.mobile_image_mounter"
        guard lockdownd_start_service(lockdown, serviceName, &service) == LOCKDOWN_E_SUCCESS, let serviceDesc = service else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: serviceName)
        }
        defer { lockdownd_service_descriptor_free(serviceDesc) }

        // 4. Crear un cliente para el servicio `mobile_image_mounter`.
        guard mobile_image_mounter_new(device, serviceDesc, &mim) == MOBILE_IMAGE_MOUNTER_E_SUCCESS else {
            throw DeviceCommunicationError.serviceConnectionFailed(serviceName: serviceName)
        }
        defer { mobile_image_mounter_free(mim) }
        
        // 5. Leer el archivo .dmg y obtener su tamaño.
        guard (try? Data(contentsOf: URL(fileURLWithPath: path))) != nil else {
            throw DeviceCommunicationError.mountFailed(details: "No se pudo leer el archivo .dmg en \(path)")
        }

        // 6. Enviar el comando "MountImage" con los metadatos.
        let mountError = signature.withUnsafeBytes { (signaturePointer: UnsafeRawBufferPointer) -> mobile_image_mounter_error_t in
            let rawSignature = signaturePointer.bindMemory(to: CChar.self).baseAddress
            return mobile_image_mounter_mount_image(mim, path, rawSignature, UInt32(signature.count), "Developer", nil)
        }

        guard mountError == MOBILE_IMAGE_MOUNTER_E_SUCCESS else {
            throw DeviceCommunicationError.mountFailed(details: "No se pudo iniciar el comando de montaje. Código: \(mountError.rawValue)")
        }

        // 7. Transferir el archivo .dmg en bloques y reportar el progreso.
        // NOTA: La función `mobile_image_mounter_mount_image` es bloqueante y no ofrece un callback de progreso fácil.
        // La barra de progreso se completará al 100% al finalizar la transferencia.
        // Para un progreso real, se necesitaría una implementación de sockets más compleja.
        progressHandler?(1.0) // Aseguramos que llegue al 100%

        // 8. Finalizar la transferencia y esperar la respuesta final del servicio.
        // La función `mobile_image_mounter_mount_image` ya espera la respuesta, pero podemos verificar el estado si es necesario.

        // 9. Analizar la respuesta final para confirmar que el montaje fue exitoso.
        // Si la función `mobile_image_mounter_mount_image` devolvió SUCCESS, el montaje fue exitoso.
    }
}

/// Contiene la lógica de bajo nivel para interactuar con los servicios del dispositivo (lockdownd, etc.).
final class DeviceCommunicator {
    
    /// Detecta el primer dispositivo conectado usando `libimobiledevice`.
    /// - Returns: Una instancia de `Device` que representa el dispositivo encontrado.
    func detectDevice() async throws -> Device {
        var devices: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        var count: Int32 = 0

        // 1. Llamar a la función de C para obtener la lista de UDIDs de dispositivos.
        let result = idevice_get_device_list(&devices, &count)

        // 2. Verificar si la llamada fue exitosa y si se encontró al menos un dispositivo.
        guard result == IDEVICE_E_SUCCESS, count > 0, let deviceList = devices else {
            throw DeviceCommunicationError.deviceNotDetected
        }

        // 3. Tomar el UDID del primer dispositivo de la lista.
        guard let firstDeviceUDID_c = deviceList[0] else {
            idevice_device_list_free(devices)
            throw DeviceCommunicationError.deviceNotDetected
        }

        let detectedUDID = String(cString: firstDeviceUDID_c)

        // 4. Liberar la memoria utilizada por la lista de dispositivos de C.
        idevice_device_list_free(devices)

        guard !detectedUDID.isEmpty else {
            throw DeviceCommunicationError.deviceNotDetected
        }

        print("Communicator: Dispositivo detectado con UDID: \(detectedUDID)")
        return RealDevice(udid: detectedUDID)
    }

    /// Verifica si una imagen DDI ya está montada.
    /// - Parameter device: El dispositivo a verificar.
    /// - Returns: `true` si está montado, de lo contrario `false`.
    func isDDIMounted(device: Device) async throws -> Bool {
        return try await device.isDDIMounted()
    }

    /// Monta una imagen DDI en el dispositivo.
    /// - Parameters:
    ///   - device: El dispositivo donde se montará la imagen.
    ///   - ddiPath: La ruta al archivo .dmg del DDI.
    ///   - signaturePath: La ruta al archivo .signature del DDI.
    func mountDDI(device: Device, ddiPath: String, signaturePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let signatureData = FileManager.default.contents(atPath: signaturePath) else {
            throw DeviceCommunicationError.mountFailed(details: "No se pudo leer el archivo de firma en \(signaturePath)")
        }
        try await device.mountDDI(path: ddiPath, signature: signatureData, progressHandler: progressHandler)
    }
}