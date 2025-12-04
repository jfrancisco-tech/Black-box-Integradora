import UIKit

// MARK: - 1. ESTRUCTURAS DE DATOS
struct UltimoEstadoResponse: Codable {
    let fecha_bloque: String
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
    let fecha_bloque: String
}

// MARK: - 2. CLASE PRINCIPAL
class ViewController: UIViewController {

    // MARK: - IBOUTLETS
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
    
    // Variables para cachear datos
    var ultimosDatos: DatosSensores?
    var ultimoHistorial: EventoHistorial?

    // MARK: - LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesign()
        
        print("🚀 SISTEMA INICIADO: Conectando a la nube...")
        
        // Primera carga inmediata
        fetchUltimoEstado()
        
        // Timer: Actualiza estado cada 3 segundos
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchUltimoEstado()
        }
        
        configurarGestos()
    }
    
    func setupDesign() {
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        actualizarBotonVisualmente()
    }
    
    func configurarGestos() {
        statusLabel.isUserInteractionEnabled = true
        let tapLabel = UITapGestureRecognizer(target: self, action: #selector(abrirHistorial))
        statusLabel.addGestureRecognizer(tapLabel)
        
        let tapView = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapView)
    }
    
    @objc func dismissKeyboard() { view.endEditing(true) }

    // MARK: - CONSUMIR API
    
    func fetchUltimoEstado() {
        guard let url = URL(string: "\(baseUrl)/api/ultimo-estado") else { return }

        // 1. Obtener Sensores
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                let respuesta = try decoder.decode(UltimoEstadoResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self?.ultimosDatos = respuesta.datos
                    self?.actualizarInterfaz(con: respuesta.datos)
                }
            } catch { print("Error decodificando sensores: \(error)") }
        }
        task.resume()
        
        // 2. Obtener Historial
        guard let urlHistorial = URL(string: "\(baseUrl)/api/historial") else { return }
        URLSession.shared.dataTask(with: urlHistorial) { [weak self] data, _, _ in
            guard let data = data else { return }
            if let lista = try? JSONDecoder().decode([EventoHistorial].self, from: data), let ultimo = lista.first {
                DispatchQueue.main.async {
                    self?.ultimoHistorial = ultimo
                    if let sensores = self?.ultimosDatos {
                        self?.actualizarEstadoPrincipal(sensores: sensores)
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - LÓGICA DE INTERFAZ
    
    func actualizarInterfaz(con d: DatosSensores) {
        self.isLocked = !d.puerta_abierta
        actualizarBotonVisualmente()
        
        // Etiquetas pequeñas
        tempLabel.text = String(format: "%.1f°C", d.temperatura)
        humLabel.text = "\(Int(d.humedad))%"
        distanceLabel.text = "\(Int(d.distancia)) cm"
        
        // Colores en etiquetas pequeñas según umbrales
        if d.distancia < 19.0 {
            proximityLabel.text = "OBJETO SEGURO"; proximityLabel.textColor = .systemGreen
        } else {
            proximityLabel.text = "OBJETO RETIRADO"; proximityLabel.textColor = .systemRed
        }
        
        if d.vibracion {
            vibrationLabel.text = "¡ALERTA!"; vibrationLabel.textColor = .systemRed
        } else {
            vibrationLabel.text = "Estable"; vibrationLabel.textColor = .systemGreen
        }
        
        // Si hay temperatura extrema, pintar el label pequeño de rojo también
        tempLabel.textColor = d.temperatura >= 30.0 ? .systemRed : .white
        
        // 🔥 ACTUALIZAR EL TEXTO GRANDE (LÓGICA CENTRAL)
        actualizarEstadoPrincipal(sensores: d)
    }

    // ✅ LÓGICA CORREGIDA: AZUL PARA CERRADO Y HORA EXACTA DEL HISTORIAL
    func actualizarEstadoPrincipal(sensores: DatosSensores) {
        let horaActual = obtenerHoraActual()
        
        // ---------------------------------------------------------
        // 1. NIVEL CRÍTICO (EN VIVO) - SI ESTÁ PASANDO AHORA
        // ---------------------------------------------------------
        if sensores.alarma_activa {
            mostrarTextoEnPantalla(titulo: "🚨 ALARMA SONANDO", hora: horaActual, color: .systemRed)
            return
        }
        
        // Alerta de Temperatura (>= 30 grados)
        if sensores.temperatura >= 30.0 {
            mostrarTextoEnPantalla(titulo: "🔥 ALTA TEMPERATURA", hora: horaActual, color: .systemRed)
            return
        }
        
        // Alerta de Humedad (> 80%)
        if sensores.humedad > 80.0 {
            mostrarTextoEnPantalla(titulo: "💧 ALERTA HUMEDAD", hora: horaActual, color: .systemRed)
            return
        }
        
        // Vibración activa
        if sensores.vibracion {
            mostrarTextoEnPantalla(titulo: "📳 VIBRACIÓN DETECTADA", hora: horaActual, color: .systemRed)
            return
        }
        
        // Robo de objeto (Distancia >= 19cm significa que quitaron el objeto)
        if sensores.distancia >= 19.0 {
            mostrarTextoEnPantalla(titulo: "⚠️ OBJETO SUSTRAÍDO", hora: horaActual, color: .systemRed)
            return
        }
        
        // ---------------------------------------------------------
        // 2. NIVEL ADVERTENCIA (INTENTOS FALLIDOS)
        // ---------------------------------------------------------
        if let intentos = sensores.intentos, intentos > 0 {
            mostrarTextoEnPantalla(titulo: "🔐 CLAVE INCORRECTA (\(intentos))", hora: horaActual, color: .systemRed)
            return
        }

        // ---------------------------------------------------------
        // 3. NIVEL HISTORIAL (SOLO SI ES UNA ALERTA RECIENTE)
        // ---------------------------------------------------------
        if let ultimo = self.ultimoHistorial {
            let msg = ultimo.mensaje.uppercased()
            
            // Si hay una alerta en el historial que queramos persistir
            if msg.contains("ROBO") ||
               msg.contains("VIBRACION") ||
               msg.contains("VIBRACIÓN") ||
               msg.contains("RETIRADO") ||
               msg.contains("INTENTO") ||
               msg.contains("ALARMA") {
                
                // Usamos ultimo.hora para mostrar la hora EXACTA del evento
                mostrarTextoEnPantalla(titulo: ultimo.mensaje, hora: ultimo.hora, color: .systemRed)
                return
            }
        }
        
        // ---------------------------------------------------------
        // 4. NIVEL NORMAL (ESTADO REAL DE PUERTA)
        // ---------------------------------------------------------
        if sensores.puerta_abierta {
            // Puerta Abierta -> Verde
            mostrarTextoEnPantalla(titulo: "🔓 Puerta Abierta", hora: horaActual, color: .systemGreen)
        } else {
            // Puerta Cerrada -> AZUL (.systemBlue)
            
            // Intentamos buscar la hora exacta del cierre en el historial
            var horaCierre = horaActual
            if let ultimo = self.ultimoHistorial {
                let msg = ultimo.mensaje.uppercased()
                // Si el último mensaje fue sobre la puerta, usamos esa hora
                if msg.contains("PUERTA") || msg.contains("CERRAR") {
                    horaCierre = ultimo.hora
                }
            }
            
            mostrarTextoEnPantalla(titulo: "🔒 Puerta Cerrada", hora: horaCierre, color: .systemBlue)
        }
    }

    // He modificado esta función para aceptar un UIColor directamente
    func mostrarTextoEnPantalla(titulo: String, hora: String, color: UIColor) {
        let textoCompleto = "\(titulo)\n\(hora) • Ver Historial ›"
        let attributedString = NSMutableAttributedString(string: textoCompleto)
        
        let rangoEnter = (textoCompleto as NSString).range(of: "\n")
        
        if rangoEnter.location != NSNotFound {
            let rangoTitulo = NSRange(location: 0, length: rangoEnter.location)
            let rangoSubtitulo = NSRange(location: rangoEnter.location, length: textoCompleto.count - rangoEnter.location)
            
            // Aplicamos el color recibido (Rojo, Azul o Verde)
            attributedString.addAttribute(.foregroundColor, value: color, range: rangoTitulo)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 22), range: rangoTitulo)
            
            attributedString.addAttribute(.foregroundColor, value: UIColor.lightGray, range: rangoSubtitulo)
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: rangoSubtitulo)
        }
        
        statusLabel.attributedText = attributedString
        statusLabel.numberOfLines = 2
    }
    
    func obtenerHoraActual() -> String {
        let f = DateFormatter()
        f.dateFormat = "hh:mm:ss a"
        return f.string(from: Date())
    }

    // MARK: - COMANDOS Y BOTONES
    
    func enviarComandoServo(accion: String) {
        guard let url = URL(string: "\(baseUrl)/api/control-servo") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["accion": accion]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in }
        task.resume()
    }
    
    func enviarCambioClave(nuevaClave: String) {
        guard let url = URL(string: "\(baseUrl)/api/cambiar-clave") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["nuevaClave": nuevaClave]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async { self?.mostrarAlerta(titulo: "Éxito", mensaje: "Nueva clave configurada.") }
            }
        }
        task.resume()
    }
    
    // MARK: - ACCIONES IBACTION
    
    @objc func abrirHistorial() {
        let storyboard = UIStoryboard(name: "HistorialStoryBoard", bundle: nil)
        if let historialVC = storyboard.instantiateViewController(withIdentifier: "HistorialViewController") as? HistorialViewController {
            present(historialVC, animated: true)
        }
    }

    @IBAction func lockTapped(_ sender: UIButton) {
        isLocked.toggle(); actualizarBotonVisualmente()
        let comando = isLocked ? "CERRAR" : "ABRIR"
        enviarComandoServo(accion: comando)
    }
    
    @IBAction func changePasswordTapped(_ sender: UIButton) {
        guard let nuevaClave = passwordTextField.text, nuevaClave.count == 4 else {
            mostrarAlerta(titulo: "Error", mensaje: "La contraseña debe tener 4 dígitos.")
            return
        }
        enviarCambioClave(nuevaClave: nuevaClave)
        passwordTextField.text = ""; dismissKeyboard()
    }
    
    @IBAction func logoutTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Cerrar Sesión", message: "¿Seguro que deseas salir?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Salir", style: .destructive, handler: { _ in
            let storyboard = UIStoryboard(name: "LoginStoryBoard", bundle: nil)
            if let loginVC = storyboard.instantiateInitialViewController() {
                loginVC.modalPresentationStyle = .fullScreen
                loginVC.modalTransitionStyle = .crossDissolve
                self.present(loginVC, animated: true)
            }
        }))
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
        
        // AQUI CAMBIAMOS EL COLOR DEL BOTÓN A AZUL SI ESTÁ CERRADO
        let color = isLocked ? UIColor.systemBlue : UIColor.systemGreen
        
        if var config = lockButton.configuration {
            config.title = texto
            config.image = UIImage(systemName: imagenNombre)
            config.baseForegroundColor = color
            lockButton.configuration = config
        }
        lockButton.layer.borderColor = color.cgColor
    }
}
