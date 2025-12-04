import UIKit

class RegistroViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var idDeviceTextField: UITextField! // El nuevo campo para RPI_SALA_01
    @IBOutlet weak var userTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var guardarButton: UIButton!
    
    let baseUrl = "https://api-sensores-348016469746.us-central1.run.app"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Pantalla de Registro cargada")
        
        // Ocultar teclado al tocar fuera
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        guardarButton.layer.cornerRadius = 8
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Acción del Botón GUARDAR
    @IBAction func guardarTapped(_ sender: Any) {
        
        // 1. Validar que no haya campos vacíos (idDevice obligatorio según tu API)
        guard let idCaja = idDeviceTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !idCaja.isEmpty,
              let usuario = userTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !usuario.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            
            mostrarAlerta(mensaje: "Por favor llena todos los campos, incluyendo el Código de Caja")
            return
        }
        
        print("📦 Intentando registrar: Usuario=\(usuario) Caja=\(idCaja)")
        guardarButton.isEnabled = false
        
        let payload: [String: Any] = ["username": usuario, "password": password, "dispositivo_id": idCaja]
        guard let url = URL(string: "\(baseUrl)/api/registro") else { return mostrarAlerta(mensaje: "URL inválida") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.guardarButton.isEnabled = true
                
                if let error = error {
                    self?.mostrarAlerta(mensaje: "Error de red: \(error.localizedDescription)")
                    return
                }
                guard let http = response as? HTTPURLResponse, let data = data else {
                    self?.mostrarAlerta(mensaje: "Respuesta inválida del servidor")
                    return
                }
                
                // Esperamos { success: Bool, mensaje: String } o 404/400 con mensaje
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let success = (json?["success"] as? Bool) ?? (http.statusCode == 200)
                    let mensaje = (json?["mensaje"] as? String) ?? ""
                    
                    if success {
                        self?.mostrarAlerta(mensaje: "Registro exitoso. \(mensaje)") {
                            // Cerrar registro y volver al login
                            self?.dismiss(animated: true, completion: nil)
                        }
                    } else {
                        let status = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                        self?.mostrarAlerta(mensaje: mensaje.isEmpty ? status : mensaje)
                    }
                } catch {
                    let str = String(data: data, encoding: .utf8) ?? "Sin texto"
                    self?.mostrarAlerta(mensaje: "Respuesta no esperada: \(str)")
                }
            }
        }.resume()
    }
    
    // Función para mostrar alertas rápidas (con cierre opcional)
    func mostrarAlerta(mensaje: String, onOk: (() -> Void)? = nil) {
        let alerta = UIAlertController(title: "Registro", message: mensaje, preferredStyle: .alert)
        alerta.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in onOk?() }))
        present(alerta, animated: true)
    }
    
    // Botón Cancelar (si tienes uno)
    @IBAction func cancelarTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
