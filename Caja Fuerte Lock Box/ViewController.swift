import UIKit
import UserNotifications

// MARK: - 1. ESTRUCTURAS DE DATOS (MODELOS)
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

// MARK: - 2. CLASE PRINCIPAL (ACTUALIZADA)
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
    private var pollingTimer: Timer?
    private var cornerLogoutButton: UIButton?
    
    let LIMITE_DISTANCIA = 15.0
    let LIMITE_TEMP_ALTA = 30.0
    let LIMITE_TEMP_BAJA = 28.0
    let LIMITE_HUM_ALTA = 80.0
    let LIMITE_HUM_BAJA = 75.0
    
    var yaNotifiqueRobo = false
    var yaNotifiqueAlarma = false
    var yaNotifiqueTemp = false
    var yaNotifiqueHum = false
    
    // MARK: - LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UNUserNotificationCenter.current().delegate = self
        
        setupDesign()
        solicitarPermisosNotificacion()
        
        fetchUltimoEstado()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchUltimoEstado()
        }
        
        configurarGestos()
        setupCornerLogoutButton()
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    func setupDesign() {
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        actualizarBotonVisualmente()
        statusLabel.text = "Ver registro de actividad"
    }
    
    func configurarGestos() {
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
        
        tempLabel.text = String(format: "%.1f C", d.temperatura)
        tempLabel.textColor = d.temperatura >= LIMITE_TEMP_ALTA ? .systemRed : .white
        
        humLabel.text = "\(Int(d.humedad))%"
        humLabel.textColor = d.humedad > LIMITE_HUM_ALTA ? .systemBlue : .white
        
        distanceLabel.text = "\(Int(d.distancia)) cm"
        
        if d.distancia > 1.0 && d.distancia < LIMITE_DISTANCIA {
            proximityLabel.text = "OBJETO SEGURO"
            proximityLabel.textColor = .systemGreen
            yaNotifiqueRobo = false
        } else {
            proximityLabel.text = "SIN OBJETO / RETIRADO"
            proximityLabel.textColor = .systemRed
        }
        
        if d.vibracion {
            vibrationLabel.text = "ALERTA"
            vibrationLabel.textColor = .systemRed
        } else {
            vibrationLabel.text = "Estable"
            vibrationLabel.textColor = .systemGreen
        }
        
        gestionarNotificaciones(d)
    }
    
    func gestionarNotificaciones(_ datos: DatosSensores) {
        let esRobo = datos.distancia >= LIMITE_DISTANCIA || datos.distancia == 0
        if esRobo {
            if !yaNotifiqueRobo {
                enviarNotificacionLocal(titulo: "ALERTA: OBJETO FALTANTE", cuerpo: "La caja esta vacia o el objeto fue retirado.")
                yaNotifiqueRobo = true
            }
        }
        if datos.alarma_activa {
            if !yaNotifiqueAlarma {
                enviarNotificacionLocal(titulo: "ALERTA: ALARMA SONANDO", cuerpo: "Se ha activado la sirena de seguridad.")
                yaNotifiqueAlarma = true
            }
        } else { yaNotifiqueAlarma = false }
        
        if datos.temperatura >= LIMITE_TEMP_ALTA {
            if !yaNotifiqueTemp {
                enviarNotificacionLocal(titulo: "ALERTA: TEMPERATURA CRITICA", cuerpo: "La temperatura subio a \(datos.temperatura) C. Riesgo para el contenido.")
                yaNotifiqueTemp = true
            }
        } else if datos.temperatura < LIMITE_TEMP_BAJA {
            yaNotifiqueTemp = false
        }
        
        if datos.humedad > LIMITE_HUM_ALTA {
            if !yaNotifiqueHum {
                enviarNotificacionLocal(titulo: "ALERTA: HUMEDAD CRITICA", cuerpo: "Humedad critica del \(Int(datos.humedad))%. Riesgo de daño.")
                yaNotifiqueHum = true
            }
        } else if datos.humedad < LIMITE_HUM_BAJA {
            yaNotifiqueHum = false
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
        guard let nuevaClave = passwordTextField.text, nuevaClave.count == 4 else {
            mostrarAlerta(titulo: "Error de Formato", mensaje: "La contraseña debe tener exactamente 4 digitos.")
            return
        }
        enviarCambioClave(nuevaClave: nuevaClave)
        passwordTextField.text = ""; dismissKeyboard()
    }
    
    // MARK: - LOGOUT (mejorado y dinámico)
    @IBAction func logoutTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Cerrar Sesion", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Salir", style: .destructive, handler: { [weak self] _ in
            self?.performLogout()
        }))
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(alert, animated: true)
    }
    
    func performLogout() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        yaNotifiqueAlarma = false
        yaNotifiqueHum = false
        yaNotifiqueRobo = false
        yaNotifiqueTemp = false
        
        let keysToRemove = ["auth_token", "last_user", "last_device"]
        let ud = UserDefaults.standard
        keysToRemove.forEach { ud.removeObject(forKey: $0) }
        ud.synchronize()
        
        // Intentar reemplazar rootViewController (iOS 13+)
        if #available(iOS 13.0, *) {
            if let scene = view.window?.windowScene {
                for window in scene.windows where window.isKeyWindow {
                    let storyboard = UIStoryboard(name: "LoginStoryBoard", bundle: nil)
                    if let loginRoot = storyboard.instantiateInitialViewController() {
                        window.rootViewController = loginRoot
                        UIView.transition(with: window, duration: 0.35, options: [.transitionFlipFromLeft], animations: nil)
                        return
                    }
                }
            }
        }
        
        // Fallback: presentar el login modally (si no pudimos cambiar root)
        let storyboard = UIStoryboard(name: "LoginStoryBoard", bundle: nil)
        if let loginVC = storyboard.instantiateInitialViewController() {
            loginVC.modalPresentationStyle = .fullScreen
            present(loginVC, animated: true)
            return
        }
        
        // Último recurso: instanciar desde "Main" usando instantiateViewController:
        // instantiateViewController(withIdentifier:) ya devuelve UIViewController, así que no necesitamos castear a UIViewController (cast redundante).
        // Opción A (recomendada si la escena tiene Storyboard ID "LoginViewController"):
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = mainStoryboard.instantiateViewController(withIdentifier: "LoginViewController")
        loginVC.modalPresentationStyle = .fullScreen
        present(loginVC, animated: true)
        
        // Opción B (si prefieres castear a la clase específica):
        // if let loginVC = mainStoryboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
        //     loginVC.modalPresentationStyle = .fullScreen
        //     present(loginVC, animated: true)
        // }
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
            lockButton.setTitle(texto, for: .normal)
            lockButton.setImage(UIImage(systemName: imagenNombre), for: .normal)
            lockButton.tintColor = color
        }
        lockButton.layer.borderColor = color.cgColor
        lockButton.layer.borderWidth = 1.0
        lockButton.layer.cornerRadius = 10
    }
    
    // MARK: - BOTÓN DE LOGOUT EN ESQUINA (RESPONSIVO)
    private func setupCornerLogoutButton() {
        if cornerLogoutButton != nil { return }
        
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        btn.setImage(UIImage(systemName: "power", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0.12, alpha: 0.6)
        btn.layer.cornerRadius = 18
        btn.layer.masksToBounds = true
        btn.accessibilityLabel = "Cerrar sesión"
        btn.addTarget(self, action: #selector(cornerLogoutTapped(_:)), for: .touchUpInside)
        
        view.addSubview(btn)
        cornerLogoutButton = btn
        
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 36),
            btn.heightAnchor.constraint(equalToConstant: 36),
            btn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
        
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
    }
    
    @objc private func cornerLogoutTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Cerrar sesión", message: "¿Deseas cerrar sesión y volver al login?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cerrar sesión", style: .destructive, handler: { [weak self] _ in
            self?.performLogout()
        }))
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = sender; pop.sourceRect = sender.bounds }
        present(alert, animated: true)
    }
}
