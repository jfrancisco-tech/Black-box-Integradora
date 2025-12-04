import UIKit
import UserNotifications

// MARK: - 1. ESTRUCTURAS DE DATOS (MODELOS)
// EXPLICACION: Estas estructuras mapean el JSON que llega de la API a objetos de Swift.

struct UltimoEstadoResponse: Codable {
    let id_bloque: String
    let hora_lectura: String
    let datos: DatosSensores
}

struct DatosSensores: Codable {
    let temperatura: Double
    let humedad: Double
    let distancia: Double
    let puerta_abierta: Bool
    let vibracion: Bool
    let alarma_activa: Bool
    let intentos: Int?
}

struct EventoHistorial: Codable {
    let mensaje: String
    let hora: String
    let timestamp: Int64?
}

// MARK: - 2. CLASE PRINCIPAL
class ViewController: UIViewController, UNUserNotificationCenterDelegate {

    // MARK: - IBOUTLETS (Conexiones con la interfaz gráfica)
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var lockButton: UIButton!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var humLabel: UILabel!
    @IBOutlet weak var vibrationLabel: UILabel!
    @IBOutlet weak var proximityLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var passwordTextField: UITextField!
    
    // MARK: - VARIABLES DE ESTADO
    var isLocked = true
    let baseUrl = "https://api-sensores-348016469746.us-central1.run.app"
    
    // EXPLICACION: Umbrales de Histeresis para evitar lecturas falsas y spam.
    // Se definen limites altos para activar la alarma y bajos para desactivarla.
    let LIMITE_DISTANCIA = 15.0
    let LIMITE_TEMP_ALTA = 30.0
    let LIMITE_TEMP_BAJA = 28.0 // Temperatura debe bajar hasta aqui para resetear la alerta
    let LIMITE_HUM_ALTA = 80.0
    let LIMITE_HUM_BAJA = 75.0 // Humedad debe bajar hasta aqui para resetear la alerta
    
    // Banderas de estado para controlar el flujo de notificaciones locales
    var yaNotifiqueRobo = false
    var yaNotifiqueAlarma = false
    var yaNotifiqueTemp = false
    var yaNotifiqueHum = false
    
    // MARK: - LIFECYCLE (Ciclo de vida de la pantalla)
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configurar delegado para permitir notificaciones aun con la app abierta
        UNUserNotificationCenter.current().delegate = self
        
        setupDesign()
        solicitarPermisosNotificacion()
        
        print("SISTEMA INICIADO: Vista cargada correctamente")
        
        // Primera carga de datos
        fetchUltimoEstado()
        
        // EXPLICACION: Timer que consulta la API cada 3 segundos (Polling)
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchUltimoEstado()
        }
        
        configurarGestos()
    }
    
    // Metodo para manejar notificaciones en primer plano (Foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    func setupDesign() {
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Fondo oscuro profesional
        actualizarBotonVisualmente()
        statusLabel.text = "Ver registro de actividad"
    }
    
    func configurarGestos() {
        // Ocultar teclado al tocar fuera de los campos de texto
        let tapView = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapView)
    }
    
    func solicitarPermisosNotificacion() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted { print("Permiso de notificaciones concedido") }
        }
    }
    
    @objc func dismissKeyboard() { view.endEditing(true) }

    // MARK: - CONSUMIR API (Networking)
    
    func fetchUltimoEstado() {
        guard let url = URL(string: "\(baseUrl)/api/ultimo-estado") else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                let respuesta = try decoder.decode(UltimoEstadoResponse.self, from: data)
                
                // EXPLICACION: Las actualizaciones de UI deben hacerse en el hilo principal
                DispatchQueue.main.async {
                    self?.actualizarInterfaz(con: respuesta.datos)
                }
            } catch { print("Error decodificando respuesta API: \(error)") }
        }
        task.resume()
    }
    
    // MARK: - LÓGICA DE INTERFAZ Y ALERTAS
    
    func actualizarInterfaz(con d: DatosSensores) {
        self.isLocked = !d.puerta_abierta
        actualizarBotonVisualmente()
        
        // 1. Actualizacion de etiquetas de TEMPERATURA
        tempLabel.text = String(format: "%.1f C", d.temperatura)
        if d.temperatura >= LIMITE_TEMP_ALTA {
            tempLabel.textColor = .systemRed
        } else {
            tempLabel.textColor = .white
        }
        
        // 2. Actualizacion de etiquetas de HUMEDAD
        humLabel.text = "\(Int(d.humedad))%"
        if d.humedad > LIMITE_HUM_ALTA {
            humLabel.textColor = .systemBlue
        } else {
            humLabel.textColor = .white
        }
        
        // 3. Actualizacion de DISTANCIA y Estado del Objeto
        distanceLabel.text = "\(Int(d.distancia)) cm"
        
        // EXPLICACION: Validacion de presencia. Debe ser > 1.0 para descartar errores de lectura (0.0)
        if d.distancia > 1.0 && d.distancia < LIMITE_DISTANCIA {
            proximityLabel.text = "OBJETO SEGURO"
            proximityLabel.textColor = .systemGreen
            yaNotifiqueRobo = false // Se resetea la bandera si el objeto regresa
        } else {
            proximityLabel.text = "SIN OBJETO / RETIRADO"
            proximityLabel.textColor = .systemRed
        }
        
        // 4. Estado de VIBRACION
        if d.vibracion {
            vibrationLabel.text = "ALERTA"
            vibrationLabel.textColor = .systemRed
        } else {
            vibrationLabel.text = "Estable"
            vibrationLabel.textColor = .systemGreen
        }
        
        // Llamada a la logica de notificaciones push
        gestionarNotificaciones(d)
    }
    
    func gestionarNotificaciones(_ datos: DatosSensores) {
        
        // CASO A: ROBO DETECTADO
        // Se activa si la distancia supera el limite o es 0 (lectura vacia/error critico)
        let esRobo = datos.distancia >= LIMITE_DISTANCIA || datos.distancia == 0
        if esRobo {
            if !yaNotifiqueRobo {
                enviarNotificacionLocal(titulo: "ALERTA: OBJETO FALTANTE", cuerpo: "La caja esta vacia o el objeto fue retirado.")
                yaNotifiqueRobo = true
            }
        }
        
        // CASO B: ALARMA FISICA ACTIVADA
        if datos.alarma_activa {
            if !yaNotifiqueAlarma {
                enviarNotificacionLocal(titulo: "ALERTA: ALARMA SONANDO", cuerpo: "Se ha activado la sirena de seguridad.")
                yaNotifiqueAlarma = true
            }
        } else {
            yaNotifiqueAlarma = false
        }
        
        // CASO C: TEMPERATURA (Con Histeresis)
        // Solo notifica si sube de 30. Solo resetea si baja de 28.
        if datos.temperatura >= LIMITE_TEMP_ALTA {
            if !yaNotifiqueTemp {
                enviarNotificacionLocal(titulo: "ALERTA: TEMPERATURA CRITICA", cuerpo: "La temperatura subio a \(datos.temperatura) C. Riesgo para el contenido.")
                yaNotifiqueTemp = true
            }
        } else if datos.temperatura < LIMITE_TEMP_BAJA {
            yaNotifiqueTemp = false // Resetear bandera
        }
        
        // CASO D: HUMEDAD (Con Histeresis)
        // Solo notifica si sube de 80. Solo resetea si baja de 75.
        if datos.humedad > LIMITE_HUM_ALTA {
            if !yaNotifiqueHum {
                enviarNotificacionLocal(titulo: "ALERTA: HUMEDAD CRITICA", cuerpo: "Humedad critica del \(Int(datos.humedad))%. Riesgo de daño.")
                yaNotifiqueHum = true
            }
        } else if datos.humedad < LIMITE_HUM_BAJA {
            yaNotifiqueHum = false // Resetear bandera
        }
    }
    
    func enviarNotificacionLocal(titulo: String, cuerpo: String) {
        let content = UNMutableNotificationContent()
        content.title = titulo
        content.body = cuerpo
        content.sound = UNNotificationSound.defaultCritical
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - COMANDOS A LA API
    
    func enviarComandoServo(accion: String) {
        guard let url = URL(string: "\(baseUrl)/api/control-servo") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["accion": accion]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func enviarCambioClave(nuevaClave: String) {
        guard let url = URL(string: "\(baseUrl)/api/cambiar-clave") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["nuevaClave": nuevaClave]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async { self?.mostrarAlerta(titulo: "Exito", mensaje: "Clave actualizada correctamente.") }
            }
        }.resume()
    }
    
    // MARK: - ACTIONS (Botones)
    
    @IBAction func abrirHistorialTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "HistorialStoryBoard", bundle: nil)
        if let historialVC = storyboard.instantiateViewController(withIdentifier: "HistorialViewController") as? HistorialViewController {
            present(historialVC, animated: true)
        }
    }
    
    @objc func abrirHistorial() { abrirHistorialTapped(UIButton()) }

    @IBAction func lockTapped(_ sender: UIButton) {
        isLocked.toggle()
        actualizarBotonVisualmente()
        let comando = isLocked ? "CERRAR" : "ABRIR"
        enviarComandoServo(accion: comando)
    }
    
    @IBAction func changePasswordTapped(_ sender: UIButton) {
        // EXPLICACION: Validacion local antes de enviar a la red
        guard let nuevaClave = passwordTextField.text, nuevaClave.count == 4 else {
            mostrarAlerta(titulo: "Error de Formato", mensaje: "La contraseña debe tener exactamente 4 digitos.")
            return
        }
        enviarCambioClave(nuevaClave: nuevaClave)
        passwordTextField.text = ""; dismissKeyboard()
    }
    
    @IBAction func logoutTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Cerrar Sesion", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Salir", style: .destructive, handler: { _ in
            let storyboard = UIStoryboard(name: "LoginStoryBoard", bundle: nil)
            if let loginVC = storyboard.instantiateInitialViewController() {
                loginVC.modalPresentationStyle = .fullScreen
                self.present(loginVC, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    func mostrarAlerta(titulo: String, mensaje: String) {
        let alert = UIAlertController(title: titulo, message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func actualizarBotonVisualmente() {
        let texto = isLocked ? " CERRADO" : " ABIERTO"
        let imagenNombre = isLocked ? "lock.fill" : "lock.open.fill"
        let color = isLocked ? UIColor.systemBlue : UIColor.systemGreen
        
        if #available(iOS 15.0, *) {
            var config = lockButton.configuration ?? UIButton.Configuration.filled()
            config.title = texto
            config.image = UIImage(systemName: imagenNombre)
            config.baseForegroundColor = color
            lockButton.configuration = config
        } else {
            // Fallback para versiones antiguas de iOS
            lockButton.setTitle(texto, for: .normal)
            lockButton.setImage(UIImage(systemName: imagenNombre), for: .normal)
            lockButton.tintColor = color
        }
        lockButton.layer.borderColor = color.cgColor
        lockButton.layer.borderWidth = 1.0
        lockButton.layer.cornerRadius = 10
    }
}
