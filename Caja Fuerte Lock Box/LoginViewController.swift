import UIKit

class LoginViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Outlets (Tus conexiones)
    @IBOutlet weak var loginUserTextField: UITextField!
    @IBOutlet weak var loginPasswordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton? // opcional para evitar crash si olvidaste conectar

    // URL base (usa la misma que en tu ViewController)
    let baseUrl = "https://api-sensores-348016469746.us-central1.run.app"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configuración de campos para permitir letras y números
        loginUserTextField.delegate = self
        loginPasswordTextField.delegate = self

        // Asegurarse de que el teclado permita letras (no usar numberPad)
        loginUserTextField.keyboardType = .asciiCapable
        loginUserTextField.autocapitalizationType = .none
        loginUserTextField.autocorrectionType = .no
        loginUserTextField.placeholder = "Usuario (letras y/o números)"

        // Password por seguridad
        loginPasswordTextField.keyboardType = .default
        loginPasswordTextField.isSecureTextEntry = true
        loginPasswordTextField.autocapitalizationType = .none
        loginPasswordTextField.autocorrectionType = .no

        // Botón diseño (uso opcional)
        loginButton?.layer.cornerRadius = 8
        loginButton?.clipsToBounds = true

        // Ocultar el teclado si tocan fuera
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Lógica del Botón INGRESAR
    @IBAction func ingresoTocado(_ sender: Any) {
        // 1. Obtener los textos (y evitar vacíos)
        guard let usuario = loginUserTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !usuario.isEmpty,
              let password = loginPasswordTextField.text, !password.isEmpty else {
            mostrarAlerta(mensaje: "Por favor escribe usuario y contraseña")
            return
        }

        print("🔍 Intentando ingresar con: \(usuario) | \(password)")
        view.endEditing(true)
        loginButton?.isEnabled = false

        // Llamada al login del servidor
        let payload: [String: Any] = ["username": usuario, "password": password]
        guard let url = URL(string: "\(baseUrl)/api/login") else {
            loginButton?.isEnabled = true
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.loginButton?.isEnabled = true

                if let error = error {
                    print("Error de red: \(error.localizedDescription)")
                    self?.mostrarAlerta(mensaje: "Error de red: \(error.localizedDescription)")
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self?.mostrarAlerta(mensaje: "Respuesta inválida del servidor")
                    return
                }

                guard let data = data else {
                    self?.mostrarAlerta(mensaje: "Sin datos de respuesta")
                    return
                }

                // Decodificar respuesta básica: { success: Bool, mensaje: String, dispositivo_id?: String }
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let success = (json?["success"] as? Bool) ?? false
                    let mensaje = (json?["mensaje"] as? String) ?? ""
                    let dispositivoId = json?["dispositivo_id"] as? String

                    if success {
                        // Caso A: usuario tiene dispositivo ya asociado
                        if let dispositivo = dispositivoId, !dispositivo.isEmpty {
                            print("Login exitoso. Dispositivo asociado: \(dispositivo)")
                            UserDefaults.standard.set(usuario, forKey: "last_user")
                            UserDefaults.standard.set(dispositivo, forKey: "last_device")
                            self?.entrarAPantallaPrincipal()
                        } else {
                            // Caso B: pedir dispositivo_id
                            self?.promptForDeviceId(username: usuario)
                        }
                    } else {
                        let status = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                        print("Login fallido: \(mensaje) / status: \(status)")
                        self?.mostrarAlerta(mensaje: mensaje.isEmpty ? status : mensaje)
                    }
                } catch {
                    print("Error decodificando login: \(error)")
                    self?.mostrarAlerta(mensaje: "Error procesando respuesta del servidor")
                }
            }
        }.resume()
    }

    // Pedir al usuario el dispositivo_id (RPI)
    func promptForDeviceId(username: String) {
        let alert = UIAlertController(title: "Dispositivo no registrado", message: "Ingresa el dispositivo_id (ej. RPI_SALA_01) para asociarlo a tu usuario", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "RPI_SALA_01"
            tf.autocapitalizationType = .allCharacters
            tf.keyboardType = .asciiCapable
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Autorizar", style: .default, handler: { [weak self] _ in
            guard let dispositivoId = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !dispositivoId.isEmpty else {
                self?.mostrarAlerta(mensaje: "Debes escribir un dispositivo válido")
                return
            }
            self?.autorizarDispositivo(username: username, dispositivoId: dispositivoId)
        }))
        present(alert, animated: true)
    }

    // Llamada para autorizar dispositivo en el servidor
    func autorizarDispositivo(username: String, dispositivoId: String) {
        let payload: [String: Any] = ["username": username, "dispositivo_id": dispositivoId]
        guard let url = URL(string: "\(baseUrl)/api/autorizar-dispositivo") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.mostrarAlerta(mensaje: "Error de red: \(error.localizedDescription)")
                    return
                }
                guard let http = response as? HTTPURLResponse, let data = data else {
                    self?.mostrarAlerta(mensaje: "Respuesta inválida del servidor")
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let success = (json?["success"] as? Bool) ?? false
                    let mensaje = (json?["mensaje"] as? String) ?? ""
                    if success {
                        UserDefaults.standard.set(username, forKey: "last_user")
                        UserDefaults.standard.set(dispositivoId, forKey: "last_device")
                        self?.mostrarAlerta(mensaje: "Dispositivo autorizado: \(dispositivoId)")
                        self?.entrarAPantallaPrincipal()
                    } else {
                        let status = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                        self?.mostrarAlerta(mensaje: mensaje.isEmpty ? status : mensaje)
                    }
                } catch {
                    self?.mostrarAlerta(mensaje: "Error procesando respuesta")
                }
            }
        }.resume()
    }

    // Navegación a la pantalla principal
    func entrarAPantallaPrincipal() {
        // performSegue(using existing segue)
        // Si el segue "irAlInicio" no existe, se presenta el initial VC de Main
        // performSegue(withIdentifier: "irAlInicio", sender: self)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainVC = storyboard.instantiateInitialViewController() {
            mainVC.modalPresentationStyle = .fullScreen
            present(mainVC, animated: true)
        } else {
            mostrarAlerta(mensaje: "No encontré la pantalla principal (revisa el storyboard 'Main').")
        }
    }

    // Función auxiliar para mostrar mensajes bonitos
    func mostrarAlerta(mensaje: String) {
        let alerta = UIAlertController(title: "BlackBox", message: mensaje, preferredStyle: .alert)
        alerta.addAction(UIAlertAction(title: "OK", style: .default))
        present(alerta, animated: true)
    }

    // Botón Registrar (usar el segue que ya existe en storyboard)
    @IBAction func tocoRegistrar(_ sender: Any) {
        // Usar el segue que ya definiste en el storyboard con identifier "irARegistro"
        performSegue(withIdentifier: "irARegistro", sender: self)
    }

    // Regreso de la pantalla de registro (unwind segue)
    @IBAction func regresarAlLogin(_ segue: UIStoryboardSegue) {
        print("Regresó al Login")
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == loginUserTextField {
            loginPasswordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            ingresoTocado(self)
        }
        return true
    }
}
