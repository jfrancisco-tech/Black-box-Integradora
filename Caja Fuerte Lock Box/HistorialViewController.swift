import UIKit

class HistorialViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tabla: UITableView!
    
    // Usamos la estructura que ya definiste en ViewController.swift
    var eventos: [EventoHistorial] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configuración de la tabla
        tabla.dataSource = self
        tabla.delegate = self
        
        cargarDatos()
    }
    
    func cargarDatos() {
        guard let url = URL(string: "https://api-sensores-348016469746.us-central1.run.app/api/historial") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            do {
                // Intentamos decodificar
                self.eventos = try JSONDecoder().decode([EventoHistorial].self, from: data)
                DispatchQueue.main.async { self.tabla.reloadData() }
            } catch {
                print("Error al cargar historial: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Configuración de la Tabla
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if indexPath.row < eventos.count {
            let evento = eventos[indexPath.row]
            
            // Buscamos los elementos por su TAG (Configurado en el XML)
            let imgIcon = cell.viewWithTag(100) as? UIImageView
            let lblTitle = cell.viewWithTag(101) as? UILabel
            let lblDate = cell.viewWithTag(102) as? UILabel
            
            lblTitle?.text = evento.mensaje
            lblDate?.text = "\(evento.fecha_bloque) - \(evento.hora)"
            
            // Lógica de colores
            if evento.mensaje.contains("Alarma") || evento.mensaje.contains("Robo") || evento.mensaje.contains("Intento") {
                imgIcon?.image = UIImage(systemName: "exclamationmark.triangle.fill")
                imgIcon?.tintColor = .systemRed
                imgIcon?.superview?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            } else if evento.mensaje.contains("Abierta") {
                imgIcon?.image = UIImage(systemName: "lock.open.fill")
                imgIcon?.tintColor = .systemGreen
                imgIcon?.superview?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            } else {
                imgIcon?.image = UIImage(systemName: "info.circle.fill")
                imgIcon?.tintColor = .systemBlue
                imgIcon?.superview?.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            }
        }
        
        return cell
    }
}
